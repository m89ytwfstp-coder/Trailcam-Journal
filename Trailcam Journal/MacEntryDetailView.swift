
//
//  MacEntryDetailView.swift
//  Trailcam Journal
//
//  Two-column sheet for viewing and editing finalised entries on macOS.
//  Left  : photo only (full-bleed) + fullscreen zoom button.
//  Right : grey header bar, then scrollable section cards (view mode)
//          or a grouped Form (edit mode).
//

#if os(macOS)
import SwiftUI
import MapKit
import AppKit
import CoreLocation

struct MacEntryDetailView: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore
    @EnvironmentObject private var tripStore: TripStore
    @EnvironmentObject private var nestboxStore: NestboxStore
    @Environment(\.dismiss) private var dismiss

    let entryID: UUID

    // ── Edit state ───────────────────────────────────────────────────────────
    @State private var isEditing            = false
    @State private var editTripID:          UUID?
    @State private var editNestboxID:       UUID?
    @State private var editDate:            Date    = Date()
    @State private var editSpecies:         String  = ""
    @State private var editCamera:          String  = CameraCatalog.unknown
    @State private var editNotes:           String  = ""
    @State private var editTagsText:        String  = ""
    @State private var editLocationUnknown: Bool    = false
    @State private var editLatitude:        Double? = nil
    @State private var editLongitude:       Double? = nil
    @State private var selectedSavedLocation: String = ""

    // ── Sheets ───────────────────────────────────────────────────────────────
    @State private var showPhotoZoom = false
    @State private var showMapPicker = false

    // ── Alerts ───────────────────────────────────────────────────────────────
    @State private var confirmDelete         = false
    @State private var showSaveLocationAlert = false
    @State private var saveLocationName      = ""
    @State private var pendingSaveLat: Double = 0
    @State private var pendingSaveLon: Double = 0
    @State private var showDuplicateAlert    = false
    @State private var duplicateMessage      = ""

    // ── Derived ──────────────────────────────────────────────────────────────
    private var entryIndex: Int?   { store.entries.firstIndex(where: { $0.id == entryID }) }
    private var entry: TrailEntry? { entryIndex.map { store.entries[$0] } }

    // ── Body ─────────────────────────────────────────────────────────────────
    var body: some View {
        HStack(spacing: 0) {
            leftPhotoPanel
                .frame(width: 300)
            Divider()
            rightPanel
        }
        .frame(minWidth: 820, minHeight: 560)
        .onAppear { loadEntry() }
        // Alerts
        .alert("Delete entry?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let e = entry { store.deleteEntry(id: e.id) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This will permanently delete this entry and its photo.") }
        .alert("Save location", isPresented: $showSaveLocationAlert) {
            TextField("Name", text: $saveLocationName)
            Button("Save") { commitSaveLocation() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Save this GPS position as a pinned location.") }
        .alert("Already saved", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(duplicateMessage) }
        // Sheets
        .sheet(isPresented: $showPhotoZoom) {
            MacPhotoZoomView(entry: entry)
        }
        .sheet(isPresented: $showMapPicker) {
            MacDraftLocationPickerSheet(
                latitude:   $editLatitude,
                longitude:  $editLongitude,
                initialLat: editLatitude  ?? entry?.latitude,
                initialLon: editLongitude ?? entry?.longitude
            )
        }
    }

    // ── Left panel : photo only ───────────────────────────────────────────────

    /// Always loads the 1200 px display image — never the 400 px thumbnail.
    /// (12f: list views use MacThumbnail/loadThumbnail; detail must use loadImage.)
    private func loadDetailImage() -> NSImage? {
        guard let name = entry?.photoFilename,
              let url  = MacImageStore.fileURL(for: name) else { return nil }
        return NSImage(contentsOf: url)
    }

    private var leftPhotoPanel: some View {
        ZStack(alignment: .topTrailing) {
            // Full-bleed 1200 px display image — not the 400 px list thumbnail
            Group {
                if let img = loadDetailImage() {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.black
                        .overlay {
                            Image(systemName: entry?.entryType.symbol ?? "photo")
                                .font(.system(size: 40, weight: .thin))
                                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { showPhotoZoom = true }

            // Zoom button overlay
            Button { showPhotoZoom = true } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.semibold))
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
        .background(Color.black)
        .clipped()
    }

    // ── Right panel ───────────────────────────────────────────────────────────
    private var rightPanel: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if isEditing {
                editForm
            } else {
                viewContent
            }
        }
    }

    // Grey title bar at the top of the right column
    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(entry?.displayTitle ?? "Unknown")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(1)
                    if let et = entry?.entryType {
                        Image(systemName: et.symbol)
                            .font(.caption)
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    }
                }
                Text((entry?.date ?? Date()).formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            if isEditing {
                Button("Cancel") { isEditing = false }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { saveEdits(); isEditing = false }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Edit")  { beginEditing() }
                Button("Close") { dismiss() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // ── View-mode scrollable content ─────────────────────────────────────────
    private var viewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Details ──────────────────────────────────────────────────
                sectionCard("Details") {
                    detailRow("Type", entry?.entryType.label ?? "Sighting")
                    Divider().padding(.leading, 14)
                    if entry?.entryType != .fieldNote {
                        detailRow("Species", entry?.species ?? "—")
                        Divider().padding(.leading, 14)
                    }
                    detailRow("Date",
                              (entry?.date ?? Date())
                                  .formatted(date: .long, time: .shortened))
                    if entry?.entryType != .fieldNote {
                        Divider().padding(.leading, 14)
                        detailRow("Camera",
                                  (entry?.camera?.isEmpty == false)
                                      ? entry!.camera!
                                      : "—")
                    }
                    if let tid = entry?.tripID,
                       let trip = tripStore.trips.first(where: { $0.id == tid }) {
                        Divider().padding(.leading, 14)
                        detailRow("Trip", trip.name)
                    }
                    if let nid = entry?.nestboxID,
                       let box  = nestboxStore.nestboxes.first(where: { $0.id == nid }) {
                        Divider().padding(.leading, 14)
                        detailRow("Nestbox", box.name)
                    }
                }

                // ── Conditions (weather + sun/moon) ─────────────────────────
                if entry?.temperatureC != nil
                    || (entry?.latitude != nil && entry?.longitude != nil) {
                    sectionCard("Conditions") {
                        conditionsSection
                    }
                }

                // ── Location ─────────────────────────────────────────────────
                sectionCard("Location") {
                    locationViewSection
                }

                // ── Notes ────────────────────────────────────────────────────
                sectionCard("Notes") {
                    notesViewSection
                }

                // ── Delete at bottom ─────────────────────────────────────────
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete Entry", systemImage: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.red.opacity(0.85))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .padding(.bottom, 8)
        }
        .background(AppColors.background)
    }

    // Section card: grey title + white rounded card
    @ViewBuilder
    private func sectionCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // P7: sentence case, 13pt semibold, primary label color (not all-caps/low-contrast)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }

    // Label / value row
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppColors.primary.opacity(0.8))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // Location section content (view mode)
    @ViewBuilder
    private var locationViewSection: some View {
        if entry?.locationUnknown == true {
            HStack(spacing: 8) {
                Image(systemName: "location.slash")
                    .foregroundStyle(.secondary)
                Text("Location unknown")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        } else if let lat = entry?.latitude, let lon = entry?.longitude {
            VStack(alignment: .leading, spacing: 0) {
                // Large map
                locationMapView(lat: lat, lon: lon)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                // Coordinates row + Save as pinned button
                HStack {
                    Text(String(format: "%.5f,  %.5f", lat, lon))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Button {
                        startSaveLocationPrompt(lat: lat, lon: lon)
                    } label: {
                        Label("Save as pinned", systemImage: "bookmark")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "location")
                    .foregroundStyle(.secondary)
                Text("No GPS data")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    // Notes + tags section content (view mode)
    @ViewBuilder
    private var notesViewSection: some View {
        if (entry?.tags ?? []).isEmpty && (entry?.notes ?? "").isEmpty {
            Text("No notes or tags")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        } else {
            // Tags
            if !(entry?.tags ?? []).isEmpty {
                entryTagsView
            }
            // Divider between tags and notes
            if !(entry?.tags ?? []).isEmpty && !(entry?.notes ?? "").isEmpty {
                Divider().padding(.leading, 14)
            }
            // Notes
            if !(entry?.notes ?? "").isEmpty {
                Text(entry?.notes ?? "")
                    .font(.body)
                    .foregroundStyle(AppColors.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
    }

    // ── Conditions: weather + sun/moon ───────────────────────────────────────
    @ViewBuilder
    private var conditionsSection: some View {
        VStack(spacing: 0) {
            // Weather row
            if let symbol = entry?.weatherSymbol,
               let temp   = entry?.temperatureC,
               let wind   = entry?.windSpeedMs {
                let snap = WeatherSnapshot(temperatureC: temp,
                                           windSpeedMs: wind,
                                           symbolCode: symbol)
                condRow(icon: snap.sfSymbol, iconColor: .blue) {
                    Text(snap.temperatureString)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primary)
                    Text("·")
                        .foregroundStyle(AppColors.textSecondary)
                    Text(snap.windString)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("·")
                        .foregroundStyle(AppColors.textSecondary)
                    Text(symbol.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }

            // Sun times row
            if let lat = entry?.latitude, let lon = entry?.longitude {
                let date   = entry?.date ?? Date()
                let sun    = SunMoonCalculator.sunTimes(for: date, lat: lat, lon: lon)
                let moon   = SunMoonCalculator.moonPhase(for: date)
                let timeFmt = Date.FormatStyle().hour().minute()

                Divider().padding(.leading, 38)

                condRow(icon: "sun.horizon.fill", iconColor: .orange) {
                    if sun.isPolDay {
                        Text("Midnight sun").font(.subheadline).foregroundStyle(AppColors.textSecondary)
                    } else if sun.isPolNight {
                        Text("Polar night").font(.subheadline).foregroundStyle(AppColors.textSecondary)
                    } else {
                        if let rise = sun.sunrise {
                            Image(systemName: "sunrise.fill")
                                .font(.caption).foregroundStyle(.orange)
                            Text(rise.formatted(timeFmt))
                                .font(.subheadline).foregroundStyle(AppColors.primary)
                        }
                        if sun.sunrise != nil && sun.sunset != nil {
                            Text("·").foregroundStyle(AppColors.textSecondary)
                        }
                        if let set = sun.sunset {
                            Image(systemName: "sunset.fill")
                                .font(.caption).foregroundStyle(.orange.opacity(0.7))
                            Text(set.formatted(timeFmt))
                                .font(.subheadline).foregroundStyle(AppColors.primary)
                        }
                    }
                }

                Divider().padding(.leading, 38)

                condRow(icon: moon.sfSymbol, iconColor: AppColors.primary) {
                    Text(moon.name)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func condRow<C: View>(icon: String, iconColor: Color,
                                  @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 24, alignment: .center)
            HStack(spacing: 6) { content() }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // Tag chips
    private var entryTagsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TAGS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.primary.opacity(0.45))
                .tracking(0.4)
            FlowLayout(spacing: 4) {
                ForEach(entry?.tags ?? [], id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(AppColors.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // Non-interactive map snapshot
    @ViewBuilder
    private func locationMapView(lat: Double, lon: Double) -> some View {
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coord,
            span:   MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        ))) {
            Marker("", coordinate: coord)
                .tint(AppColors.primary)
        }
        .disabled(true)
    }

    // ── Edit-mode grouped form ────────────────────────────────────────────────
    private var editForm: some View {
        Form {
            Section("Details") {
                if entry?.entryType != .fieldNote {
                    speciesField
                }
                DatePicker("Date & Time", selection: $editDate,
                           displayedComponents: [.date, .hourAndMinute])
                if entry?.entryType != .fieldNote {
                    Picker("Camera", selection: $editCamera) {
                        ForEach(CameraCatalog.all, id: \.self) { Text($0).tag($0) }
                    }
                }
                if !tripStore.trips.isEmpty {
                    Picker("Trip", selection: $editTripID) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(tripStore.trips.sorted { $0.date > $1.date }) { trip in
                            Text(trip.name).tag(Optional(trip.id))
                        }
                    }
                }
                if !nestboxStore.nestboxes.isEmpty {
                    Picker("Nestbox", selection: $editNestboxID) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(nestboxStore.nestboxes.sorted { $0.name < $1.name }) { box in
                            Text(box.name).tag(Optional(box.id))
                        }
                    }
                }
            }
            Section("Location") {
                Toggle("Unknown location", isOn: $editLocationUnknown)
                if !editLocationUnknown {
                    // Saved spot picker
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
                    // Map picker button
                    Button {
                        showMapPicker = true
                    } label: {
                        Label("Pick on map…", systemImage: "map")
                            .foregroundStyle(AppColors.secondary)
                    }
                    .buttonStyle(.plain)
                    // Current coordinates (read-only + clear)
                    if let lat = editLatitude, let lon = editLongitude {
                        LabeledContent("Coordinates") {
                            HStack(spacing: 8) {
                                Text(String(format: "%.5f, %.5f", lat, lon))
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .monospacedDigit()
                                Button {
                                    editLatitude  = nil
                                    editLongitude = nil
                                    selectedSavedLocation = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            Section("Notes") {
                LabeledContent("Tags") {
                    TextField("comma separated, e.g. jerv, natt", text: $editTagsText)
                        .multilineTextAlignment(.trailing)
                }
                TextEditor(text: $editNotes)
                    .frame(minHeight: 80, maxHeight: 140)
                    .overlay(alignment: .topLeading) {
                        if editNotes.isEmpty {
                            Text("Notes…")
                                .foregroundStyle(Color(nsColor: .placeholderTextColor))
                                .padding(.leading, 4).padding(.top, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
    }

    // ── Species field (catalog Picker + free-text fallback) ──────────────────

    private var isCustomSpecies: Bool {
        !editSpecies.isEmpty && !SpeciesCatalog.all.map(\.nameNO).contains(editSpecies)
    }

    private var catalogPickerBinding: Binding<String> {
        Binding(
            get: { isCustomSpecies ? "__custom__" : editSpecies },
            set: { newVal in
                if newVal == "__custom__" { if !isCustomSpecies { editSpecies = "" } }
                else { editSpecies = newVal }
            }
        )
    }

    @ViewBuilder
    private var speciesField: some View {
        Picker("Species", selection: catalogPickerBinding) {
            Text("— select species —").tag("")
            ForEach(SpeciesGroup.allCases, id: \.self) { group in
                let groupSpecies = SpeciesCatalog.all
                    .filter { $0.group == group }
                    .sorted { $0.nameNO < $1.nameNO }
                if !groupSpecies.isEmpty {
                    Section(group.rawValue.capitalized) {
                        ForEach(groupSpecies) { s in Text(s.nameNO).tag(s.nameNO) }
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

    // ── Helpers ───────────────────────────────────────────────────────────────
    private func loadEntry() {
        guard let e = entry else { return }
        editTripID            = e.tripID
        editNestboxID         = e.nestboxID
        editDate              = e.date
        editSpecies           = e.species ?? ""
        editCamera            = (e.camera?.isEmpty == false)
            ? (e.camera ?? CameraCatalog.unknown)
            : CameraCatalog.unknown
        editNotes             = e.notes
        editTagsText          = e.tags.joined(separator: ", ")
        editLocationUnknown   = e.locationUnknown
        editLatitude          = e.latitude
        editLongitude         = e.longitude
        selectedSavedLocation = ""
    }

    private func beginEditing() { loadEntry(); isEditing = true }

    private func saveEdits() {
        guard let i = entryIndex else { return }
        store.entries[i].tripID          = editTripID
        store.entries[i].nestboxID       = editNestboxID
        let st = editSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
        store.entries[i].species         = st.isEmpty ? nil : st
        store.entries[i].date            = editDate
        let ct = editCamera.trimmingCharacters(in: .whitespacesAndNewlines)
        store.entries[i].camera          = (ct.isEmpty || ct == CameraCatalog.unknown) ? nil : ct
        store.entries[i].notes           = editNotes
        store.entries[i].tags            = parseTags(editTagsText)
        store.entries[i].locationUnknown = editLocationUnknown
        store.entries[i].latitude        = editLocationUnknown ? nil : editLatitude
        store.entries[i].longitude       = editLocationUnknown ? nil : editLongitude
    }

    private func parseTags(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func startSaveLocationPrompt(lat: Double, lon: Double) {
        pendingSaveLat        = lat
        pendingSaveLon        = lon
        saveLocationName      = entry?.species
            ?? "Location \(Date().formatted(date: .abbreviated, time: .omitted))"
        showSaveLocationAlert = true
    }

    private func commitSaveLocation() {
        let name = saveLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let newCoord = CLLocation(latitude: pendingSaveLat, longitude: pendingSaveLon)
        if let existing = savedLocationStore.locations.first(where: {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                .distance(from: newCoord) < 25
        }) {
            duplicateMessage   = "\"\(existing.name)\" is already saved very close to this spot."
            showDuplicateAlert = true
            return
        }
        savedLocationStore.add(
            SavedLocation(name: name, latitude: pendingSaveLat, longitude: pendingSaveLon)
        )
    }
}

// ── Full-resolution photo viewer ──────────────────────────────────────────────

struct MacPhotoZoomView: View {
    let entry: TrailEntry?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let e = entry, let img = MacImageStore.loadImage(for: e) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(.secondary)
                    Text("Photo unavailable")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Close button
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(16)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            // Entry title bottom-left
            if let e = entry {
                VStack {
                    Spacer()
                    HStack {
                        Text(e.displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(16)
                        Spacer()
                    }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

// ── Simple flow layout for tags ────────────────────────────────────────────────

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +)
            + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in computeRows(proposal: proposal, subviews: subviews) {
            var x = bounds.minX
            for sv in row.views {
                let size = sv.sizeThatFits(.unspecified)
                sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var views: [LayoutSubview]; var height: CGFloat }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row(views: [], height: 0)
        var x: CGFloat = 0
        let maxW = proposal.width ?? .infinity
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if !current.views.isEmpty && x + size.width > maxW {
                rows.append(current)
                current = Row(views: [], height: 0)
                x = 0
            }
            current.views.append(sv)
            current.height = max(current.height, size.height)
            x += size.width + spacing
        }
        if !current.views.isEmpty { rows.append(current) }
        return rows
    }
}
#endif
