
//
//  MacDraftEditView.swift
//  Trailcam Journal
//
//  Two-column sheet: photo + metadata on the left, Form on the right.
//

#if os(macOS)
import SwiftUI
import AppKit

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
    @State private var editLatitude:        String = ""
    @State private var editLongitude:       String = ""
    @State private var confirmDelete:       Bool   = false

    // ── Derived ──────────────────────────────────────────────────────────────
    private var entryIndex: Int?    { store.entries.firstIndex(where: { $0.id == entryID }) }
    private var entry: TrailEntry?  { entryIndex.map { store.entries[$0] } }
    private var parsedLat: Double?  { Double(editLatitude)  }
    private var parsedLon: Double?  { Double(editLongitude) }

    private var canFinalizeNow: Bool {
        !editSpecies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (editLocationUnknown || (parsedLat != nil && parsedLon != nil))
    }

    private var liveStatus: MacDraftStatus {
        guard !editSpecies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .missingSpecies }
        guard editLocationUnknown || (parsedLat != nil && parsedLon != nil)
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
        .frame(minWidth: 720, minHeight: 540)
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
    }

    // ── Left panel ───────────────────────────────────────────────────────────
    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Hero photo
            MacThumbnail(entry: entry, cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()

            Divider()

            // Metadata
            VStack(alignment: .leading, spacing: 14) {
                metaField("File",
                    entry?.originalFilename ?? "—",
                    font: .subheadline.weight(.medium))

                metaField("Captured",
                    entry?.date.formatted(date: .abbreviated, time: .shortened) ?? "—")

                if let lat = entry?.latitude, let lon = entry?.longitude {
                    metaField("GPS from photo",
                              String(format: "%.5f, %.5f", lat, lon),
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
            .padding(16)

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
                Text(entry?.isDraft == true ? "Edit Draft" : "Edit Entry")
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            // Grouped form (macOS-native look)
            Form {
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
                                ForEach(savedLocationStore.locations) { loc in
                                    Text(loc.name).tag(loc.name)
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

    // ── Persistence ───────────────────────────────────────────────────────────
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

    private func saveEdits(finalize: Bool) {
        guard let i = entryIndex else { return }
        let speciesTrim = editSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
        store.entries[i].species = speciesTrim.isEmpty ? nil : speciesTrim
        store.entries[i].date    = editDate
        let camTrim = editCamera.trimmingCharacters(in: .whitespacesAndNewlines)
        store.entries[i].camera  = (camTrim.isEmpty || camTrim == CameraCatalog.unknown) ? nil : camTrim
        store.entries[i].notes           = editNotes
        store.entries[i].tags            = parseTags(editTagsText)
        store.entries[i].locationUnknown = editLocationUnknown
        store.entries[i].latitude  = editLocationUnknown ? nil : parsedLat
        store.entries[i].longitude = editLocationUnknown ? nil : parsedLon
        if finalize { store.entries[i].isDraft = false }
    }

    private func parseTags(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
#endif
