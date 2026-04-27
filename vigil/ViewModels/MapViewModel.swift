import Foundation
import MapKit
import CoreLocation
import UIKit
import Observation

@Observable
class MapViewModel {
    struct ScoredRoute: Identifiable {
        let id: Int
        let route: MKRoute
        let score: Double
        /// 0 = safest, 1 = most dangerous (relative to this set of routes)
        let normalizedScore: Double
        let isRecommended: Bool

        var formattedTime: String {
            let minutes = Int(route.expectedTravelTime) / 60
            guard minutes >= 60 else { return "\(minutes) min" }
            return "\(minutes / 60)h \(minutes % 60)m"
        }

        var formattedDistance: String {
            let miles = route.distance * 0.000621371
            return String(format: "%.1f mi", miles)
        }

        var safetyLabel: String {
            if normalizedScore < 0.05 { return "Safe" }
            if normalizedScore < 0.5  { return "Low Risk" }
            if normalizedScore < 0.8  { return "Med Risk" }
            return "High Risk"
        }
    }

    var sourceQuery = ""
    var sourceResults: [MKMapItem] = []
    var selectedSource: MKMapItem?

    var destinationQuery = ""
    var destinationResults: [MKMapItem] = []
    var selectedDestination: MKMapItem?

    var route: MKRoute?
    var allRoutes: [MKRoute] = []
    var scoredRoutes: [ScoredRoute] = []
    var pendingRouteSelection = false
    var routeError: String?

    // In-app navigation state
    var isNavigating = false
    var currentStepIndex = 0
    var navigationStartTime: Date?
    var etaAlertShown = false

    var currentStep: MKRoute.Step? {
        guard let route, isNavigating,
              currentStepIndex < route.steps.count else { return nil }
        return route.steps[currentStepIndex]
    }

    var nextStep: MKRoute.Step? {
        guard let route, isNavigating,
              currentStepIndex + 1 < route.steps.count else { return nil }
        return route.steps[currentStepIndex + 1]
    }

    /// Routes that were considered but rejected (shown as gray dashed lines).
    var alternateRoutes: [MKRoute] {
        allRoutes.filter { $0 !== route }
    }

    enum ActiveField { case source, destination }
    var activeField: ActiveField?

    func search(_ query: String, for field: ActiveField) async {
        guard !query.isEmpty else {
            clearResults(for: field)
            return
        }

        activeField = field
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.9526, longitude: -75.1652),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            switch field {
            case .source: sourceResults = response.mapItems
            case .destination: destinationResults = response.mapItems
            }
        } catch {
            clearResults(for: field)
        }
    }

    func selectSource(_ item: MKMapItem) {
        selectedSource = item
        sourceQuery = item.name ?? "Source"
        sourceResults = []
        activeField = nil
    }

    func selectDestination(_ item: MKMapItem) {
        selectedDestination = item
        destinationQuery = item.name ?? "Destination"
        destinationResults = []
        activeField = nil
    }

    /// Request multiple routes and pick the safest one based on avoidance zones.
    func calculateSafestRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        avoiding zones: [AvoidanceZone]
    ) async {
        routeError = nil
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking
        request.requestsAlternateRoutes = true

        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            allRoutes = response.routes

            let scores = response.routes.map { crimeScore($0, zones: zones) }
            let maxScore = scores.max() ?? 0
            let minScore = scores.min() ?? 0

            // Sort safest-first for display; id encodes display rank
            let paired = zip(response.routes, scores).sorted { $0.1 < $1.1 }
            scoredRoutes = paired.enumerated().map { rank, pair in
                ScoredRoute(
                    id: rank,
                    route: pair.0,
                    score: pair.1,
                    normalizedScore: maxScore > 0 ? pair.1 / maxScore : 0,
                    isRecommended: pair.1 == minScore
                )
            }

            route = nil
            pendingRouteSelection = !scoredRoutes.isEmpty
        } catch {
            route = nil
            allRoutes = []
            let mkError = error as NSError
            if mkError.domain == "MKErrorDomain",
               let reason = mkError.userInfo["NSLocalizedFailureReason"] as? String {
                routeError = reason
            } else {
                routeError = "Could not calculate walking route."
            }
        }
    }

    /// Score a route by how much it overlaps with avoidance zones.
    /// Lower score = safer route.
    private func crimeScore(_ route: MKRoute, zones: [AvoidanceZone]) -> Double {
        let polyline = route.polyline
        let points = polyline.points()
        let pointCount = polyline.pointCount
        var score = 0.0

        // Sample every few points for performance
        let step = max(1, pointCount / 100)
        for i in stride(from: 0, to: pointCount, by: step) {
            let coord = points[i].coordinate
            let pointLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)

            for zone in zones {
                let zoneLoc = CLLocation(latitude: zone.center.latitude, longitude: zone.center.longitude)
                let distance = pointLoc.distance(from: zoneLoc)
                if distance <= zone.radius {
                    // Inside the zone: full penalty based on severity
                    score += Double(zone.severity.rawValue) * 3.0
                } else if distance <= zone.radius * 2 {
                    // Near the zone: partial penalty
                    score += Double(zone.severity.rawValue)
                }
            }
        }
        return score
    }

    /// Set source to user's current GPS location.
    func useMyLocation(_ location: CLLocation) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        item.name = "My Location"
        selectedSource = item
        sourceQuery = "My Location"
        sourceResults = []
        activeField = nil
    }

    /// Begin in-app turn-by-turn navigation.
    func startNavigation() {
        guard route != nil else { return }
        currentStepIndex = 0
        isNavigating = true
        navigationStartTime = Date()
        etaAlertShown = false
    }

    func advanceStep() {
        guard let route, currentStepIndex < route.steps.count - 1 else {
            stopNavigation()
            return
        }
        currentStepIndex += 1
    }

    /// Check if elapsed time exceeds 2x the expected travel time.
    var shouldShowETAAlert: Bool {
        guard isNavigating, !etaAlertShown,
              let start = navigationStartTime,
              let route else { return false }
        let elapsed = Date().timeIntervalSince(start)
        return elapsed > route.expectedTravelTime * 2
    }

    /// Format the expected arrival for display.
    var expectedArrivalString: String {
        guard let start = navigationStartTime, let route else { return "" }
        let arrival = start.addingTimeInterval(route.expectedTravelTime)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: arrival)
    }

    /// Send a safety text to an emergency contact.
    func sendSafetyText(to phone: String) {
        guard let destination = selectedDestination else { return }
        let name = destination.name ?? "my destination"
        let message = "Hey, I'm walking to \(name) using Vigil and my ETA has been exceeded. Please check on me."
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = trimmed.isEmpty ? "sms:&body=\(encoded)" : "sms:\(trimmed)&body=\(encoded)"
        if let url = URL(string: urlString) {
            Task { @MainActor in UIApplication.shared.open(url) }
        }
        etaAlertShown = true
    }

    func stopNavigation() {
        isNavigating = false
        currentStepIndex = 0
        navigationStartTime = nil
        etaAlertShown = false
    }

    /// 1-based safety rank of the currently selected route (1 = safest).
    var selectedRouteRank: Int? {
        guard let route else { return nil }
        return scoredRoutes.first(where: { $0.route === route }).map { $0.id + 1 }
    }

    /// Midpoint between source and destination (used to center the crime data fetch).
    var routeMidpoint: CLLocationCoordinate2D? {
        guard let src = selectedSource?.placemark.coordinate,
              let dst = selectedDestination?.placemark.coordinate else { return nil }
        return CLLocationCoordinate2D(
            latitude: (src.latitude + dst.latitude) / 2,
            longitude: (src.longitude + dst.longitude) / 2
        )
    }

    /// Radius from midpoint to either endpoint, with a 20% buffer.
    var routeRadiusMeters: Double? {
        guard let src = selectedSource?.placemark.coordinate,
              let dst = selectedDestination?.placemark.coordinate else { return nil }
        let srcLoc = CLLocation(latitude: src.latitude, longitude: src.longitude)
        let dstLoc = CLLocation(latitude: dst.latitude, longitude: dst.longitude)
        return (srcLoc.distance(from: dstLoc) / 2) * 1.2
    }

    /// Auto-route if both endpoints are selected.
    func tryCalculateRoute(avoiding zones: [AvoidanceZone]) async {
        guard let src = selectedSource?.placemark.coordinate,
              let dst = selectedDestination?.placemark.coordinate else { return }
        await calculateSafestRoute(from: src, to: dst, avoiding: zones)
    }

    func selectRoute(_ scored: ScoredRoute) {
        route = scored.route
        pendingRouteSelection = false
    }

    func cancelRouteSelection() {
        pendingRouteSelection = false
        clearRoute()
    }

    func clearRoute() {
        stopNavigation()
        route = nil
        allRoutes = []
        scoredRoutes = []
        pendingRouteSelection = false
        routeError = nil
        selectedSource = nil
        selectedDestination = nil
        sourceQuery = ""
        destinationQuery = ""
        sourceResults = []
        destinationResults = []
        activeField = nil
    }

    private func clearResults(for field: ActiveField) {
        switch field {
        case .source: sourceResults = []
        case .destination: destinationResults = []
        }
    }
}
