import SwiftUI
import MapKit

struct SearchBarView: View {
    @Environment(MapViewModel.self) var mapVM

    var body: some View {
        @Bindable var mapVM = mapVM

        VStack(spacing: 4) {
            // Source field
            searchField(
                icon: "circle.fill",
                iconColor: .blue,
                placeholder: "Start",
                text: $mapVM.sourceQuery,
                field: .source
            )

            // Destination field
            searchField(
                icon: "mappin.circle.fill",
                iconColor: .red,
                placeholder: "Destination",
                text: $mapVM.destinationQuery,
                field: .destination
            )

            // Results dropdown
            if let field = mapVM.activeField {
                let results = field == .source ? mapVM.sourceResults : mapVM.destinationResults
                if !results.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(results, id: \.self) { item in
                                Button {
                                    if field == .source {
                                        mapVM.selectSource(item)
                                    } else {
                                        mapVM.selectDestination(item)
                                    }
                                    mapVM.tryCalculateRoute()
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "Unknown")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        if let address = item.placemark.title {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func searchField(
        icon: String,
        iconColor: Color,
        placeholder: String,
        text: Binding<String>,
        field: MapViewModel.ActiveField
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.caption)
                .frame(width: 16)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .onSubmit {
                    Task { await mapVM.search(text.wrappedValue, for: field) }
                }
                .onTapGesture { mapVM.activeField = field }
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                    if field == .source { mapVM.selectedSource = nil }
                    else { mapVM.selectedDestination = nil }
                    mapVM.route = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
