import Foundation

struct DeeplinkResult {
    let stationId: String
    let country: Country
}

enum DeeplinkParser {
    private static let countryPrefixes = ["ES_", "GB_", "FR_", "DE_", "IT_"]

    static func parse(_ url: URL) -> DeeplinkResult? {
        guard url.scheme == WidgetConstants.urlScheme,
              url.host == "station",
              let rawId = url.pathComponents.dropFirst().first else {
            return nil
        }

        if countryPrefixes.contains(where: { rawId.hasPrefix($0) }) {
            let prefix = String(rawId.split(separator: "_").first ?? "ES")
            let country = Country(rawValue: prefix) ?? .spain
            return DeeplinkResult(stationId: rawId, country: country)
        } else {
            return DeeplinkResult(stationId: "ES_\(rawId)", country: .spain)
        }
    }
}
