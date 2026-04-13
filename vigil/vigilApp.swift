import SwiftUI
import SwiftData

@main
struct vigilApp: App {
    @State private var locationManager = LocationManager()
    @State private var crimeDataVM = CrimeDataViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
                .environment(crimeDataVM)
        }
        .modelContainer(for: CrimeIncident.self)
    }
}
