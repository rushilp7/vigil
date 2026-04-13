import Foundation

enum CrimeAPIError: Error {
    case invalidURL
    case networkError
    case decodingError
}

/// Fetches crime data from the Philadelphia Open Data Carto SQL API.
nonisolated class CrimeAPIService {
    static let instance = CrimeAPIService()

    /// Fetch crime incidents near a coordinate within a given radius and time range.
    func fetchCrimeData(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 2000,
        daysBack: Int = 90
    ) async throws -> [CrimeIncidentDTO] {
        // Compute bounding box (~0.000009 degrees per meter at Philly's latitude)
        let latDelta = radiusMeters * 0.000009
        let lngDelta = radiusMeters * 0.000011
        let latMin = latitude - latDelta
        let latMax = latitude + latDelta
        let lngMin = longitude - lngDelta
        let lngMax = longitude + lngDelta

        // Compute start date
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: startDate)

        let sql = """
        SELECT cartodb_id, dispatch_date_time, text_general_code, ucr_general, \
        point_x, point_y, dc_dist, location_block \
        FROM incidents_part1_part2 \
        WHERE dispatch_date_time >= '\(dateString)' \
        AND point_y BETWEEN \(latMin) AND \(latMax) \
        AND point_x BETWEEN \(lngMin) AND \(lngMax) \
        LIMIT 2000
        """

        var components = URLComponents(string: "https://phl.carto.com/api/v2/sql")!
        components.queryItems = [
            URLQueryItem(name: "q", value: sql)
        ]

        guard let url = components.url else {
            throw CrimeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200, httpResponse.statusCode <= 299 else {
            throw CrimeAPIError.networkError
        }

        do {
            let apiResponse = try JSONDecoder().decode(CrimeAPIResponse.self, from: data)
            return apiResponse.rows
        } catch {
            print("Decoding error: \(error)")
            throw CrimeAPIError.decodingError
        }
    }
}
