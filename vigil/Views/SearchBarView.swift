import SwiftUI
import MapKit

struct SearchBarView: View {
    @Environment(MapViewModel.self) var mapVM
    @Environment(LocationManager.self) var locationManager

    var body: some View {
        @Bindable var mapVM = mapVM

        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search destination", text: $mapVM.searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task {
                            await mapVM.searchForDestination(mapVM.searchQuery)
                        }
                    }
                if !mapVM.searchQuery.isEmpty {
                    Button {
                        mapVM.searchQuery = ""
                        mapVM.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            // Search results
            if !mapVM.searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(mapVM.searchResults, id: \.self) { item in
                        Button {
                            mapVM.selectedDestination = item
                            mapVM.searchResults = []
                            mapVM.searchQuery = item.name ?? "Destination"

                            if let userLocation = locationManager.userLocation {
                                Task {
                                    await mapVM.calculateRoute(
                                        from: userLocation.coordinate,
                                        to: item.placemark.coordinate
                                    )
                                }
                            }
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
