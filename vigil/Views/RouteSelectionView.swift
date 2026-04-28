import SwiftUI
import MapKit

struct RouteSelectionView: View {
    @Environment(MapViewModel.self) var mapVM

    var body: some View {
        NavigationStack {
            List(mapVM.scoredRoutes) { scored in
                Button { mapVM.selectRoute(scored) } label: {
                    RouteRowView(scored: scored)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choose a Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { mapVM.cancelRouteSelection() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct RouteRowView: View {
    let scored: MapViewModel.ScoredRoute

    var body: some View {
        HStack(spacing: 14) {
            // Rank circle
            ZStack {
                Circle()
                    .fill(scored.isRecommended ? Color.blue : Color(.systemGray4))
                    .frame(width: 38, height: 38)
                Text("\(scored.id + 1)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(scored.isRecommended ? "Safest Route" : "Route \(scored.id + 1)")
                        .font(.headline)
                    if scored.isRecommended {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                HStack(spacing: 14) {
                    Label(scored.formattedTime, systemImage: "clock")
                    Label(scored.formattedDistance, systemImage: "arrow.left.and.right")
                    if scored.nearbyBusinessCount > 0 {
                        Label("\(scored.nearbyBusinessCount)", systemImage: "building.2")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                // Relative danger bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5))
                        Capsule()
                            .fill(safetyColor)
                            .frame(width: max(4, geo.size.width * scored.normalizedScore))
                    }
                    .frame(height: 4)
                }
                .frame(height: 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(scored.safetyLabel)
                    .font(.caption.bold())
                    .foregroundStyle(safetyColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(safetyColor.opacity(0.15), in: Capsule())
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private var safetyColor: Color {
        switch scored.normalizedScore {
        case ..<0.05: return .green
        case ..<0.5:  return .orange
        default:      return .red
        }
    }
}
