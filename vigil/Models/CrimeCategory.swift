import SwiftUI

/// Maps UCR general codes to human-readable categories with severity and color.
enum CrimeCategory: String, CaseIterable {
    case homicide = "100"
    case rape = "200"
    case robbery = "300"
    case aggravatedAssault = "400"
    case burglary = "500"
    case theft = "600"
    case motorVehicleTheft = "700"
    case otherAssaults = "800"
    case other = "0"

    enum Severity: Int, Comparable {
        case high = 3
        case medium = 2
        case low = 1

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var severity: Severity {
        switch self {
        case .homicide, .rape, .robbery, .aggravatedAssault:
            return .high
        case .burglary, .motorVehicleTheft, .otherAssaults:
            return .medium
        case .theft, .other:
            return .low
        }
    }

    var color: Color {
        switch severity {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        }
    }

    var label: String {
        switch self {
        case .homicide: return "Homicide"
        case .rape: return "Rape"
        case .robbery: return "Robbery"
        case .aggravatedAssault: return "Aggravated Assault"
        case .burglary: return "Burglary"
        case .theft: return "Theft"
        case .motorVehicleTheft: return "Motor Vehicle Theft"
        case .otherAssaults: return "Other Assaults"
        case .other: return "Other"
        }
    }

    /// Severity weight used for avoidance zone computation.
    var weight: Int { severity.rawValue }

    static func from(ucrCode: String) -> CrimeCategory {
        // UCR codes can be like "100", "200", etc. Take the hundreds digit.
        let hundreds = String(ucrCode.prefix(1)) + "00"
        return CrimeCategory(rawValue: hundreds) ?? .other
    }
}
