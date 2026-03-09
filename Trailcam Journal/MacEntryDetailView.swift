
//
//  MacEntryDetailView.swift
//  Trailcam Journal
//
//  Two-column sheet for viewing and editing finalised entries on macOS.
//  Left panel: photo hero + live metadata preview.
//  Right panel: form (read-only in view mode, editable in edit mode).
//

#if os(macOS)
import SwiftUI
import MapKit
import AppKit
import CoreLocation

struct MacEntryDetailView: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore
    @Environment(\.dismiss) private var dismiss

    let entryID: UUID

    // Edit state
    @State private var isEditing            = false
    @State private var editDate:            Date   = Date()
    @State private var editSpecies:         String = ""
    @State private var editCamera:          String = CameraCatalog.unknown
    @State private var editNotes:           String = ""
    @State private var editTagsText:        String = ""
    @State private var editLocationUnknown: Bool    = false
    @State private var editLatitude:        Double? = nil
    @State private var editLongitude:       Double? = nil
    @State private var selectedSavedLocation:String = ""

    // Photo zoom + map picker
    @State private var showPhotoZoom   = false
    @State private var showMapPicker   = false

    // Alerts
    @State private var confirmDelete            = false
    @State private var showSaveLocationAlert    = false
    @State private var saveLocationName         = ""
    @State private var pendingSaveLat: Double   = 0
    @State private var pendingSaveLon: Double   = 0
    @State private var showDuplicateAlert       = false
    @State private var duplicateMessage         = ""

    // ── Derived ──────────────────────────────────────────────────────────────
    private var entryIndex: Int?   { store.entries.firstIndex(where: { $0.id == entryID }) }
    private var entry: TrailEntry? { entryIndex.map { store.entries[$0] } }

    /// Displayed species: live edit value when editing, stored value otherwise
    private var displaySpecies: String {
        isEditing
            ? (editSpecies.isEmpty ? "Unknown species" : editSpecies)
            : (entry?.species ?? "Unknown species")
    }
    private var displayCamera: String? {
        isEditing
            ? (editCamera == CameraCatalog.unknown ? nil : editCamera)
            : entry?.camera
    }
    private var displayLat: Double? { isEditing ? editLatitude  : entry?.latitude  }
    private var displayLon: Double? { isEditing ? editLongitude : entry?.longitude }
    private var displayTags: [String] {
        isEditing
            ? parseTags(editTagsText)
            : (entry?.tags ?? [])
    }

    // ── Body ─────────────────────────────────────────────────────────────────
    var body: some View {
        HStack(spacing: 0) {
            leftPanel.frame(width: 280)
                .background(AppColors.primary.opacity(0.035))
            Divider()
            rightPanel
        }
        .frame(minWidth: 760, minHeight: 560)
        .onAppear { loadEntry() }
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
        .sheet(isPresented: $showPhotoZoom) {
            MacPhotoZoomView(entry: entry)
        }
        .sheet(isPresented: $showMapPicker) {
            MacDraftLocationPickerSheet(
                latitude:  $editLatitude,
                longitude: $editLongitude,
                initialLat: editLatitude ?? entry?.latitude,
                initialLon: editLongitude ?? entry?.longitude
            )
        }
    }

    // ── Left panel ───────────────────────────────────────────────────────────
    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Photo hero — padded + rounded (tap to zoom)
            MacThumbnail(entry: entry, cornerRadius: 12)
                .frame(maxWidth: .infinity).frame(height: 180)
                .padding(16)
                .overlay(alignment: .bottomTrailing) {
                    Button { showPhotoZoom = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .padding(24)
                }
                .onTapGesture { showPhotoZoom = true }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Species (large, live)
                    VStack(alignment: .leading, spacing: 3) {
                        label("Species")
                        Text(displaySpecies)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppColors.primary)
                            .lineLimit(2)
                    }

                    // Date
                    VStack(alignment: .leading, spacing: 3) {
                        label("Date")
                        Text((isEditing ? editDate : entry?.date ?? Date())
                                .formatted(date: .long, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    // Camera
                    if let cam = displayCamera, !cam.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            label("Camera")
                            Label(cam, systemImage: "camera")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }

                    // Tags
                    if !displayTags.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            label("Tags")
                            FlowLayout(spacing: 5) {
                                ForEach(displayTags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppColors.secondary)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(AppColors.secondary.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Mini-map
                    if let lat = displayLat, let lon = displayLon {
                        VStack(alignment: .leading, spacing: 5) {
                            label("Location")
                            miniMap(lat: lat, lon: lon)
                            Text(String(format: "%.5f, %.5f", lat, lon))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            if !isEditing {
                                Button {
                                    startSaveLocationPrompt(lat: lat, lon: lon)
                                } label: {
                                    Label("Save as pinned location", systemImage: "bookmark")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppColors.secondary)
                            }
                        }
                    } else if (isEditing ? editLocationUnknown : entry?.locationUnknown) == true {
                        VStack(alignment: .leading, spacing: 3) {
                            label("Location")
                            Text("Unknown").font(.subheadline).foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
                .padding(16)
            }

            Spacer(minLength: 0)

            // Delete at bottom
            Divider()
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete Entry", systemImage: "trash")
                    .font(.subheadline).foregroundStyle(.red.opacity(0.85))
            }
            .buttonStyle(.plain).padding(14)
        }
    }

    @ViewBuilder
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColors.primary.opacity(0.5))
            .textCase(.uppercase).tracking(0.4)
    }

    @ViewBuilder
    private func miniMap(lat: Double, lon: Double) -> some View {
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        ))) {
            Marker("", coordinate: coord)
                .tint(AppColors.primary)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .disabled(true)
    }

    // ── Right panel ──────────────────────────────────────────────────────────
    private var rightPanel: some View {
        VStack(spacing: 0) {

            // Title bar
            HStack {
                Text(entry?.species ?? "Entry")
                    .font(.headline).foregroundStyle(AppColors.primary)
                    .lineLimit(1)
                Spacer()
                if isEditing {
                    Button("Cancel") { isEditing = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Save") { saveEdits(); isEditing = false }
                        .keyboardShortcut("s", modifiers: .command)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Edit") { beginEditing() }
                    Button("Close") { dismiss() }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            if isEditing {
                editForm
            } else {
                viewForm
            }
        }
    }

    // MARK: View-mode form

    private var viewForm: some View {
        Form {
            Section("Details") {
                LabeledContent("Species", value: entry?.species ?? "Unknown species")
                LabeledContent("Date", value: (entry?.date ?? Date()).formatted(date: .long, time: .shortened))
                LabeledContent("Camera", value: entry?.camera ?? "Unknown camera")
            }
            Section("Location") {
                if entry?.locationUnknown == true {
                    LabeledContent("Location", value: "Unknown")
                } else if let lat = entry?.latitude, let lon = entry?.longitude {
                    LabeledContent("Coordinates", value: String(format: "%.5f, %.5f", lat, lon))
                } else {
                    LabeledContent("Location", value: "No GPS data")
                }
            }
            Section("Notes") {
                LabeledContent("Tags", value: entry?.tags.isEmpty == false
                    ? (entry?.tags.map { "#\($0)" }.joined(separator: "  ") ?? "")
                    : "None")
                if let notes = entry?.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No notes").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
    }

    // MARK: Edit-mode form

    private var editForm: some View {
        Form {
            Section("Details") {
                Picker("Species", selection: $editSpecies) {
                    Text("— select species —").tag("").foregroundStyle(.secondary)
                    ForEach(SpeciesCatalog.all) { s in Text(s.nameNO).tag(s.nameNO) }
                }
                DatePicker("Date & Time", selection: $editDate,
                           displayedComponents: [.date, .hourAndMinute])
                Picker("Camera", selection: $editCamera) {
                    ForEach(CameraCatalog.all, id: \.self) { Text($0).tag($0) }
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
                                  let loc = savedLocationStore.locations.first(where: { $0.name == name })
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
                    // Current coordinates (read-only with clear)
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

    // ── Helpers ───────────────────────────────────────────────────────────────
    private func loadEntry() {
        guard let e = entry else { return }
        editDate            = e.date
        editSpecies         = e.species ?? ""
        editCamera          = (e.camera?.isEmpty == false) ? (e.camera ?? CameraCatalog.unknown) : CameraCatalog.unknown
        editNotes           = e.notes
        editTagsText        = e.tags.joined(separator: ", ")
        editLocationUnknown   = e.locationUnknown
        editLatitude          = e.latitude
        editLongitude         = e.longitude
        selectedSavedLocation = ""
    }

    private func beginEditing() { loadEntry(); isEditing = true }

    private func saveEdits() {
        guard let i = entryIndex else { return }
        let st = editSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
        store.entries[i].species = st.isEmpty ? nil : st
        store.entries[i].date    = editDate
        let ct = editCamera.trimmingCharacters(in: .whitespacesAndNewlines)
        store.entries[i].camera  = (ct.isEmpty || ct == CameraCatalog.unknown) ? nil : ct
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
        pendingSaveLat   = lat
        pendingSaveLon   = lon
        saveLocationName = entry?.species ?? "Location \(Date().formatted(date: .abbreviated, time: .omitted))"
        showSaveLocationAlert = true
    }

    private func commitSaveLocation() {
        let name = saveLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let newCoord = CLLocation(latitude: pendingSaveLat, longitude: pendingSaveLon)
        if let existing = savedLocationStore.locations.first(where: {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: newCoord) < 25
        }) {
            duplicateMessage = "\"\(existing.name)\" is already saved very close to this spot."
            showDuplicateAlert = true
            return
        }
        savedLocationStore.add(SavedLocation(name: name, latitude: pendingSaveLat, longitude: pendingSaveLon))
    }
}

// ── Full-resolution photo viewer ─────────────────────────────────────────────

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

            // Species label bottom-left
            if let species = entry?.species {
                VStack {
                    Spacer()
                    HStack {
                        Text(species)
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

// ── Simple flow layout for tags ───────────────────────────────────────────────

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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
