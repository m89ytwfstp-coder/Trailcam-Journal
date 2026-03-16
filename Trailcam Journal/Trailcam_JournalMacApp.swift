import SwiftUI

#if os(macOS)
@main
struct Trailcam_JournalMacApp: App {
    @StateObject private var store          = EntryStore()
    @StateObject private var locationStore  = LocationStore()
    @StateObject private var tripStore      = TripStore()
    @StateObject private var arrivalStore   = ArrivalStore()
    @StateObject private var nestboxStore   = NestboxStore()
    @StateObject private var customPinStore = CustomPinStore()

    init() {
        ProjectSelfChecks.run()
    }

    var body: some Scene {
        WindowGroup {
            ContentViewMac()
                .environmentObject(store)
                .environmentObject(locationStore)
                .environmentObject(tripStore)
                .environmentObject(arrivalStore)
                .environmentObject(nestboxStore)
                .environmentObject(customPinStore)
        }
    }
}
#endif
