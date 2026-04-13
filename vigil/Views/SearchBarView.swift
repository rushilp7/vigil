import SwiftUI
import MapKit

struct SearchBarView: View {
    @Environment(MapViewModel.self) var mapVM
    @Environment(LocationManager.self) var locationManager

    @State private var isExpanded = false

    var body: some View {
        @Bindable var mapVM = mapVM

        VStack(spacing: 6) {
            // Source field (shown when expanded)
            if isExpanded {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)

                    if mapVM.useCurrentLocationAsSource {
                        Text("Your Location")
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            mapVM.useCurrentLocationAsSource = false
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        TextField("Source", text: $mapVM.sourceQuery)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                Task { await mapVM.search(mapVM.sourceQuery, for: .source) }
                            }
                            .onTapGesture { mapVM.activeField = .source }
                        Button {
                            mapVM.selectCurrentLocation()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        if !mapVM.sourceQuery.isEmpty {
                            clearButton { mapVM.sourceQuery = ""; mapVM.sourceResults = [] }
                        }
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }

            // Destination field (always shown)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("Where to?", text: $mapVM.destinationQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task { await mapVM.search(mapVM.destinationQuery, for: .destination) }
                    }
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) { isExpanded = true }
                        mapVM.activeField = .destination
                    }
                if !mapVM.destinationQuery.isEmpty {
                    clearButton {
                        mapVM.clearRoute()
                        withAnimation(.easeOut(duration: 0.2)) { isExpanded = false }
                    }
                }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            // Search results dropdown
            if let field = mapVM.activeField {
                let results = field == .source ? mapVM.sourceResults : mapVM.destinationResults
                if !results.isEmpty {
                    VStack(spacing: 0) {
                        // "Your Location" option for source field
                        if field == .source {
                            Button {
                                mapVM.selectCurrentLocation()
                                tryCalculateRoute()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                    Text("Your Location")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                            }
                            Divider()
                        }

                        ForEach(results, id: \.self) { item in
                            Button {
                                if field == .source {
                                    mapVM.selectSource(item)
                                } else {
                                    mapVM.selectDestination(item)
                                }
                                tryCalculateRoute()
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
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    /// Calculate route if both source and destination are set.
    private func tryCalculateRoute() {
        guard let destCoord = mapVM.selectedDestination?.placemark.coordinate,
              let srcCoord = mapVM.sourceCoordinate(userLocation: locationManager.userLocation)
        else { return }

        Task {
            await mapVM.calculateRoute(from: srcCoord, to: destCoord)
        }
    }

    private func clearButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
    }
}
