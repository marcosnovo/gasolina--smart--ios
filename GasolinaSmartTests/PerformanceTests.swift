import XCTest
import CoreLocation
@testable import GasolinaSmart

final class PerformanceTests: XCTestCase {

    private func mockStations(count: Int, country: Country = .italy) -> [FuelStation] {
        (0..<count).map { i in
            FuelStation(
                id: "\(country.rawValue)_\(i)",
                name: "Station \(i)",
                brand: ["Eni", "Q8", "Tamoil", "Esso", "IP"][i % 5],
                address: "Via Test \(i)",
                municipality: "City \(i % 100)",
                province: "PR",
                latitude: 35.5 + Double(i % 1000) * 0.01,
                longitude: 6.6 + Double(i / 1000) * 0.01,
                prices: [.e5: Decimal(string: "1.\(800 + i % 200)")!,
                         .dieselA: Decimal(string: "1.\(700 + i % 200)")!],
                lastUpdated: Date(),
                country: country
            )
        }
    }

    // B.2.2 — Sort 21k stations by distance
    func test_perf_sort21kStationsByDistance() {
        let stations = mockStations(count: 21_000)
        let userLocation = CLLocation(latitude: 41.9028, longitude: 12.4964)

        measure {
            let _ = stations.sorted { lhs, rhs in
                lhs.distance(from: userLocation) < rhs.distance(from: userLocation)
            }
        }
    }

    // B.2.3 — Filter favorites from 21k stations
    func test_perf_filterFavoritesFrom21kStations() {
        let stations = mockStations(count: 21_000)
        let favoriteIDs: Set<String> = Set((0..<50).map { "IT_\($0)" })

        measure {
            let _ = stations.filter { favoriteIDs.contains($0.id) }
        }
    }
}
