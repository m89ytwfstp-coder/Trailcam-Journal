
//
//  MacDraftEditView.swift
//  Trailcam Journal
//
//  Issue #8: macOS draft entries — editable and finalisable via a sheet.
//

#if os(macOS)
import SwiftUI
import AppKit

struct MacDraftEditView: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore
    @Environment(\.dismiss) private var dismiss

    let entryID: UUID

    // Edit fields
    @State private var editDate: Date = Date()
    @State private var editSpecies: String = ""
    @State private var editCamera: String = CameraCatalog.unknown
    @State private var editNotes: String = ""
    @State private var editTagsText: String = ""

    @State private var editLocationUnknown: Bool = false
    @State private var editLatitude: String = ""
    @State private var editLongitude: String = ""

    @State private var confirmDelete: Bool = false

    // ---------------------------------------------------------------
    private var entryIndex: Int? {
        store.entries.firstIndex(where: { $0.id == entryID })
    }

    private var entry: TrailEntry? {
        guard let i = entryIndex else { return nil }
        return store.entries[i]
    }

    private var parsedLat: Double? { Double(editLatitude) }
    private var parsedLon: Double? { Double(editLongitude) }

    private var canFinalizeNow: Bool {
        let hasSpecies = !editSpecies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLocation = editLocationUnknown || (parsedLat != nil && parsedLon != nil)
        return hasSpecies && hasLocation
    }

    // ---------------------------------------------------------------
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry?.originalFilename ?? "Edit Draft")
                        .font(.headline)
                    if let entry = entry, entry.isDraft {
                        Text("Draft")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // ── Scrollable form ──────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Photo preview
                    MacDraftPhoto(entry: entry)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Species
                    formRow("Species") {
                        Picker("Species", selection: $editSpecies) {
                            Text("Unknown species").tag("")
                            ForEach(SpeciesCatalog.all) { s in
                                Text(s.nameNO).tag(s.nameNO)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    // Date
                    formRow("Date & Time") {
                        DatePicker(
                            "",
                            selection: $editDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                    }

                    Divider()

                    // Camera
                    formRow("Camera") {
                        Picker("Camera", selection: $editCamera) {
                            ForEach(CameraCatalog.all, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    Divider()

                    // Location
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Location")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Toggle("Mark location as unknown", isOn: $editLocationUnknown)

                        if !editLocationUnknown {
                            HStack {
                                Text("Latitude")
                                    .frame(width: 80, alignment: .leading)
                                TextField("e.g. 60.39299", text: $editLatitude)
                                    .textFieldStyle(.roundedBorder)
                            }
                            HStack {
                                Text("Longitude")
                                    .frame(width: 80, alignment: .leading)
                                TextField("e.g. 5.32415", text: $editLongitude)
                                    .textFieldStyle(.roundedBorder)
                            }

                            if !savedLocationStore.locations.isEmpty {
                                Picker("Saved location", selection: Binding(
                                    get: { "" },
                                    set: { name in
                                        if let loc = savedLocationStore.locations.first(where: { $0.name == name }) {
                                            editLatitude = String(loc.latitude)
                                            editLongitude = String(loc.longitude)
                                        }
                                    }
                                )) {
                                    Text("Pick saved location…").tag("")
                                    ForEach(savedLocationStore.locations) { loc in
                                        Text(loc.name).tag(loc.name)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    Divider()

                    // Tags
                    formRow("Tags") {
                        TextField("Comma separated, e.g. jerv, natt, snø", text: $editTagsText)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $editNotes)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3))
                            )
                    }
                }
                .padding()
            }

            Divider()

            // ── Action bar ───────────────────────────────────────────
            HStack {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .foregroundStyle(.red)

                Spacer()

                Button("Save draft") {
                    saveEdits(finalize: false)
                    dismiss()
                }

                Button("Finalize →") {
                    saveEdits(finalize: true)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canFinalizeNow)
                .help(canFinalizeNow ? "Mark as finalized entry" : "Set a species and location first")
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 680)
        .onAppear { loadEntry() }
        .alert("Delete entry?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let entry = entry { store.deleteEntry(id: entry.id) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this draft.")
        }
    }

    // ---------------------------------------------------------------
    // MARK: - Helpers

    @ViewBuilder
    private func formRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func loadEntry() {
        guard let entry = entry else { return }
        editDate               = entry.date
        editSpecies            = entry.species ?? ""
        editCamera             = (entry.camera?.isEmpty == false) ? (entry.camera ?? CameraCatalog.unknown) : CameraCatalog.unknown
        editNotes              = entry.notes
        editTagsText           = entry.tags.joined(separator: ", ")
        editLocationUnknown    = entry.locationUnknown
        if let lat = entry.latitude  { editLatitude  = String(lat) }
        if let lon = entry.longitude { editLongitude = String(lon) }
    }

    private func saveEdits(finalize: Bool) {
        guard let i = entryIndex else { return }

        let speciesTrim = editSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
        store.entries[i].species = speciesTrim.isEmpty ? nil : speciesTrim

        store.entries[i].date = editDate

        let camTrim = editCamera.trimmingCharacters(in: .whitespacesAndNewlines)
        store.entries[i].camera = (camTrim.isEmpty || camTrim == CameraCatalog.unknown) ? nil : camTrim

        store.entries[i].notes = editNotes
        store.entries[i].tags  = parseTags(editTagsText)

        store.entries[i].locationUnknown = editLocationUnknown
        if editLocationUnknown {
            store.entries[i].latitude  = nil
            store.entries[i].longitude = nil
        } else {
            store.entries[i].latitude  = parsedLat
            store.entries[i].longitude = parsedLon
        }

        if finalize {
            store.entries[i].isDraft = false
        }
    }

    private func parseTags(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// ── Photo helper (macOS only) ────────────────────────────────────────────────

private struct MacDraftPhoto: View {
    let entry: TrailEntry?

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.12))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private func loadImage() -> NSImage? {
        guard let name = entry?.photoFilename,
              let dir  = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        return NSImage(contentsOf: dir.appendingPathComponent(name))
    }
}
#endif
