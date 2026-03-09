
//
//  MacDraftEditView.swift
//  Trailcam Journal
//
//  Two-column sheet: photo + metadata on the left, Form on the right.
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
    @Environment(\.dismiss) private var dismiss

    let entryID: UUID

    // Edit state
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

    // Sheets
    @State private var showMapPicker:  Bool = false
    @State private var confirmDelete:  Bool = false

    // ── Derived ──────────────────────────────────────────────────────────────
    private var entryIndex: Int?    { store.entries.firstIndex(where: { $0.id == entryID }) }
    private var entry: TrailEntry?  { entryIndex.map { store.entries[$0] } }

    /// GPS extracted from original photo EXIF
    private var photoGPS: (lat: Double, lon: Double)? {
        guard let lat = entry?.latitude, let lon = entry?.longitude,
              lat != 0 || lon != 0 else { return nil }
        return (lat, lon)
    }

    private var hasCoordinates: Bool { editLatitude != nil && editLongitude != nil }

    private var canFinalizeNow: Bool {
        !editSpecies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (editLocationUnknown || hasCoordinates)
    }

    private var liveStatus: MacDraftStatus {
        guard !editSpecies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .missingSpecies }
        guard editLocationUnknown || hasCoordinates
        else { return .missingLocation }
        return .ready
    }

    // ── Body ─────────────────────────────────────────────────────────────────
    var body: some View {
        HStack(spacing: 0) {
            leftPanel.frame(width: 270)
                .background(AppColors.primary.opacity(0.035))
            Divider()
            rightPanel
        }
        .frame(minWidth: 760, minHeight: 560)
        .onAppear { loadEntry() }
        .alert("Delete draft?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let e = entry { store.deleteEntry(id: e.id) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this draft and its photo.")
        }
        .sheet(isPresented: $showMapPicker) {
            MacDraftLocationPickerSheet(
                latitude:  $editLatitude,
                longitude: $editLongitude,
                initialLat: editLatitude ?? photoGPS?.lat,
                initialLon: editLongitude ?? photoGPS?.lon
            )
        }
    }

    // ── Left panel ───────────────────────────────────────────────────────────
    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Photo — padded + rounded, like import queue rows
            MacThumbnail(entry: entry, cornerRadius: 12)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .padding(16)

            // Metadata
            VStack(alignment: .leading, spacing: 14) {
                metaField("File",
                    entry?.originalFilename ?? "—",
                    font: .subheadline.weight(.medium))

                metaField("Captured",
                    entry?.date.formatted(date: .abbreviated, time: .shortened) ?? "—")

                if let gps = photoGPS {
                    metaField("GPS from photo",
                              String(format: "%.5f, %.5f", gps.lat, gps.lon),
                              font: .caption)
                }

                Divider()

                // Live status pill
                HStack(spacing: 6) {
                    Circle().fill(liveStatus.color).frame(width: 8, height: 8)
                    Text(liveStatus.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(liveStatus.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            Spacer()

            // Delete at bottom of panel
            Divider()
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete Draft", systemImage: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red.opacity(0.85))
            }
            .buttonStyle(.plain)
            .padding(14)
        }
    }

    @ViewBuilder
    private func metaField(_ label: String, _ value: String, font: Font = .subheadline) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.primary.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.4)
            Text(value)
                .font(font)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // ── Right panel ──────────────────────────────────────────────────────────
    private var rightPanel: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                Text("Edit Draft")
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            Form {
                detailsSection
                locationSection
                notesSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)

            Divider()

            // Action bar
            HStack(spacing: 10) {
                Spacer()
                Button("Save Draft") { saveEdits(finalize: false); dismiss() }
                    .keyboardShortcut("s", modifiers: .command)
                Button("Finalise →") { saveEdits(finalize: true); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canFinalizeNow)
                    .help(canFinalizeNow
                          ? "Save and move to Entries"
                          : "Set a species and a location first")
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
    }

    // MARK: Form sections

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            Picker("Species", selection: $editSpecies) {
                Text("— select species —").tag("").foregroundStyle(.secondary)
                ForEach(SpeciesCatalog.all) { s in
                    Text(s.nameNO).tag(s.nameNO)
                }
            }
            DatePicker("Date & Time", selection: $editDate,
                       displayedComponents: [.date, .hourAndMinute])
            Picker("Camera", selection: $editCamera) {
                ForEach(CameraCatalog.all, id: \.self) { Text($0).tag($0) }
            }
            // Tags live in Details so they stay compact
            LabeledContent("Tags") {
                TextField("jerv, natt, snø…", text: $editTagsText)
                    .multilineTextAlignment(.trailing)
            }
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
                        editLatitude  = gps.lat
                        editLongitude = gps.lon
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
                              let loc = savedLocationStore.locations.first(where: { $0.name == name })
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
        } header: {
            Text("Location")
        }
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
        editDate            = e.date
        editSpecies         = e.species ?? ""
        editCamera          = (e.camera?.isEmpty == false) ? (e.camera ?? CameraCatalog.unknown) : CameraCatalog.unknown
        editNotes           = e.notes
        editTagsText        = e.tags.joined(separator: ", ")
        editLocationUnknown = e.locationUnknown
        editLatitude        = e.latitude
        editLongitude       = e.longitude
    }

    private func saveEdits(finalize: Bool) {
        guard let i = entryIndex else { return }
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
        if finalize { store.entries[i].isDraft = false }
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
        func mapView(_ mv: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // Pin style
        func mapView(_ mv: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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
