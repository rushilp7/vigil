import SwiftUI
import MapKit

struct NavigationBannerView: View {
    let step: MKRoute.Step
    let nextStep: MKRoute.Step?
    let stepIndex: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: directionIcon)
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.instructions.isEmpty ? "Proceed to route" : step.instructions)
                        .font(.headline)
                        .lineLimit(2)
                    if step.distance > 0 {
                        Text(formatDistance(step.distance))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(stepIndex + 1)/\(totalSteps)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            .padding()

            HStack {
                if let nextStep, !nextStep.instructions.isEmpty {
                    Label("Then: \(nextStep.instructions)", systemImage: "arrow.turn.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(role: .destructive) { onStop() } label: {
                    Label("Stop", systemImage: "xmark.circle.fill")
                        .font(.caption.bold())
                }
                Button { onNext() } label: {
                    Label("Next", systemImage: "chevron.right")
                        .font(.caption.bold())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var directionIcon: String {
        let text = step.instructions.lowercased()
        if text.contains("left") { return "arrow.turn.up.left" }
        if text.contains("right") { return "arrow.turn.up.right" }
        if text.contains("arrive") || text.contains("destination") { return "mappin.circle.fill" }
        return "arrow.up"
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f mi", meters / 1609.34)
        }
        return String(format: "%.0f ft", meters * 3.281)
    }
}
