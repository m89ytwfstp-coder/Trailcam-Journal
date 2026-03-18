
//
//  MacDraftEditView.swift
//  Trailcam Journal
//
//  Two-column sheet: left = photo only + live-status pill overlay,
//  right = grey header + grouped form + action bar.
//  Location is picked via saved spots, GPS-from-photo, or an interactive map.
//

#if os(macOS)
import SwiftUI
import AppKit
import MapKit
import CoreLocation

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Draft edit view
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MacDraftEditView: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore
    @EnvironmentObject private var tripStore: TripStore
    @EnvironmentObject private var nestboxStore: NestboxStore
    @Environment(\.dismiss) private var dismiss

    let entryID: UUID
    /// When non-nil, called instead of environment dismiss — used by inline import pane.
    var onClose: (() -> Void)? = nil
    /// When true, layout is photo-on-top + form-below (used in import split view).
    var isInlineMode: Bool = false

    private func closeView() {
        if let onClose = onClose { onClose() }
        else { dismiss() }
    }

    // ── Edit state ───────────────────────────────────────────────────────────
    @State private var editEntryType:       EntryType = .sighting
    @State private var editTripID:          UUID?
    @State private var editNestboxID:       UUID?
    @State private var editDate:            Date   = Date()
    @State private var editSpecies:         String = ""
    @State private var editCamera:          String = CameraCatalog.unknown
    @State private var editNotes:           String = ""
    @State private var editTagsText:        String = ""
    @State private var editLocationUnknown: Bool   = false
    @State private var editLatitude:        Double?
    @State private var editLongitude:       Double?

    // Saved location picker
    @State private var selectedSavedLocation: String = ""

    // Weather (F8)
    @State private var editTemperatureC:  Double? = nil
    @State private var editWeatherSymbol: String? = nil
    @State private var editWindSpeedMs:   Double? = nil
    @State private var isFetchingWeather: Bool    = false
    @State private var weatherFetchTask:  Task<Void, Never>? = nil

    // Sheets / alerts
    @State private var showMapPicker:  Bool = false
    @State private var showPhotoZoom:  Bool = false
    @State private var confirmDelete:  Bool = false

    // ── Derived ──────────────────────────────────────────────────────────────
    private var entryIndex: Int?   { store.entries.firstIndex(where: { $0.id == entryID }) }
    private var entry: TrailEntry? { entryIndex.map { store.entries[$0] } }

    /// GPS extracted from original photo EXIF
    private var photoGPS: (lat: Double, lon: Double)? {
        guard let lat = entry?.latitude, let lon = entry?.longitude,
              lat != 0 || lon != 0 else { return nil }
        return (lat, lon)
    }

    private var hasCoordinates: Bool { editLatitude != nil && editLongitude != nil }

    private var canFinalizeNow: Bool {
        switch editEntryType {
        case .sighting:
            return !editSpecies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (editLocationUnknown || hasCoordinates)
        case .track:
            return editLocationUnknown || hasCoordinates
        case .fieldNote:
            return !editNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .nestbox:
            return editNestboxID != nil
        }
    }

    private var liveStatus: MacDraftStatus {
        switch editEntryType {
        case .sighting:
            let speciesTrimmed = editSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
            if speciesTrimmed.isEmpty { return .missingSpecies }
            if !editLocationUnknown && !hasCoordinates { return .missingLocation }
            return .ready
        case .track:
            if !editLocationUnknown && !hasCoordinates { return .missingLocation }
            return .ready
        case .fieldNote:
            if editNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .missingNotes }
            return .ready
        case .nestbox:
            if editNestboxID == nil { return .missingNestbox }
            return .ready
        }
    }

    // ── Body ─────────────────────────────────────────────────────────────────
    var body: some View {
        Group {
            if isInlineMode {
                VStack(spacing: 0) {
                    inlinePhotoPanel
                        .frame(height: 240)
                    Divider()
                    rightPanel
                }
            } else {
                HStack(spacing: 0) {
                    leftPhotoPanel
                        .frame(width: 280)
                    Divider()
                    rightPanel
                }
                .frame(minWidth: 800, minHeight: 560)
            }
        }
        .onAppear { loadEntry() }
        .alert("Delete draft?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let e = entry { store.deleteEntry(id: e.id) }
                closeView()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this draft and its photo.")
        }
        .sheet(isPresented: $showMapPicker) {
            MacDraftLocationPickerSheet(
                latitude:   $editLatitude,
                longitude:  $editLongitude,
                initialLat: editLatitude  ?? photoGPS?.lat,
                initialLon: editLongitude ?? photoGPS?.lon
            )
        }
        .sheet(isPresented: $showPhotoZoom) {
            MacPhotoZoomView(entry: entry)
        }
    }

    // ── Inline photo panel (horizontal strip at top) ─────────────────────────
    /// Used when isInlineMode = true: single large photo, aspect-fit,
    /// dark background for night shots, rounded corners 8pt.
    private var inlinePhotoPanel: some View {
        ZStack(alignment: .topLeading) {
            Color.black

            if let e = entry, let img = MacImageStore.loadImage(for: e) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MacThumbnail(entry: entry, cornerRadius: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Live-status pill
            HStack(spacing: 6) {
                Circle()
                    .fill(liveStatus.color)
                    .frame(width: 7, height: 7)
                Text(liveStatus.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(liveStatus.color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(10)

            // Expand icon
            VStack {
                HStack {
                    Spacer()
                    Button { showPhotoZoom = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .onTapGesture { showPhotoZoom = true }
    }

    // ── Left panel : photo only ───────────────────────────────────────────────
    private var leftPhotoPanel: some View {
        ZStack(alignment: .topLeading) {
            // Full-bleed photo — loads 1200 px display image; tappable to zoom
            Group {
                if let e = entry, let img = MacImageStore.loadImage(for: e) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MacThumbnail(entry: entry, cornerRadius: 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onTapGesture { showPhotoZoom = true }
            .contentShape(Rectangle())

            // Live-status pill — top-left
            HStack(spacing: 6) {
                Circle()
                    .fill(liveStatus.color)
                    .frame(width: 7, height: 7)
                Text(liveStatus.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(liveStatus.color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(10)

            // Expand icon — top-right
            VStack {
                HStack {
                    Spacer()
                    Button { showPhotoZoom = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }
                Spacer()
            }
        }
        .background(Color.black)
        .clipped()
    }

    // ── Right panel ───────────────────────────────────────────────────────────
    private var rightPanel: some View {
        VStack(spacing: 0) {

            // Header bar
            HStack {
                Text("Edit Draft")
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)
                Spacer()
                if !isInlineMode {
                    Button("Cancel") { closeView() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Form
            Form {
                detailsSection
                locationSection
                notesSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)

            Divider()

            // Action bar: Delete (left) | Save Draft + Finalise (right)
            HStack(spacing: 10) {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete Draft", systemImage: "trash")
                        .foregroundStyle(.red.opacity(0.85))
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Save Draft") {
                    saveEdits(finalize: false)
                    closeView()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Finalise →") {
                    saveEdits(finalize: true)
                    closeView()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canFinalizeNow)
                .help(canFinalizeNow
                      ? "Save and move to Entries"
                      : "Set a species and a location first")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    // MARK: Form sections

    @ViewBuilder
    private var detailsSection: some View {
        // Entry type picker — always first
        Section {
            Picker("Entry Type", selection: $editEntryType) {
                ForEach(EntryType.allCases, id: \.self) { et in
                    Label(et.label, systemImage: et.symbol).tag(et)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }

        Section("Details") {
            // Species: required for sighting, optional for track/nestbox, hidden for fieldNote
            if editEntryType != .fieldNote {
                speciesField(label: editEntryType == .sighting ? "Species" : "Species (optional)")
            }
            DatePicker("Date & Time", selection: $editDate,
                       displayedComponents: [.date, .hourAndMinute])
            // Camera: hidden for fieldNote and nestbox
            if editEntryType != .fieldNote && editEntryType != .nestbox {
                Picker("Camera", selection: $editCamera) {
                    ForEach(CameraCatalog.all, id: \.self) { Text($0).tag($0) }
                }
            }
            // Nestbox picker — required for .nestbox, hidden for other types
            if editEntryType == .nestbox {
                Picker("Nestbox", selection: $editNestboxID) {
                    Text("Select nestbox…").tag(Optional<UUID>.none)
                    ForEach(nestboxStore.nestboxes.sorted { $0.name < $1.name }) { box in
                        Text(box.name).tag(Optional(box.id))
                    }
                }
            }
            // Trip assignment
            if !tripStore.trips.isEmpty {
                Picker("Trip", selection: $editTripID) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(tripStore.trips.sorted { $0.date > $1.date }) { trip in
                        Text(trip.name).tag(Optional(trip.id))
                    }
                }
            }
            // Tags live in Details so they stay compact
            LabeledContent("Tags") {
                TextField("jerv, natt, snø…", text: $editTagsText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Species field (catalog Picker + free-text fallback)

    /// True when the current species value is NOT in the catalog (or is empty custom input).
    private var isCustomSpecies: Bool {
        !editSpecies.isEmpty && !SpeciesCatalog.all.map(\.nameNO).contains(editSpecies)
    }

    /// Binding that maps the catalog Picker selection — selects "custom" tag when
    /// the current value is free-text, clears for a fresh custom entry.
    private var catalogPickerBinding: Binding<String> {
        Binding(
            get: { isCustomSpecies ? "__custom__" : editSpecies },
            set: { newVal in
                if newVal == "__custom__" {
                    // Switch to free-text: clear so TextField gets focus
                    if !isCustomSpecies { editSpecies = "" }
                } else {
                    editSpecies = newVal
                }
            }
        )
    }

    @ViewBuilder
    private func speciesField(label: String) -> some View {
        Picker(label, selection: catalogPickerBinding) {
            Text("— select species —").tag("")
            ForEach(SpeciesGroup.allCases, id: \.self) { group in
                let groupSpecies = SpeciesCatalog.all
                    .filter { $0.group == group }
                    .sorted { $0.nameNO < $1.nameNO }
                if !groupSpecies.isEmpty {
                    Section(group.rawValue.capitalized) {
                        ForEach(groupSpecies) { s in
                            Text(s.nameNO).tag(s.nameNO)
                        }
                    }
                }
            }
            Divider()
            Text("Custom…").tag("__custom__")
        }
        if isCustomSpecies || catalogPickerBinding.wrappedValue == "__custom__" {
            TextField("Type species name…", text: $editSpecies)
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        Section {
            Toggle("Unknown location", isOn: $editLocationUnknown)

            if !editLocationUnknown {
                // ── GPS from photo ──────────────────────────────────────────
                if let gps = photoGPS {
                    Button {
                        editLatitude          = gps.lat
                        editLongitude         = gps.lon
                        selectedSavedLocation = ""
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(AppColors.primary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Use GPS from photo")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.primary)
                                Text(String(format: "%.5f, %.5f", gps.lat, gps.lon))
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                            if editLatitude == gps.lat && editLongitude == gps.lon {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppColors.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                // ── Saved location picker ───────────────────────────────────
                if !savedLocationStore.locations.isEmpty {
                    Picker("Saved spot", selection: $selectedSavedLocation) {
                        Text("Pick a saved spot…").tag("")
                        ForEach(savedLocationStore.locations) { loc in
                            Text(loc.name).tag(loc.name)
                        }
                    }
                    .onChange(of: selectedSavedLocation) { name in
                        guard !name.isEmpty,
                              let loc = savedLocationStore.locations.first(
                                  where: { $0.name == name }
                              )
                        else { return }
                        editLatitude  = loc.latitude
                        editLongitude = loc.longitude
                    }
                }

                // ── Map picker button ───────────────────────────────────────
                Button {
                    showMapPicker = true
                } label: {
                    Label("Pick on map…", systemImage: "map")
                        .foregroundStyle(AppColors.secondary)
                }
                .buttonStyle(.plain)

                // ── Current coordinates (read-only feedback) ────────────────
                if let lat = editLatitude, let lon = editLongitude {
                    LabeledContent("Coordinates") {
                        HStack(spacing: 8) {
                            Text(String(format: "%.5f, %.5f", lat, lon))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .monospacedDigit()
                            Button {
                                editLatitude          = nil
                                editLongitude         = nil
                                selectedSavedLocation = ""
                                editTemperatureC      = nil
                                editWeatherSymbol     = nil
                                editWindSpeedMs       = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // ── Weather row ───────────────────────────────────────────
                    LabeledContent("Weather") {
                        HStack(spacing: 10) {
                            if isFetchingWeather {
                                ProgressView().scaleEffect(0.7)
                                Text("Fetching…")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            } else if let symbol = editWeatherSymbol,
                                      let temp   = editTemperatureC,
                                      let wind   = editWindSpeedMs {
                                let snap = WeatherSnapshot(temperatureC: temp,
                                                           windSpeedMs: wind,
                                                           symbolCode: symbol)
                                Image(systemName: snap.sfSymbol)
                                    .foregroundStyle(AppColors.primary)
                                Text(snap.temperatureString)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.primary)
                                Text("· \(snap.windString)")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                Button {
                                    triggerWeatherFetch(lat: lat, lon: lon)
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    triggerWeatherFetch(lat: lat, lon: lon)
                                } label: {
                                    Label("Fetch weather", systemImage: "cloud")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Location")
        }
        .onChange(of: editLatitude)  { _ in scheduleWeatherFetch() }
        .onChange(of: editLongitude) { _ in scheduleWeatherFetch() }
    }

    @ViewBuilder
    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $editNotes)
                .frame(minHeight: 90, maxHeight: 160)
                .overlay(alignment: .topLeading) {
                    if editNotes.isEmpty {
                        Text("Add notes…")
                            .foregroundStyle(Color(nsColor: .placeholderTextColor))
                            .padding(.leading, 4).padding(.top, 5)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // ── Persistence ───────────────────────────────────────────────────────────
    private func loadEntry() {
        guard let e = entry else { return }
        editEntryType       = e.entryType
        editTripID          = e.tripID
        editNestboxID       = e.nestboxID
        editDate            = e.date
        editSpecies         = e.species ?? ""
        editCamera          = (e.camera?.isEmpty == false)
            ? (e.camera ?? CameraCatalog.unknown)
            : CameraCatalog.unknown
        editNotes           = e.notes
        editTagsText        = e.tags.joined(separator: ", ")
        editLocationUnknown = e.locationUnknown
        editLatitude        = e.latitude
        editLongitude       = e.longitude
        // Load persisted weather
        editTemperatureC    = e.temperatureC
        editWeatherSymbol   = e.weatherSymbol
        editWindSpeedMs     = e.windSpeedMs
        // Auto-fetch if we have coords but no weather yet
        if e.temperatureC == nil, let lat = e.latitude, let lon = e.longitude {
            triggerWeatherFetch(lat: lat, lon: lon)
        }
    }

    private func saveEdits(finalize: Bool) {
        guard let i = entryIndex else { return }
        store.entries[i].entryType       = editEntryType
        store.entries[i].tripID          = editTripID
        store.entries[i].nestboxID       = editNestboxID
        let speciesTrim = editSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
        store.entries[i].species         = speciesTrim.isEmpty ? nil : speciesTrim
        store.entries[i].date            = editDate
        let camTrim = editCamera.trimmingCharacters(in: .whitespacesAndNewlines)
        store.entries[i].camera          = (camTrim.isEmpty || camTrim == CameraCatalog.unknown) ? nil : camTrim
        store.entries[i].notes           = editNotes
        store.entries[i].tags            = parseTags(editTagsText)
        store.entries[i].locationUnknown = editLocationUnknown
        store.entries[i].latitude        = editLocationUnknown ? nil : editLatitude
        store.entries[i].longitude       = editLocationUnknown ? nil : editLongitude
        // Weather
        store.entries[i].temperatureC    = editTemperatureC
        store.entries[i].weatherSymbol   = editWeatherSymbol
        store.entries[i].windSpeedMs     = editWindSpeedMs
        if finalize { store.entries[i].isDraft = false }
    }

    private func scheduleWeatherFetch() {
        guard let lat = editLatitude, let lon = editLongitude else { return }
        triggerWeatherFetch(lat: lat, lon: lon)
    }

    private func triggerWeatherFetch(lat: Double, lon: Double) {
        weatherFetchTask?.cancel()
        isFetchingWeather = true
        weatherFetchTask = Task {
            if let snap = await WeatherService.fetch(lat: lat, lon: lon) {
                editTemperatureC  = snap.temperatureC
                editWeatherSymbol = snap.symbolCode
                editWindSpeedMs   = snap.windSpeedMs
            }
            isFetchingWeather = false
        }
    }

    private func parseTags(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Interactive map location picker sheet
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MacDraftLocationPickerSheet: View {
    @Binding var latitude:  Double?
    @Binding var longitude: Double?
    var initialLat: Double?
    var initialLon: Double?

    @Environment(\.dismiss) private var dismiss
    @State private var pickedCoord: CLLocationCoordinate2D?

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pick Location")
                        .font(.headline).foregroundStyle(AppColors.primary)
                    Text("Click on the map to place the camera pin. Drag to fine-tune.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)

            Divider()

            // Map
            MacDraftMapPickerNSView(
                pickedCoord: $pickedCoord,
                initialLat: initialLat,
                initialLon: initialLon
            )
            .ignoresSafeArea()

            Divider()

            // Footer
            HStack(spacing: 12) {
                if let c = pickedCoord {
                    Label(String(format: "%.5f,  %.5f", c.latitude, c.longitude),
                          systemImage: "location.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.primary)
                        .monospacedDigit()
                } else {
                    Text("No location selected")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Use This Location") {
                    if let c = pickedCoord {
                        latitude  = c.latitude
                        longitude = c.longitude
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(pickedCoord == nil)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
        }
        .frame(minWidth: 560, minHeight: 460)
        .onAppear {
            // Pre-populate with existing coordinates
            if let lat = initialLat, let lon = initialLon {
                pickedCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - MKMapView wrapper (click or drag to place pin)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MacDraftMapPickerNSView: NSViewRepresentable {
    @Binding var pickedCoord: CLLocationCoordinate2D?
    var initialLat: Double?
    var initialLon: Double?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> MKMapView {
        let mv = MKMapView(frame: .zero)
        mv.delegate = context.coordinator
        context.coordinator.mapView = mv

        // Kartverket topo tiles
        mv.addOverlay(KartverketTileOverlay(layer: .topo), level: .aboveLabels)
        mv.register(MKMarkerAnnotationView.self,
                    forAnnotationViewWithReuseIdentifier: "PickerPin")

        // Click-to-place gesture
        let click = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleClick(_:))
        )
        mv.addGestureRecognizer(click)

        // Initial region
        if let lat = initialLat, let lon = initialLon {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            mv.setRegion(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            ), animated: false)
            context.coordinator.placePin(at: coord, on: mv)
        } else {
            mv.setRegion(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 64.5, longitude: 17.0),
                span: MKCoordinateSpan(latitudeDelta: 14, longitudeDelta: 14)
            ), animated: false)
        }

        return mv
    }

    func updateNSView(_ mv: MKMapView, context: Context) {}

    // MARK: Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MacDraftMapPickerNSView
        weak var mapView: MKMapView?
        private var pin: MKPointAnnotation?

        init(parent: MacDraftMapPickerNSView) { self.parent = parent }

        @objc func handleClick(_ recognizer: NSClickGestureRecognizer) {
            guard let mv = mapView else { return }
            let pt    = recognizer.location(in: mv)
            let coord = mv.convert(pt, toCoordinateFrom: mv)
            placePin(at: coord, on: mv)
            DispatchQueue.main.async { self.parent.pickedCoord = coord }
        }

        func placePin(at coord: CLLocationCoordinate2D, on mv: MKMapView) {
            if let existing = pin { mv.removeAnnotation(existing) }
            let ann = MKPointAnnotation()
            ann.coordinate = coord
            mv.addAnnotation(ann)
            pin = ann
        }

        // Tile renderer
        func mapView(_ mv: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // Pin style
        func mapView(_ mv: MKMapView,
                     viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let view = mv.dequeueReusableAnnotationView(
                withIdentifier: "PickerPin", for: annotation
            ) as! MKMarkerAnnotationView
            view.markerTintColor = NSColor(AppColors.primary)
            view.glyphImage      = NSImage(systemSymbolName: "camera.fill",
                                           accessibilityDescription: nil)
            view.canShowCallout  = false
            view.isDraggable     = true
            return view
        }

        // Drag-to-reposition
        func mapView(_ mv: MKMapView,
                     annotationView view: MKAnnotationView,
                     didChange newState: MKAnnotationView.DragState,
                     fromOldState oldState: MKAnnotationView.DragState) {
            if newState == .ending, let ann = view.annotation {
                DispatchQueue.main.async {
                    self.parent.pickedCoord = ann.coordinate
                }
            }
        }
    }
}
#endif
