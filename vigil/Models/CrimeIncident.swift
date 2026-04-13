import Foundation
import SwiftData

/// Persisted crime incident stored in SwiftData for offline access.
@Model
class CrimeIncident {
    @Attribute(.unique) var cartodbId: Int
    var dispatchDateTime: String
    var textGeneralCode: String
    var ucrGeneral: String
    var latitude: Double
    var longitude: Double
    var dcDist: String
    var locationBlock: String

    init(cartodbId: Int, dispatchDateTime: String, textGeneralCode: String,
         ucrGeneral: String, latitude: Double, longitude: Double,
         dcDist: String, locationBlock: String) {
        self.cartodbId = cartodbId
        self.dispatchDateTime = dispatchDateTime
        self.textGeneralCode = textGeneralCode
        self.ucrGeneral = ucrGeneral
        self.latitude = latitude
        self.longitude = longitude
        self.dcDist = dcDist
        self.locationBlock = locationBlock
    }

    /// Create a persisted CrimeIncident from an API DTO.
    /// Returns nil if the DTO is missing coordinates.
    convenience init?(from dto: CrimeIncidentDTO) {
        guard let lat = dto.pointY, let lng = dto.pointX else { return nil }
        self.init(
            cartodbId: dto.cartodbId,
            dispatchDateTime: dto.dispatchDateTime,
            textGeneralCode: dto.textGeneralCode,
            ucrGeneral: dto.ucrGeneral ?? "0",
            latitude: lat,
            longitude: lng,
            dcDist: dto.dcDist ?? "",
            locationBlock: dto.locationBlock ?? ""
        )
    }

    var category: CrimeCategory {
        CrimeCategory.from(ucrCode: ucrGeneral)
    }
}
