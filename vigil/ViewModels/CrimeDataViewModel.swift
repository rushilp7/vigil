import Foundation
import SwiftUI
import SwiftData

@Observable
class CrimeDataViewModel {
    var isLoading = false
    var errorMessage: String?
    var incidents: [CrimeIncident] = []

    /// Stored in UserDefaults to track when we last fetched from the API.
    @ObservationIgnored
    @AppStorage("lastCrimeFetchDate") private var lastFetchTimestamp: Double = 0

    /// Load crime data: use cached SwiftData if fresh, otherwise fetch from API.
    func loadCrimeData(near latitude: Double, longitude: Double, context: ModelContext) async {
        // First, load whatever we have cached
        loadCachedIncidents(context: context)

        // Check if cache is stale (older than 24 hours) or empty
        let lastFetch = Date(timeIntervalSince1970: lastFetchTimestamp)
        let hoursElapsed = Date().timeIntervalSince(lastFetch) / 3600
        let cacheIsStale = hoursElapsed > 24 || incidents.isEmpty

        guard cacheIsStale else { return }

        // Fetch fresh data from the API
        isLoading = true
        errorMessage = nil

        do {
            let dtos = try await CrimeAPIService.instance.fetchCrimeData(
                latitude: latitude,
                longitude: longitude
            )

            // Clear old data and insert new
            try clearCachedIncidents(context: context)
            for dto in dtos {
                if let incident = CrimeIncident(from: dto) {
                    context.insert(incident)
                }
            }
            try context.save()

            // Update fetch timestamp
            lastFetchTimestamp = Date().timeIntervalSince1970

            // Reload from SwiftData to get the persisted objects
            loadCachedIncidents(context: context)

            isLoading = false
        } catch {
            isLoading = false
            // If we have cached data, just show a warning; otherwise show the error
            if incidents.isEmpty {
                errorMessage = "Failed to load crime data. Check your connection."
            } else {
                errorMessage = "Using cached data. Refresh failed."
            }
            print("Crime data fetch error: \(error)")
        }
    }

    private func loadCachedIncidents(context: ModelContext) {
        let descriptor = FetchDescriptor<CrimeIncident>()
        do {
            incidents = try context.fetch(descriptor)
        } catch {
            print("Failed to load cached incidents: \(error)")
        }
    }

    private func clearCachedIncidents(context: ModelContext) throws {
        let descriptor = FetchDescriptor<CrimeIncident>()
        let existing = try context.fetch(descriptor)
        for item in existing {
            context.delete(item)
        }
    }
}
