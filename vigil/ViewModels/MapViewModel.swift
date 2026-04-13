import Foundation
import MapKit
import CoreLocation
import Observation

@Observable
class MapViewModel {
    var sourceQuery = ""
    var sourceResults: [MKMapItem] = []
    var selectedSource: MKMapItem?

    var destinationQuery = ""
    var destinationResults: [MKMapItem] = []
    var selectedDestination: MKMapItem?

    var route: MKRoute?
    var allRoutes: [MKRoute] = []
    var routeError: String?

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

            if zones.isEmpty {
                route = response.routes.first
            } else {
                // Score each route by avoidance zone overlap and pick the safest
                route = response.routes.min(by: { crimeScore($0, zones: zones) < crimeScore($1, zones: zones) })
            }
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

    /// Open the route in Apple Maps for turn-by-turn navigation.
    func startNavigation() {
        guard let source = selectedSource, let destination = selectedDestination else { return }
        MKMapItem.openMaps(
            with: [source, destination],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        )
    }

    /// Auto-route if both endpoints are selected.
    func tryCalculateRoute(avoiding zones: [AvoidanceZone]) {
        guard let src = selectedSource?.placemark.coordinate,
              let dst = selectedDestination?.placemark.coordinate else { return }
        Task { await calculateSafestRoute(from: src, to: dst, avoiding: zones) }
    }

    func clearRoute() {
        route = nil
        allRoutes = []
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
