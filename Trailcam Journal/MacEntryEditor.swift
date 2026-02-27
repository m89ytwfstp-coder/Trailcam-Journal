import SwiftUI
import AppKit
import MapKit

#if os(macOS)
struct MacEntryEditorPane: View {
    let initialEntryID: UUID

    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentEntryID: UUID
    @State private var date = Date()
    @State private var species = ""
    @State private var camera = CameraCatalog.unknown
    @State private var notes = ""
    @State private var tagsText = ""
    @State private var locationUnknown = false
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var selectedSavedLocationID: UUID?
    @State private var isDraft = true
    @State private var showDeleteConfirm = false
    @State private var showImagePreview = false

    init(entryID: UUID) {
        self.initialEntryID = entryID
        _currentEntryID = State(initialValue: entryID)
    }

    private var entryIndex: Int? {
        store.entries.firstIndex(where: { $0.id == currentEntryID })
    }

    private var currentEntry: TrailEntry? {
        guard let idx = entryIndex else { return nil }
        return store.entries[idx]
    }

    private var canGoPrevious: Bool {
        guard let idx = entryIndex else { return false }
        return idx > 0
    }

    private var canGoNext: Bool {
        guard let idx = entryIndex else { return false }
        return idx < store.entries.count - 1
    }

    private var canFinalize: Bool {
        let hasSpecies = !species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLocation = locationUnknown || (parseCoordinate(latitudeText) != nil && parseCoordinate(longitudeText) != nil)
        return hasSpecies && hasLocation
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    if let image = currentImage() {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button("Open Fullscreen Preview") {
                            showImagePreview = true
                        }
                    } else {
                        Text("No local image available for preview.")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Section("Basics") {
                    DatePicker("Date", selection: $date)

                    Picker("Species", selection: $species) {
                        Text("— Select —").tag("")
                        ForEach(SpeciesCatalog.all) { item in
                            Text(item.nameNO).tag(item.nameNO)
                        }
                    }

                    Picker("Camera", selection: $camera) {
                        ForEach(CameraCatalog.all, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                Section("Tags") {
                    TextField("Comma separated tags", text: $tagsText)
                }

                Section("Location") {
                    Toggle("Location unknown", isOn: $locationUnknown)

                    Picker("Saved location", selection: $selectedSavedLocationID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(savedLocationStore.locations) { location in
                            Text(location.name).tag(Optional(location.id))
                        }
                    }
                    .onChange(of: selectedSavedLocationID) { _, id in
                        guard let id,
                              let location = savedLocationStore.locations.first(where: { $0.id == id }) else { return }
                        latitudeText = String(location.latitude)
                        longitudeText = String(location.longitude)
                        locationUnknown = false
                    }

                    TextField("Latitude", text: $latitudeText)
                        .disabled(locationUnknown)
                    TextField("Longitude", text: $longitudeText)
                        .disabled(locationUnknown)

                    if !locationUnknown {
                        MacCoordinatePicker(
                            latitude: parseCoordinate(latitudeText),
                            longitude: parseCoordinate(longitudeText)
                        ) { lat, lon in
                            latitudeText = String(format: "%.6f", lat)
                            longitudeText = String(format: "%.6f", lon)
                        }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if let lat = parseCoordinate(latitudeText),
                       let lon = parseCoordinate(longitudeText),
                       !locationUnknown {
                        Button("Open in Maps") {
                            openInMaps(latitude: lat, longitude: lon)
                        }
                    }
                }

                Section("State") {
                    Toggle("Draft", isOn: $isDraft)
                    if isDraft {
                        Text(canFinalize ? "This draft can be finalized." : "Species and location are required to finalize.")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button("Previous") {
                        goPrevious()
                    }
                    .disabled(!canGoPrevious)
                    .keyboardShortcut("[", modifiers: .command)

                    Button("Next") {
                        goNext()
                    }
                    .disabled(!canGoNext)
                    .keyboardShortcut("]", modifiers: .command)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Delete", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .onAppear {
                loadFromStore()
            }
            .onChange(of: currentEntryID) { _, _ in
                loadFromStore()
            }
            .alert("Delete this entry?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    store.deleteEntry(id: currentEntryID)
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(isPresented: $showImagePreview) {
                if let image = currentImage() {
                    MacImagePreviewSheet(image: image)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 560)
    }

    private func loadFromStore() {
        guard let idx = entryIndex else { return }
        let entry = store.entries[idx]
        date = entry.date
        species = entry.species ?? ""
        camera = (entry.camera?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? (entry.camera ?? CameraCatalog.unknown) : CameraCatalog.unknown
        notes = entry.notes
        tagsText = entry.tags.joined(separator: ", ")
        locationUnknown = entry.locationUnknown
        latitudeText = entry.latitude.map { "\($0)" } ?? ""
        longitudeText = entry.longitude.map { "\($0)" } ?? ""
        isDraft = entry.isDraft
        selectedSavedLocationID = nil
    }

    private func saveChanges() {
        guard let idx = entryIndex else { return }

        var updated = store.entries[idx]
        updated.date = date

        let speciesTrimmed = species.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.species = speciesTrimmed.isEmpty ? nil : speciesTrimmed

        let cameraTrimmed = camera.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.camera = cameraTrimmed.isEmpty ? nil : cameraTrimmed

        updated.notes = notes
        updated.tags = parseTags(tagsText)

        if locationUnknown {
            updated.locationUnknown = true
            updated.latitude = nil
            updated.longitude = nil
        } else {
            updated.locationUnknown = false
            updated.latitude = parseCoordinate(latitudeText)
            updated.longitude = parseCoordinate(longitudeText)
        }

        if isDraft {
            updated.isDraft = true
        } else {
            updated.isDraft = updated.canFinalize ? false : true
        }

        store.entries[idx] = updated
    }

    private func goPrevious() {
        guard let idx = entryIndex, idx > 0 else { return }
        currentEntryID = store.entries[idx - 1].id
    }

    private func goNext() {
        guard let idx = entryIndex, idx < store.entries.count - 1 else { return }
        currentEntryID = store.entries[idx + 1].id
    }

    private func currentImage() -> NSImage? {
        guard let entry = currentEntry,
              let filename = entry.photoFilename, !filename.isEmpty else {
            return nil
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let url = docs?.appendingPathComponent(filename) else { return nil }
        return NSImage(contentsOf: url)
    }

    private func parseTags(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parseCoordinate(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private func openInMaps(latitude: Double, longitude: Double) {
        guard let url = URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct MacImagePreviewSheet: View {
    let image: NSImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

private struct MacCoordinatePicker: View {
    let latitude: Double?
    let longitude: Double?
    let onPick: (Double, Double) -> Void

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                if let latitude, let longitude {
                    Marker("Selected", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let point = value.location
                        if let coord = proxy.convert(point, from: .local) {
                            onPick(coord.latitude, coord.longitude)
                        }
                    }
            )
            .overlay(alignment: .topLeading) {
                Text("Click to set location")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
                    .padding(8)
            }
            .onAppear {
                updatePosition()
            }
            .onChange(of: latitude) { _, _ in
                updatePosition()
            }
            .onChange(of: longitude) { _, _ in
                updatePosition()
            }
        }
    }

    private func updatePosition() {
        if let latitude, let longitude {
            position = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
        } else {
            position = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 61.0, longitude: 8.0),
                    span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 12.0)
                )
            )
        }
    }
}
#endif
