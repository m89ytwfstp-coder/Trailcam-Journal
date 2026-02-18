//
//  EntryDetailView.swift
//  Trailcam Journal
//
//  Updated Jan 2026:
//  - Edit finalized entries (and drafts too if opened)
//  - Uses entryID so edits persist in EntryStore
//  - NEW: Save a pinned location from an entry's GPS
//

import SwiftUI
import MapKit
import CoreLocation

struct EntryDetailView: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore
    @Environment(\.dismiss) private var dismiss

    let entryID: UUID

    // UI state
    @State private var isEditing: Bool = false
    @State private var confirmDelete: Bool = false

    // Save-location state
    @State private var showSaveLocationAlert: Bool = false
    @State private var saveLocationName: String = ""
    @State private var pendingSaveLat: Double = 0
    @State private var pendingSaveLon: Double = 0

    @State private var showDuplicateAlert: Bool = false
    @State private var duplicateMessage: String = ""

    // Draft edit fields (local copy while editing)
    @State private var editDate: Date = Date()
    @State private var editSpecies: String = ""
    @State private var editCamera: String = CameraCatalog.unknown
    @State private var editNotes: String = ""
    @State private var editTagsText: String = ""

    @State private var editLocationUnknown: Bool = false
    @State private var editLatitude: Double? = nil
    @State private var editLongitude: Double? = nil

    private var entryIndex: Int? {
        store.entries.firstIndex(where: { $0.id == entryID })
    }

    private var entry: TrailEntry? {
        guard let i = entryIndex else { return nil }
        return store.entries[i]
    }

    var body: some View {
        Group {
            if let entry, let i = entryIndex {
                Form {

                    Section("Photo") {
                        EntryPhotoView(entry: entry, height: 240, cornerRadius: 12, maxPixel: 1400)
                    }

                    Section("Species") {
                        if isEditing {
                            Picker("Species", selection: $editSpecies) {
                                Text("Unknown species").tag("")
                                ForEach(SpeciesCatalog.all) { s in
                                    Text(s.nameNO).tag(s.nameNO)
                                }
                            }
                        } else {
                            Text(entry.species ?? "Unknown species")
                        }
                    }

                    Section("Date & time") {
                        if isEditing {
                            DatePicker("Date", selection: $editDate, displayedComponents: [.date, .hourAndMinute])
                        } else {
                            Text(entry.date.formatted(date: .long, time: .shortened))
                        }
                    }

                    Section("Camera") {
                        if isEditing {
                            Picker("Camera", selection: $editCamera) {
                                ForEach(CameraCatalog.all, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            Text(entry.camera ?? "Unknown camera")
                        }
                    }

                    Section("Tags") {
                        if isEditing {
                            TextField("Tags (comma separated)", text: $editTagsText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)

                            Text("Example: jerv, natt, snø")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            if entry.tags.isEmpty {
                                Text("No tags")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(entry.tags.joined(separator: ", "))
                            }
                        }
                    }

                    Section("Notes") {
                        if isEditing {
                            TextEditor(text: $editNotes)
                                .frame(minHeight: 120)
                        } else {
                            if entry.notes.isEmpty {
                                Text("No notes")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(entry.notes)
                            }
                        }
                    }

                    locationSection(entry: entry)

                    if !isEditing {
                        Section {
                            Button(role: .destructive) {
                                confirmDelete = true
                            } label: {
                                Label("Delete entry", systemImage: "trash")
                            }
                        }
                    }
                }
                .navigationTitle(entry.species?.isEmpty == false ? (entry.species ?? "Entry") : "Entry")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if isEditing {
                            Button("Save") { saveEdits(storeIndex: i) }
                        } else {
                            Button("Edit") { beginEditing(from: entry) }
                        }
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        if isEditing {
                            Button("Cancel") { isEditing = false }
                        }
                    }
                }

                // Delete confirmation
                .alert("Delete entry?", isPresented: $confirmDelete) {
                    Button("Delete", role: .destructive) {
                        store.deleteEntry(id: entry.id)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete this entry.")
                }

                // Save location prompt
                .alert("Save location", isPresented: $showSaveLocationAlert) {
                    TextField("Name", text: $saveLocationName)
                    Button("Save") { commitSaveLocation() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Save this GPS position as a pinned location for quick reuse.")
                }

                // Duplicate warning
                .alert("Already saved", isPresented: $showDuplicateAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(duplicateMessage)
                }

            } else {
                VStack(spacing: 10) {
                    Text("Entry not found")
                        .font(.headline)
                    Text("It may have been deleted.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }

    // MARK: - Location section

    @ViewBuilder
    private func locationSection(entry: TrailEntry) -> some View {
        Section("Location") {
            if isEditing {
                Toggle("Mark location as unknown", isOn: $editLocationUnknown)

                NavigationLink {
                    SavedLocationPickerView { loc in
                        editLocationUnknown = false
                        editLatitude = loc.latitude
                        editLongitude = loc.longitude
                    }
                } label: {
                    Label("Choose saved location", systemImage: "bookmark")
                }

                if !editLocationUnknown {
                    if let lat = editLatitude, let lon = editLongitude {
                        Text(String(format: "%.5f, %.5f", lat, lon))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Tap on the map to choose a location")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    MapLocationPickerInline(latitude: $editLatitude, longitude: $editLongitude)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    // ✅ Save pinned location from the edited coordinate
                    if let lat = editLatitude, let lon = editLongitude {
                        Button {
                            startSaveLocationPrompt(lat: lat, lon: lon, entry: entry)
                        } label: {
                            Label("Save as pinned location", systemImage: "bookmark.fill")
                        }
                    }
                }
            } else {
                if entry.locationUnknown {
                    Text("Unknown location")
                } else if let lat = entry.latitude, let lon = entry.longitude {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                    Map(
                        initialPosition: .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    ) {
                        Marker("Trailcam location", coordinate: coordinate)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(String(format: "%.5f, %.5f", lat, lon))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    // ✅ Save pinned location from the entry GPS
                    Button {
                        startSaveLocationPrompt(lat: lat, lon: lon, entry: entry)
                    } label: {
                        Label("Save as pinned location", systemImage: "bookmark.fill")
                    }

                    Text("Tip: Use this after importing photos with GPS. Then you can reuse the location later from the picker.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                } else {
                    Text("No location")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Save pinned location

    private func startSaveLocationPrompt(lat: Double, lon: Double, entry: TrailEntry) {
        pendingSaveLat = lat
        pendingSaveLon = lon

        // Friendly default name suggestions
        if let species = entry.species, !species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveLocationName = species
        } else {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none
            saveLocationName = "Location \(df.string(from: entry.date))"
        }

        showSaveLocationAlert = true
    }

    private func commitSaveLocation() {
        let name = saveLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        // Prevent near-duplicates (within ~25m)
        let newCoord = CLLocation(latitude: pendingSaveLat, longitude: pendingSaveLon)
        if let existing = savedLocationStore.locations.first(where: { loc in
            let c = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
            return c.distance(from: newCoord) < 25
        }) {
            duplicateMessage = "You already have “\(existing.name)” saved very close to this spot."
            showDuplicateAlert = true
            return
        }

        savedLocationStore.add(
            SavedLocation(
                name: name,
                latitude: pendingSaveLat,
                longitude: pendingSaveLon
            )
        )
    }

    // MARK: - Editing lifecycle

    private func beginEditing(from entry: TrailEntry) {
        editDate = entry.date
        editSpecies = entry.species ?? ""
        editCamera = (entry.camera?.isEmpty == false) ? (entry.camera ?? "") : CameraCatalog.unknown
        editNotes = entry.notes
        editTagsText = entry.tags.joined(separator: ", ")

        editLocationUnknown = entry.locationUnknown
        editLatitude = entry.latitude
        editLongitude = entry.longitude

        isEditing = true
    }

    private func saveEdits(storeIndex i: Int) {
        // Species
        let speciesTrim = editSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
        store.entries[i].species = speciesTrim.isEmpty ? nil : speciesTrim

        // Date
        store.entries[i].date = editDate

        // Camera
        let camTrim = editCamera.trimmingCharacters(in: .whitespacesAndNewlines)
        if camTrim.isEmpty || camTrim == CameraCatalog.unknown {
            store.entries[i].camera = nil
        } else {
            store.entries[i].camera = camTrim
        }

        // Notes
        store.entries[i].notes = editNotes

        // Tags
        store.entries[i].tags = parseTags(editTagsText)

        // Location
        store.entries[i].locationUnknown = editLocationUnknown
        if editLocationUnknown {
            store.entries[i].latitude = nil
            store.entries[i].longitude = nil
        } else {
            store.entries[i].latitude = editLatitude
            store.entries[i].longitude = editLongitude
        }

        isEditing = false
    }

    private func parseTags(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
