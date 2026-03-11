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
        /// Aerial orthophoto via Norkart/Geonorge open tile service (no API key required).
        /// Endpoint: https://opencache.statkart.no/gatekeeper/gk/gk.open_nib_web_mercator_wmts_v2
        case aerial
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
        let urlString: String

        if layer == .aerial {
            // Norge i bilder — Kartverket’s orthophoto WMTS (open, no API key required)
            // Docs: https://kartkatalog.geonorge.no/metadata/norge-i-bilder-wmts/072f32f4-3636-407c-ba97-0f7b1a2de839
            urlString =
                "https://opencache.statkart.no/gatekeeper/gk/gk.open_nib_web_mercator_wmts_v2" +
                "?SERVICE=WMTS" +
                "&REQUEST=GetTile" +
                "&VERSION=1.0.0" +
                "&LAYER=Nibcache_web_mercator_v2" +
                "&STYLE=default" +
                "&FORMAT=image/jpgpng" +
                "&TILEMATRIXSET=default028mm" +
                "&TILEMATRIX=\(path.z)" +
                "&TILEROW=\(path.y)" +
                "&TILECOL=\(path.x)"
        } else {
            // Kartverket provides WMTS tiles via KVP endpoint.
            // Template pattern is documented/used widely for Kartverket cache:
            // https://cache.kartverket.no/v1/service?layer=...&style=default&tilematrixset=webmercator&Service=WMTS&Request=GetTile...
            urlString =
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
        }

        if let url = URL(string: urlString) {
            return url
        }

        assertionFailure("Invalid Kartverket tile URL: \(urlString)")
        return URL(fileURLWithPath: "/")
    }
}
