import SwiftUI
import MapKit

struct RouteInfoView: View {
    let route: MKRoute
    let avoidanceZones: [AvoidanceZone]
    let onGo: () -> Void
    let onClear: () -> Void

    /// Check if the route passes through any avoidance zone.
    private var routeWarnings: [AvoidanceZone] {
        avoidanceZones.filter { zone in
            let zoneLocation = CLLocation(latitude: zone.center.latitude, longitude: zone.center.longitude)
            // Check if any polyline point is within the zone radius
            let polyline = route.polyline
            let pointCount = polyline.pointCount
            let points = polyline.points()
            for i in 0..<pointCount {
                let coord = points[i].coordinate
                let pointLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                if pointLocation.distance(from: zoneLocation) <= zone.radius {
                    return true
                }
            }
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Walking Route")
                        .font(.headline)
                    HStack(spacing: 12) {
                        Label(formattedDistance, systemImage: "figure.walk")
                        Label(formattedTime, systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    onGo()
                } label: {
                    Text("Go")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 20))
                }
                Button("Clear", systemImage: "xmark.circle.fill") {
                    onClear()
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.secondary)
            }

            if !routeWarnings.isEmpty {
                let highSeverity = routeWarnings.contains { $0.severity == .high }
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(highSeverity ? .red : .orange)
                    Text(highSeverity
                        ? "Route passes through a high-crime area"
                        : "Route passes through an elevated-crime area")
                        .font(.caption)
                        .foregroundStyle(highSeverity ? .red : .orange)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var formattedDistance: String {
        let meters = route.distance
        if meters >= 1000 {
            return String(format: "%.1f mi", meters / 1609.34)
        }
        return "\(Int(meters)) m"
    }

    private var formattedTime: String {
        let minutes = Int(route.expectedTravelTime / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes) min"
    }
}
