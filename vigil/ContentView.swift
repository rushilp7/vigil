import SwiftUI
import MapKit
import SwiftData

struct ContentView: View {
    @Environment(LocationManager.self) var locationManager
    @Environment(CrimeDataViewModel.self) var crimeDataVM
    @Environment(\.modelContext) var modelContext

    var body: some View {
        Map {
            UserAnnotation()
        }
        .onAppear {
            locationManager.requestPermission()
        }
        .onChange(of: locationManager.userLocation) { _, newLocation in
            if let location = newLocation, crimeDataVM.incidents.isEmpty {
                Task {
                    await crimeDataVM.loadCrimeData(
                        near: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        context: modelContext
                    )
                }
            }
        }
        .overlay(alignment: .top) {
            if crimeDataVM.isLoading {
                ProgressView("Loading crime data...")
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 60)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(LocationManager())
        .environment(CrimeDataViewModel())
        .modelContainer(for: CrimeIncident.self, inMemory: true)
}
