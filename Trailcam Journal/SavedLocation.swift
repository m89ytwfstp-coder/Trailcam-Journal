//
//  SavedLocation.swift
//  Trailcam Journal
//
//  SavedLocation has been merged into the unified Location type.
//  See Location.swift and LocationStore.swift.
//

// ── SavedLocation vs Hub (boundary decision, 2026-03) ───────────────────────
// SavedLocation: cross-platform bookmark. Created from an entry's GPS position.
//               Shown in iOS entry detail ("Save location") and on Mac map.
//               Represents a place Simon has observed something.
//
// Hub: macOS-only management concept. Created by right-clicking the Mac map.
//      Represents a planning/logistics point (cabin, rendezvous, access point).
//      NOT the same as a wildlife observation location.
//
// These two models should NOT be merged until there is a strong reason.
// If a future feature needs both on iOS, introduce a shared protocol — do not
// collapse the models unless their semantics truly converge.
//
// NOTE (2026-03): Both SavedLocation and Hub are now unified under Location
// (Location.swift / LocationStore.swift). The semantic distinction above still
// holds: Location.radius == nil = SavedLocation bookmark,
//         Location.radius != nil = Hub area.
// ─────────────────────────────────────────────────────────────────────────────

typealias SavedLocation = Location
