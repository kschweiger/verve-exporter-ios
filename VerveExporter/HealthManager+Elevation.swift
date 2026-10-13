import CoreLocation
import Foundation

typealias GeoidUndulationProvider = (Double, Double) throws -> Double

extension HealthManager {
    /// HealthKit persists approximate sea-level altitude, not ellipsoidal altitude.
    func ellipsoidalElevations(
        for locations: [CLLocation],
        geoidUndulation: GeoidUndulationProvider?
    ) throws -> [Double] {
        guard !locations.isEmpty else {
            return []
        }
        guard locations.count >= 2 else {
            throw GeoJSONExportError.routeTooShort
        }
        for (index, location) in locations.enumerated() {
            guard location.altitude.isFinite,
                  location.verticalAccuracy.isFinite, location.verticalAccuracy > 0,
                  location.horizontalAccuracy.isFinite, location.horizontalAccuracy >= 0,
                  CLLocationCoordinate2DIsValid(location.coordinate)
            else {
                throw GeoJSONExportError.invalidElevation(pointIndex: index)
            }
        }
        let provider: GeoidUndulationProvider
        if let geoidUndulation {
            provider = geoidUndulation
        } else {
            do {
                let grid = try BundledGeoidGrid.cached.get()
                provider = grid.undulationMeters
            } catch {
                throw GeoJSONExportError.geoidModelUnavailable
            }
        }
        return try locations.enumerated().map { index, location in
            let undulation: Double
            do {
                undulation = try provider(location.coordinate.latitude, location.coordinate.longitude)
            } catch {
                throw GeoJSONExportError.geoidModelUnavailable
            }
            let height = location.altitude + undulation
            guard undulation.isFinite, height.isFinite else {
                throw GeoJSONExportError.invalidElevation(pointIndex: index)
            }
            return height
        }
    }
}
