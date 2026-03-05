//
//  LocationManager.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 18/12/2025.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published var lastLocation: CLLocation?
    /// Set to true when the user has denied or restricted location access.
    /// Views can observe this to present a Settings deep-link alert.
    @Published var isPermissionDenied: Bool = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        let status = manager.authorizationStatus
        switch status {
        case .denied, .restricted:
            isPermissionDenied = true
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        isPermissionDenied = (status == .denied || status == .restricted)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clError = error as? CLError
        if clError?.code == .denied {
            isPermissionDenied = true
        }
        print("❌ LocationManager: \(error.localizedDescription)")
    }
}
