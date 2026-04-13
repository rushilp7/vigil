import SwiftUI
import MapKit

struct RouteStepsView: View {
    let route: MKRoute
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Label(formattedDistance, systemImage: "figure.walk")
                        Label(formattedTime, systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Section("Directions") {
                    ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                        if !step.instructions.isEmpty {
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(.blue, in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.instructions)
                                        .font(.subheadline)
                                    if step.distance > 0 {
                                        Text(formatStepDistance(step.distance))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Route Steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
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

    private func formatStepDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f mi", meters / 1609.34)
        }
        return String(format: "%.0f ft", meters * 3.281)
    }
}
