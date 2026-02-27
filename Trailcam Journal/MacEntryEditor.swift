import SwiftUI
import AppKit
import MapKit

#if os(macOS)
enum MacEntryEditorLogic {
    static func canFinalize(species: String, locationUnknown: Bool, latitudeText: String, longitudeText: String) -> Bool {
        let hasSpecies = !species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLocation = locationUnknown || (parseCoordinate(latitudeText) != nil && parseCoordinate(longitudeText) != nil)
        return hasSpecies && hasLocation
    }

    static func parseCoordinate(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }
}

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
        MacEntryEditorLogic.canFinalize(
            species: species,
            locationUnknown: locationUnknown,
            latitudeText: latitudeText,
            longitudeText: longitudeText
        )
    }

    private var titleText: String {
        currentEntry?.originalFilename ?? "Edit Entry"
    }

    private var subtitleText: String {
        if isDraft {
            return canFinalize ? "Draft ready to finalize" : "Draft needs species and location"
        }
        return "Finalized entry"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AppHeader(title: "Edit Entry", subtitle: titleText)

                    statusBar
                    photoCard
                    basicsCard
                    notesAndTagsCard
                    locationCard
                    stateCard
                }
                .padding(.top, 2)
                .padding(.bottom, 20)
            }
            .appScreenBackground()
            .navigationTitle("")
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
        .frame(minWidth: 620, minHeight: 700)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            statusChip(text: isDraft ? "Draft" : "Finalized", systemImage: isDraft ? "square.and.pencil" : "checkmark.seal.fill")
            statusChip(text: subtitleText, systemImage: canFinalize ? "checkmark.circle.fill" : "exclamationmark.circle")
            Spacer()
        }
        .padding(.horizontal)
    }

    private var photoCard: some View {
        editorCard(title: "Photo") {
            if let image = currentImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack {
                    Text(currentEntry?.date.formatted(date: .abbreviated, time: .shortened) ?? "")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Button("Open Fullscreen Preview") {
                        showImagePreview = true
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text("No local image available for preview.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var basicsCard: some View {
        editorCard(title: "Basics") {
            LabeledContent("Date") {
                DatePicker("", selection: $date)
                    .labelsHidden()
            }

            Divider().opacity(0.25)

            LabeledContent("Species") {
                Picker("Species", selection: $species) {
                    Text("— Select —").tag("")
                    ForEach(SpeciesCatalog.all) { item in
                        Text(item.nameNO).tag(item.nameNO)
                    }
                }
                .frame(width: 220)
            }

            Divider().opacity(0.25)

            LabeledContent("Camera") {
                Picker("Camera", selection: $camera) {
                    ForEach(CameraCatalog.all, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }
                .frame(width: 220)
            }
        }
    }

    private var notesAndTagsCard: some View {
        editorCard(title: "Notes & Tags") {
            Text("Notes")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)

            TextEditor(text: $notes)
                .font(.body)
                .frame(minHeight: 110)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppColors.primary.opacity(0.10), lineWidth: 1)
                        )
                )

            Text("Tags")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)

            TextField("Comma separated tags", text: $tagsText)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var locationCard: some View {
        editorCard(title: "Location") {
            Toggle("Location unknown", isOn: $locationUnknown)

            LabeledContent("Saved location") {
                Picker("Saved location", selection: $selectedSavedLocationID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(savedLocationStore.locations) { location in
                        Text(location.name).tag(Optional(location.id))
                    }
                }
                .frame(width: 220)
                .onChange(of: selectedSavedLocationID) { _, id in
                    guard let id,
                          let location = savedLocationStore.locations.first(where: { $0.id == id }) else { return }
                    latitudeText = String(location.latitude)
                    longitudeText = String(location.longitude)
                    locationUnknown = false
                }
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latitude")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    TextField("Latitude", text: $latitudeText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(locationUnknown)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Longitude")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    TextField("Longitude", text: $longitudeText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(locationUnknown)
                }
            }

            if !locationUnknown {
                MacCoordinatePicker(
                    latitude: parseCoordinate(latitudeText),
                    longitude: parseCoordinate(longitudeText)
                ) { lat, lon in
                    latitudeText = String(format: "%.6f", lat)
                    longitudeText = String(format: "%.6f", lon)
                }
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let lat = parseCoordinate(latitudeText),
               let lon = parseCoordinate(longitudeText),
               !locationUnknown {
                Button("Open in Maps") {
                    openInMaps(latitude: lat, longitude: lon)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var stateCard: some View {
        editorCard(title: "State") {
            Toggle("Draft", isOn: $isDraft)

            if isDraft {
                Text(canFinalize ? "This draft can be finalized." : "Species and location are required to finalize.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func editorCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.primary)

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppColors.primary.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    private func statusChip(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(AppColors.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(AppColors.primary.opacity(0.12)))
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
        MacEntryEditorLogic.parseCoordinate(text)
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
