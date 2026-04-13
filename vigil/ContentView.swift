import SwiftUI
import MapKit
import SwiftData

struct ContentView: View {
    static let philadelphiaCenter = CLLocationCoordinate2D(latitude: 39.9526, longitude: -75.1652)

    @Environment(LocationManager.self) var locationManager
    @Environment(CrimeDataViewModel.self) var crimeDataVM
    @Environment(MapViewModel.self) var mapVM
    @Environment(MotionManager.self) var motionManager
    @Environment(\.modelContext) var modelContext

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: philadelphiaCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var showFakeCall = false
    @State private var showEmergency = false

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                UserAnnotation()

                // Avoidance zone overlays
                ForEach(crimeDataVM.avoidanceZones) { zone in
                    MapCircle(center: zone.center, radius: zone.radius)
                        .foregroundStyle(
                            zone.severity == .high ? Color.red.opacity(0.2) :
                            zone.severity == .medium ? Color.orange.opacity(0.15) :
                            Color.yellow.opacity(0.1)
                        )
                        .stroke(
                            zone.severity == .high ? Color.red.opacity(0.4) :
                            zone.severity == .medium ? Color.orange.opacity(0.3) :
                            Color.yellow.opacity(0.2),
                            lineWidth: 1
                        )
                }

                // Crime incident markers
                ForEach(crimeDataVM.incidents) { incident in
                    Annotation("", coordinate: CLLocationCoordinate2D(
                        latitude: incident.latitude,
                        longitude: incident.longitude
                    )) {
                        Circle()
                            .fill(incident.category.color.opacity(0.7))
                            .frame(width: 8, height: 8)
                    }
                }

                // Walking route
                if let route = mapVM.route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 4)
                }

                // Destination pin
                if let destination = mapVM.selectedDestination {
                    Marker(destination.name ?? "Destination",
                           coordinate: destination.placemark.coordinate)
                }
            }

            // UI Overlays
            VStack {
                // Search bar
                SearchBarView()
                    .padding(.horizontal)
                    .padding(.top, 8)

                if crimeDataVM.isLoading {
                    ProgressView("Loading crime data...")
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                // Bottom controls
                HStack(alignment: .bottom) {
                    // Legend
                    if !crimeDataVM.incidents.isEmpty {
                        CrimeLegendView()
                    }

                    Spacer()

                    // Safety action buttons
                    VStack(spacing: 12) {
                        Button {
                            showFakeCall = true
                        } label: {
                            Image(systemName: "phone.fill")
                                .font(.title3)
                                .frame(width: 48, height: 48)
                                .background(.green, in: Circle())
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        }

                        Button {
                            showEmergency = true
                        } label: {
                            Image(systemName: "sos")
                                .font(.title3.bold())
                                .frame(width: 48, height: 48)
                                .background(.red, in: Circle())
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        }
                    }
                }
                .padding(.horizontal, 8)

                // Route info panel
                if let route = mapVM.route {
                    RouteInfoView(
                        route: route,
                        avoidanceZones: crimeDataVM.avoidanceZones,
                        onClear: { mapVM.clearRoute() }
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 16)
        }
        .onAppear {
            locationManager.requestPermission()
            motionManager.startMonitoring()
            Task {
                await crimeDataVM.loadCrimeData(
                    near: ContentView.philadelphiaCenter.latitude,
                    longitude: ContentView.philadelphiaCenter.longitude,
                    context: modelContext
                )
            }
        }
        .onChange(of: motionManager.isShakeDetected) { _, detected in
            if detected {
                showEmergency = true
                motionManager.resetShakeDetection()
            }
        }
        .fullScreenCover(isPresented: $showFakeCall) {
            FakeCallView(onDismiss: { showFakeCall = false })
        }
        .fullScreenCover(isPresented: $showEmergency) {
            EmergencyAlertView(onCancel: { showEmergency = false })
        }
        .alert("Error", isPresented: .init(
            get: { crimeDataVM.errorMessage != nil },
            set: { if !$0 { crimeDataVM.errorMessage = nil } }
        )) {
            Button("Retry") {
                Task {
                    await crimeDataVM.loadCrimeData(
                        near: ContentView.philadelphiaCenter.latitude,
                        longitude: ContentView.philadelphiaCenter.longitude,
                        context: modelContext
                    )
                }
            }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(crimeDataVM.errorMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
        .environment(LocationManager())
        .environment(CrimeDataViewModel())
        .environment(MapViewModel())
        .environment(MotionManager())
        .modelContainer(for: CrimeIncident.self, inMemory: true)
}
