
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
    @State private var editLocationUnknown: Bool   = false
    @State private var editLatitude:        String = ""
    @State private var editLongitude:       String = ""

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

    private var parsedLat: Double? { Double(editLatitude)  }
    private var parsedLon: Double? { Double(editLongitude) }

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
    private var displayLat: Double? { isEditing ? parsedLat  : entry?.latitude  }
    private var displayLon: Double? { isEditing ? parsedLon  : entry?.longitude }
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
    }

    // ── Left panel ───────────────────────────────────────────────────────────
    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Photo hero
            MacThumbnail(entry: entry, cornerRadius: 0)
                .frame(maxWidth: .infinity).frame(height: 200).clipped()

            Divider()

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
                    LabeledContent("Latitude") {
                        TextField("e.g. 60.39299", text: $editLatitude)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Longitude") {
                        TextField("e.g. 5.32415", text: $editLongitude)
                            .multilineTextAlignment(.trailing)
                    }
                    if !savedLocationStore.locations.isEmpty {
                        Picker("Saved location", selection: Binding(
                            get: { "" },
                            set: { name in
                                if let loc = savedLocationStore.locations.first(where: { $0.name == name }) {
                                    editLatitude  = String(loc.latitude)
                                    editLongitude = String(loc.longitude)
                                }
                            }
                        )) {
                            Text("Pick saved location…").tag("")
                            ForEach(savedLocationStore.locations) { loc in Text(loc.name).tag(loc.name) }
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
        editLocationUnknown = e.locationUnknown
        if let lat = e.latitude  { editLatitude  = String(lat) }
        if let lon = e.longitude { editLongitude = String(lon) }
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
        store.entries[i].latitude  = editLocationUnknown ? nil : parsedLat
        store.entries[i].longitude = editLocationUnknown ? nil : parsedLon
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
            duplicateMessage = ""\(existing.name)" is already saved very close to this spot."
            showDuplicateAlert = true
            return
        }
        savedLocationStore.add(SavedLocation(name: name, latitude: pendingSaveLat, longitude: pendingSaveLon))
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
