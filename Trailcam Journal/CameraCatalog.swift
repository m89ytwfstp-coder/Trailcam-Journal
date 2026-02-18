//
//  CameraCatalog.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 30/12/2025.
//

import Foundation

struct CameraCatalog {

    static let brands: [String] = [
        "Zeiss",
        "Browning",
        "Reolink",
        "Spypoint",
        "Bushnell",
        "Hikmicro",
        "Bushwacker",
        "Biltema",
        "Reconyx"
    ]

    static let unknown = "Unknown camera"

    static let all: [String] = [unknown] + brands
}
