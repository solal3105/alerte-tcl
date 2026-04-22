//
//  CoordinateParsing.swift
//  AlerteTCL
//
//  Single source of truth for parsing GeoJSON [lon, lat] coordinate pairs.
//  Validates bounds to prevent MapKit crashes on NaN / out-of-range values.
//

import CoreLocation

extension CLLocationCoordinate2D {
    /// Builds a coordinate from a GeoJSON pair `[longitude, latitude]`.
    /// Returns nil if the array is too short, contains non-finite values,
    /// or is outside valid ranges.
    static func fromGeoJSON(_ pair: [Double]) -> CLLocationCoordinate2D? {
        guard pair.count >= 2 else { return nil }
        let lon = pair[0]
        let lat = pair[1]
        guard lon.isFinite, lat.isFinite else { return nil }
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return CLLocationCoordinate2DIsValid(coord) ? coord : nil
    }
}
