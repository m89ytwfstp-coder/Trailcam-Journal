//
//  Untitled.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 08/01/2026.
//

import Foundation
import MapKit

/// Kartverket/Norgeskart-style tiles using Kartverket WMTS cache.
/// Source: https://cache.kartverket.no (WMTS cache for topo/topograatone/toporaster)
/// Terms/attribution: https://www.kartverket.no/en/api-and-data/terms-of-use
final class KartverketTileOverlay: MKTileOverlay {

    enum Layer: String {
        case topo
        case topograatone
        case toporaster
    }

    private let layer: Layer

    init(layer: Layer) {
        self.layer = layer
        super.init(urlTemplate: nil)

        // Kartverket cache tiles are 256x256
        self.tileSize = CGSize(width: 256, height: 256)

        // Important: this replaces Apple’s base map content
        self.canReplaceMapContent = true
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        // Kartverket provides WMTS tiles via KVP endpoint.
        // We map MKTileOverlay z/x/y to WMTS TileMatrix/TileCol/TileRow.
        //
        // Template pattern is documented/used widely for Kartverket cache:
        // https://cache.kartverket.no/v1/service?layer=...&style=default&tilematrixset=webmercator&Service=WMTS&Request=GetTile...
        // (Kartverket’s official cache service is cache.kartverket.no.)
        let urlString =
        "https://cache.kartverket.no/v1/service" +
        "?layer=\(layer.rawValue)" +
        "&style=default" +
        "&tilematrixset=webmercator" +
        "&Service=WMTS" +
        "&Request=GetTile" +
        "&Version=1.0.0" +
        "&Format=image/png" +
        "&TileMatrix=\(path.z)" +
        "&TileCol=\(path.x)" +
        "&TileRow=\(path.y)"

        if let url = URL(string: urlString) {
            return url
        }

        assertionFailure("Invalid Kartverket tile URL: \(urlString)")
        return URL(fileURLWithPath: "/")
    }
}
