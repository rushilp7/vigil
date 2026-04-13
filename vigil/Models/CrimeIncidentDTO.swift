import Foundation

/// API response wrapper from the Carto SQL endpoint
nonisolated struct CrimeAPIResponse: Codable, Sendable {
    let rows: [CrimeIncidentDTO]
}

/// Codable struct for decoding crime incidents from the Philadelphia Crime API.
/// This is the network-layer type; use CrimeIncident (@Model) for persistence.
nonisolated struct CrimeIncidentDTO: Codable, Sendable {
    let cartodbId: Int
    let dispatchDateTime: String
    let textGeneralCode: String
    let ucrGeneral: String?
    let pointX: Double?
    let pointY: Double?
    let dcDist: String?
    let locationBlock: String?

    enum CodingKeys: String, CodingKey {
        case cartodbId = "cartodb_id"
        case dispatchDateTime = "dispatch_date_time"
        case textGeneralCode = "text_general_code"
        case ucrGeneral = "ucr_general"
        case pointX = "point_x"
        case pointY = "point_y"
        case dcDist = "dc_dist"
        case locationBlock = "location_block"
    }
}
