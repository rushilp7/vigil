import Foundation
import CoreLocation

/// A high-crime region computed by clustering nearby incidents.
struct AvoidanceZone: Identifiable {
    let id = UUID()
    let center: CLLocationCoordinate2D
    /// Radius in meters
    let radius: Double
    let severity: CrimeCategory.Severity
    let incidentCount: Int
}
