import SwiftUI

struct CrimeLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Crime Severity")
                .font(.caption.bold())
            LegendRow(color: .red, label: "Violent")
            LegendRow(color: .orange, label: "Property")
            LegendRow(color: .yellow, label: "Other")
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct LegendRow: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.7))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
        }
    }
}
