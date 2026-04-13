import Foundation
import MapKit
import Observation

@Observable
class MapViewModel {
    var searchQuery = ""
    var searchResults: [MKMapItem] = []
    var isSearching = false
    var selectedDestination: MKMapItem?
    var route: MKRoute?

    func searchForDestination(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        // Bias results toward Philadelphia
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.9526, longitude: -75.1652),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            print("Search error: \(error)")
            searchResults = []
        }
        isSearching = false
    }

    func calculateRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            route = response.routes.first
        } catch {
            print("Route error: \(error)")
            route = nil
        }
    }

    func clearRoute() {
        route = nil
        selectedDestination = nil
        searchQuery = ""
        searchResults = []
    }
}
