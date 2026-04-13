import SwiftUI
import SwiftData

@main
struct vigilApp: App {
    @State private var locationManager = LocationManager()
    @State private var crimeDataVM = CrimeDataViewModel()
    @State private var mapVM = MapViewModel()
    @State private var motionManager = MotionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
                .environment(crimeDataVM)
                .environment(mapVM)
                .environment(motionManager)
        }
        .modelContainer(for: CrimeIncident.self)
    }
}
