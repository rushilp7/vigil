import SwiftUI
import MapKit
import SwiftData
import Combine

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
    @State private var showRouteSteps = false
    @State private var showETAAlert = false
    @State private var showContactSetup = false
    @State private var showSettings = false
    @State private var contactPhoneInput = ""
    @AppStorage("emergencyContactPhone") private var emergencyContactPhone = ""

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            // Avoidance zones
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

            // Rejected alternate routes (gray, dashed) — hidden during navigation
            if !mapVM.isNavigating {
                ForEach(Array(mapVM.alternateRoutes.enumerated()), id: \.offset) { _, altRoute in
                    MapPolyline(altRoute.polyline)
                        .stroke(.gray.opacity(0.4), style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                }
            }

            // Selected safest route (blue, solid)
            if let route = mapVM.route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 5)
            }

            if let destination = mapVM.selectedDestination {
                Marker(destination.name ?? "Destination",
                       coordinate: destination.placemark.coordinate)
            }

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
        .onTapGesture {
            // Dismiss search results when tapping the map
            mapVM.activeField = nil
            mapVM.sourceResults = []
            mapVM.destinationResults = []
        }
        // Search bar + settings gear at top (hidden during navigation)
        .overlay(alignment: .top) {
            if !mapVM.isNavigating {
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 8) {
                        SearchBarView()
                        if crimeDataVM.isLoading {
                            ProgressView("Loading crime data...")
                                .padding(8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        // Legend at bottom-left
        .overlay(alignment: .bottomLeading) {
            if !crimeDataVM.avoidanceZones.isEmpty && mapVM.route == nil {
                CrimeLegendView(zoneCount: crimeDataVM.avoidanceZones.count,
                                incidentCount: crimeDataVM.incidents.count)
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
            .padding(.bottom, mapVM.route != nil ? 140 : 80)
            .animation(.easeInOut(duration: 0.2), value: mapVM.route != nil)
        }
        // Navigation banner or route info at bottom
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                if mapVM.isNavigating, let step = mapVM.currentStep, let route = mapVM.route {
                    NavigationBannerView(
                        step: step,
                        nextStep: mapVM.nextStep,
                        stepIndex: mapVM.currentStepIndex,
                        totalSteps: route.steps.count,
                        onNext: { mapVM.advanceStep() },
                        onStop: { mapVM.stopNavigation() }
                    )
                } else if let route = mapVM.route {
                    RouteInfoView(
                        route: route,
                        alternateCount: mapVM.alternateRoutes.count,
                        avoidanceZones: crimeDataVM.avoidanceZones,
                        onGo: { mapVM.startNavigation() },
                        onSteps: { showRouteSteps = true },
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
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            guard mapVM.isNavigating, mapVM.shouldShowETAAlert else { return }
            showETAAlert = true
        }
        .fullScreenCover(isPresented: $showFakeCall) {
            FakeCallView(onDismiss: { showFakeCall = false })
        }
        .fullScreenCover(isPresented: $showEmergency) {
            EmergencyAlertView(onCancel: { showEmergency = false })
        }
        .sheet(isPresented: $showRouteSteps) {
            if let route = mapVM.route {
                RouteStepsView(route: route)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
        .alert("Safety Check", isPresented: $showETAAlert) {
            Button("Send Alert") {
                if emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    contactPhoneInput = ""
                    showContactSetup = true
                } else {
                    mapVM.sendSafetyText(to: emergencyContactPhone)
                }
            }
            Button("I'm Fine", role: .cancel) {
                mapVM.etaAlertShown = true
            }
        } message: {
            Text("You've been walking longer than expected. Send a safety check to your emergency contact?")
        }
        .alert("Set Emergency Contact", isPresented: $showContactSetup) {
            TextField("Phone number", text: $contactPhoneInput)
            Button("Save & Send") {
                emergencyContactPhone = contactPhoneInput
                mapVM.sendSafetyText(to: emergencyContactPhone)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a phone number to receive your safety alerts.")
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
