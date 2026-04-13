import Foundation
import SwiftUI
import SwiftData
import CoreLocation

@Observable
class CrimeDataViewModel {
    var isLoading = false
    var errorMessage: String?
    var incidents: [CrimeIncident] = []
    var avoidanceZones: [AvoidanceZone] = []

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

        guard cacheIsStale else {
            computeAvoidanceZones()
            return
        }

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
            computeAvoidanceZones()

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

    // MARK: - Avoidance Zone Clustering

    /// Grid-based clustering: divide the area into ~200m cells,
    /// sum severity-weighted incidents per cell, flag cells above threshold.
    private func computeAvoidanceZones() {
        guard !incidents.isEmpty else {
            avoidanceZones = []
            return
        }

        // ~200m in degrees at Philadelphia's latitude
        let cellSize = 0.002

        // Group incidents into grid cells
        var grid: [String: (count: Int, weightedScore: Int, latSum: Double, lngSum: Double)] = [:]

        for incident in incidents {
            let row = Int(incident.latitude / cellSize)
            let col = Int(incident.longitude / cellSize)
            let key = "\(row),\(col)"

            var cell = grid[key] ?? (count: 0, weightedScore: 0, latSum: 0, lngSum: 0)
            cell.count += 1
            cell.weightedScore += incident.category.weight
            cell.latSum += incident.latitude
            cell.lngSum += incident.longitude
            grid[key] = cell
        }

        // Convert high-density cells into avoidance zones
        // Threshold: cells with weighted score >= 6 (e.g. 2 violent crimes or 6 thefts)
        let threshold = 6
        avoidanceZones = grid.values.compactMap { cell in
            guard cell.weightedScore >= threshold else { return nil }

            let centerLat = cell.latSum / Double(cell.count)
            let centerLng = cell.lngSum / Double(cell.count)

            let severity: CrimeCategory.Severity
            let avgWeight = Double(cell.weightedScore) / Double(cell.count)
            if avgWeight >= 2.5 {
                severity = .high
            } else if avgWeight >= 1.5 {
                severity = .medium
            } else {
                severity = .low
            }

            return AvoidanceZone(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
                radius: 150,
                severity: severity,
                incidentCount: cell.count
            )
        }
    }
}
