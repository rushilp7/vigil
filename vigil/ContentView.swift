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
    @AppStorage("autoSendSafetyText") private var autoSendSafetyText = false

    private func triggerCrimeAndRoute() {
        guard let mid = mapVM.routeMidpoint,
              let radius = mapVM.routeRadiusMeters else { return }
        Task {
            await crimeDataVM.loadCrimeData(
                near: mid.latitude,
                longitude: mid.longitude,
                radiusMeters: radius,
                forceRefresh: true,
                context: modelContext
            )
            await mapVM.tryCalculateRoute(avoiding: crimeDataVM.avoidanceZones)
        }
    }

    // MARK: - POI styling

    /// Small colored badge marker rendered above each business along the route.
    /// Extracted so the SwiftUI type-checker doesn't have to solve it inline.
    private struct POIMarker: View {
        let category: MKPointOfInterestCategory?

        var body: some View {
            ZStack {
                Circle()
                    .fill(ContentView.poiTint(for: category))
                    .frame(width: 22, height: 22)
                    .shadow(radius: 1)
                Image(systemName: ContentView.poiIcon(for: category))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    static func poiIcon(for category: MKPointOfInterestCategory?) -> String {
        guard let category else { return "mappin" }
        switch category {
        case .restaurant:           return "fork.knife"
        case .cafe:                 return "cup.and.saucer.fill"
        case .bakery:               return "birthday.cake.fill"
        case .foodMarket:           return "cart.fill"
        case .store:                return "bag.fill"
        case .gasStation:           return "fuelpump.fill"
        case .pharmacy:             return "cross.case.fill"
        case .hotel:                return "bed.double.fill"
        case .nightlife:            return "wineglass.fill"
        case .hospital:             return "cross.fill"
        case .police:               return "shield.fill"
        case .fireStation:          return "flame.fill"
        case .library:              return "books.vertical.fill"
        case .museum:               return "building.columns.fill"
        case .bank:                 return "dollarsign.circle.fill"
        case .atm:                  return "banknote.fill"
        case .school, .university:  return "graduationcap.fill"
        default:                    return "mappin"
        }
    }

    static func poiTint(for category: MKPointOfInterestCategory?) -> Color {
        guard let category else { return .gray }
        switch category {
        case .police, .hospital, .fireStation, .pharmacy:
            return .red
        case .restaurant, .cafe, .bakery, .foodMarket, .nightlife:
            return .orange
        case .store, .hotel, .bank, .atm, .gasStation:
            return .blue
        case .library, .museum, .school, .university:
            return .purple
        default:
            return .gray
        }
    }

    @MapContentBuilder
    private var mapContent: some MapContent {
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

        // Rejected alternate routes (gray, dashed) — hidden during navigation or selection
        if !mapVM.isNavigating && !mapVM.pendingRouteSelection {
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

        // Businesses along the selected route — small colored circles with a
        // category icon. Visible whether or not we're actively navigating.
        ForEach(Array(mapVM.routeBusinesses.enumerated()), id: \.offset) { _, poi in
            Annotation(
                poi.name ?? "",
                coordinate: poi.placemark.coordinate,
                anchor: .center
            ) {
                POIMarker(category: poi.pointOfInterestCategory)
            }
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

    // MARK: - Overlay content

    @ViewBuilder
    private var topOverlay: some View {
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

    @ViewBuilder
    private var legendOverlay: some View {
        if !crimeDataVM.avoidanceZones.isEmpty && mapVM.route == nil {
            CrimeLegendView(zoneCount: crimeDataVM.avoidanceZones.count,
                            incidentCount: crimeDataVM.incidents.count)
                .padding(.leading, 8)
                .padding(.bottom, 80)
        }
    }

    private var safetyButtonsOverlay: some View {
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

    @ViewBuilder
    private var bottomBannerOverlay: some View {
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
                    routeRank: mapVM.selectedRouteRank ?? 1,
                    nearbyBusinessCount: mapVM.selectedScoredRoute?.nearbyBusinessCount ?? 0,
                    onGo: { mapVM.startNavigation() },
                    onSteps: { showRouteSteps = true },
                    onClear: { mapVM.showRouteSelector() }
                )
            } else if let error = mapVM.routeError {
                routeErrorBanner(error)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    private func routeErrorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
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

    // MARK: - Body chunks
    //
    // The body is split into three layered computed properties so the SwiftUI
    // type-checker can resolve each segment independently. Combining everything
    // into one expression triggers "unable to type-check in reasonable time."

    private var mapView: some View {
        Map(position: $cameraPosition) {
            mapContent
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .mapStyle(.standard)
        .onTapGesture {
            // Dismiss search results when tapping the map
            mapVM.activeField = nil
            mapVM.sourceResults = []
            mapVM.destinationResults = []
        }
    }

    private var mapWithOverlays: some View {
        mapView
            .overlay(alignment: .top) { topOverlay }
            .overlay(alignment: .bottomLeading) { legendOverlay }
            .overlay(alignment: .bottomTrailing) { safetyButtonsOverlay }
            .overlay(alignment: .bottom) { bottomBannerOverlay }
    }

    private var mapWithLifecycle: some View {
        mapWithOverlays
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
            }
            .onChange(of: mapVM.selectedSource) { triggerCrimeAndRoute() }
            .onChange(of: mapVM.selectedDestination) { triggerCrimeAndRoute() }
            .onChange(of: mapVM.route) { _, newRoute in
                guard newRoute != nil,
                      let src = mapVM.selectedSource?.placemark.coordinate else { return }
                cameraPosition = .region(MKCoordinateRegion(
                    center: src,
                    span: MKCoordinateSpan(latitudeDelta: lastSpan, longitudeDelta: lastSpan)
                ))
            }
            .onChange(of: motionManager.isShakeDetected) { _, detected in
                if detected {
                    showEmergency = true
                    motionManager.resetShakeDetection()
                }
            }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
                guard mapVM.isNavigating, mapVM.shouldShowETAAlert else { return }
                let phone = emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
                if autoSendSafetyText && !phone.isEmpty {
                    // Skip the confirmation prompt — fire the safety text immediately.
                    mapVM.sendSafetyText(to: emergencyContactPhone)
                } else {
                    showETAAlert = true
                }
            }
    }

    var body: some View {
        mapWithLifecycle
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
            .sheet(
                isPresented: Binding(
                    get: { mapVM.pendingRouteSelection },
                    set: { mapVM.pendingRouteSelection = $0 }
                ),
                onDismiss: {
                    // Only cancel (clear state) if the user dismissed without selecting a route
                    if mapVM.route == nil {
                        mapVM.cancelRouteSelection()
                    }
                }
            ) {
                RouteSelectionView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("Error", isPresented: .init(
                get: { crimeDataVM.errorMessage != nil },
                set: { if !$0 { crimeDataVM.errorMessage = nil } }
            )) {
                Button("Retry") { triggerCrimeAndRoute() }
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
