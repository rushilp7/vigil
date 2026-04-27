import SwiftUI
import MapKit

struct RouteInfoView: View {
    let route: MKRoute
    let alternateCount: Int
    let avoidanceZones: [AvoidanceZone]
    let routeRank: Int
    let onGo: () -> Void
    let onSteps: () -> Void
    let onClear: () -> Void

    private var routeWarnings: [AvoidanceZone] {
        avoidanceZones.filter { zone in
            let zoneLocation = CLLocation(latitude: zone.center.latitude, longitude: zone.center.longitude)
            let polyline = route.polyline
            let points = polyline.points()
            let step = max(1, polyline.pointCount / 50)
            for i in stride(from: 0, to: polyline.pointCount, by: step) {
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
                    HStack(spacing: 6) {
                        Text("\(ordinal(routeRank)) Safest Route")
                            .font(.headline)
                        if alternateCount > 0 {
                            Text("of \(alternateCount + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    HStack(spacing: 12) {
                        Label(formattedDistance, systemImage: "figure.walk")
                        Label(formattedTime, systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button { onGo() } label: {
                    Text("Go")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 20))
                }
                Button("Clear", systemImage: "xmark.circle.fill") { onClear() }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // Warning + steps row
            HStack {
                if !routeWarnings.isEmpty {
                    let highSeverity = routeWarnings.contains { $0.severity == .high }
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(highSeverity ? .red : .orange)
                        Text(highSeverity
                            ? "Passes through high-crime area"
                            : "Passes through elevated-crime area")
                            .font(.caption)
                            .foregroundStyle(highSeverity ? .red : .orange)
                    }
                }
                Spacer()
                Button { onSteps() } label: {
                    Label("Steps", systemImage: "list.bullet")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
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
