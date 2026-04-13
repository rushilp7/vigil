import Foundation
import MapKit
import Observation

@Observable
class MapViewModel {
    // Source
    var sourceQuery = ""
    var sourceResults: [MKMapItem] = []
    var selectedSource: MKMapItem?
    var useCurrentLocationAsSource = true

    // Destination
    var destinationQuery = ""
    var destinationResults: [MKMapItem] = []
    var selectedDestination: MKMapItem?

    var isSearching = false
    var route: MKRoute?
    var routeError: String?

    /// Which field is currently showing results
    enum ActiveField { case source, destination }
    var activeField: ActiveField?

    func search(_ query: String, for field: ActiveField) async {
        guard !query.isEmpty else {
            clearResults(for: field)
            return
        }

        activeField = field
        isSearching = true
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
        isSearching = false
    }

    func selectSource(_ item: MKMapItem) {
        selectedSource = item
        sourceQuery = item.name ?? "Source"
        sourceResults = []
        useCurrentLocationAsSource = false
        activeField = nil
    }

    func selectCurrentLocation() {
        useCurrentLocationAsSource = true
        sourceQuery = ""
        selectedSource = nil
        sourceResults = []
        activeField = nil
    }

    func selectDestination(_ item: MKMapItem) {
        selectedDestination = item
        destinationQuery = item.name ?? "Destination"
        destinationResults = []
        activeField = nil
    }

    /// Resolve the source coordinate: either user location or a searched place.
    func sourceCoordinate(userLocation: CLLocation?) -> CLLocationCoordinate2D? {
        if useCurrentLocationAsSource {
            return userLocation?.coordinate
        }
        return selectedSource?.placemark.coordinate
    }

    func calculateRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async {
        routeError = nil
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            route = response.routes.first
        } catch {
            route = nil
            let mkError = error as NSError
            if mkError.domain == "MKErrorDomain",
               let reason = mkError.userInfo["NSLocalizedFailureReason"] as? String {
                routeError = reason
            } else {
                routeError = "Could not calculate walking route."
            }
        }
    }

    func clearRoute() {
        route = nil
        routeError = nil
        selectedSource = nil
        selectedDestination = nil
        sourceQuery = ""
        destinationQuery = ""
        sourceResults = []
        destinationResults = []
        useCurrentLocationAsSource = true
        activeField = nil
    }

    private func clearResults(for field: ActiveField) {
        switch field {
        case .source: sourceResults = []
        case .destination: destinationResults = []
        }
    }
}
