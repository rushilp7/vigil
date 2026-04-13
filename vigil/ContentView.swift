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
    @State private var lastSpan: Double = 0.05

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

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

            if let route = mapVM.route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 4)
            }

            if let destination = mapVM.selectedDestination {
                Marker(destination.name ?? "Destination",
                       coordinate: destination.placemark.coordinate)
            }

            // Source pin
            if let source = mapVM.selectedSource {
                Marker(source.name ?? "Start",
                       systemImage: "figure.walk",
                       coordinate: source.placemark.coordinate)
                    .tint(.blue)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .mapStyle(.standard(pointsOfInterest: .including([.restaurant, .store, .hospital, .police])))
        // Search bar at top
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                SearchBarView()
                if crimeDataVM.isLoading {
                    ProgressView("Loading crime data...")
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        // Legend at bottom-left
        .overlay(alignment: .bottomLeading) {
            if !crimeDataVM.avoidanceZones.isEmpty {
                CrimeLegendView()
                    .padding(.leading, 8)
                    .padding(.bottom, 80)
            }
        }
        // Safety buttons at bottom-right
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                Button { showFakeCall = true } label: {
                    Image(systemName: "phone.fill")
                        .font(.title3)
                        .frame(width: 48, height: 48)
                        .background(.green, in: Circle())
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
                Button { showEmergency = true } label: {
                    Image(systemName: "sos")
                        .font(.title3.bold())
                        .frame(width: 48, height: 48)
                        .background(.red, in: Circle())
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
            }
            .padding(.trailing, 8)
            .padding(.bottom, 80)
        }
        // Route info / error at bottom
        .overlay(alignment: .bottom) {
            VStack {
                if let route = mapVM.route {
                    RouteInfoView(
                        route: route,
                        avoidanceZones: crimeDataVM.avoidanceZones,
                        onClear: { mapVM.clearRoute() }
                    )
                } else if let error = mapVM.routeError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                        Spacer()
                        Button("Dismiss", systemImage: "xmark.circle.fill") {
                            mapVM.clearRoute()
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            let newSpan = context.region.span.latitudeDelta
            // Only recompute if zoom changed meaningfully (>20% difference)
            if abs(newSpan - lastSpan) / lastSpan > 0.2 {
                lastSpan = newSpan
                crimeDataVM.recomputeZones(for: newSpan)
            }
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
