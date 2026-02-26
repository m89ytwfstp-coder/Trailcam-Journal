//
//  ImportWorkflowView.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 03/01/2026.
//  v2 layout cleanup (first-user friendly)
//
//  FIX (Jan 2026):
//  - Grid cells must NOT be identified by index when we insert drafts at position 0.
//  - Use entry.id as identity, while still keeping index for navigation.
//

import SwiftUI
import PhotosUI
import Photos
import MapKit
import ImageIO


fileprivate enum DraftStatus {
    case missingSpecies
    case missingLocation
    case ready

    var title: String {
        switch self {
        case .missingSpecies: return "Missing species"
        case .missingLocation: return "Missing location"
        case .ready: return "Ready to finalize"
        }
    }

    var badgeBackground: Color {
        switch self {
        case .ready:
            return AppColors.primary.opacity(0.90)
        case .missingSpecies:
            return Color.orange.opacity(0.92)
        case .missingLocation:
            return Color.blue.opacity(0.85)
        }
    }

    var badgeForeground: Color {
        Color.white
    }
}

struct ImportWorkflowView: View {
    @EnvironmentObject var store: EntryStore

    // MARK: - Import state
    @State private var selection: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var lastImportCount: Int?

    // MARK: - Review state
    @State private var filter: DraftFilter = .all
    @State private var selectionMode: Bool = false
    @State private var selectedDraftIDs: Set<UUID> = []

    // Sheets
    @State private var showBatchSpeciesSheet = false
    @State private var showBatchLocationSheet = false
    @State private var showBatchCameraSheet = false
    @State private var showBatchTagsSheet = false
    @State private var didInitBatchLocationSheet = false

    // Batch values
    @State private var batchSpecies: String = ""
    @State private var batchCamera: String = CameraCatalog.unknown

    @State private var batchTagsText: String = ""       // comma separated
    @State private var batchTagsModeAdd: Bool = true    // Add vs Replace

    @State private var batchLatitude: Double? = nil
    @State private var batchLongitude: Double? = nil
    @State private var batchLocationUnknown: Bool = false

    // Alerts
    @State private var showFinalizeAlert = false
    @State private var finalizeAlertText = ""
    @State private var confirmDeleteSelectedDrafts = false
    @State private var deleteDraftsMessage = ""

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]


    // MARK: - Derived lists

    private var allDraftIndexes: [Int] {
        store.entries.indices.filter { store.entries[$0].isDraft }
    }

    private var draftIndexes: [Int] {
        let indexes = allDraftIndexes

        switch filter {
        case .all:
            return indexes

        case .missingSpecies:
            return indexes.filter { i in
                (store.entries[i].species?.isEmpty != false)
            }

        case .missingLocation:
            return indexes.filter { i in
                let e = store.entries[i]
                return !(e.locationUnknown || (e.latitude != nil && e.longitude != nil))
            }

        case .hasGPS:
            return indexes.filter { i in
                let e = store.entries[i]
                return (e.latitude != nil && e.longitude != nil)
            }

        case .noGPS:
            return indexes.filter { i in
                let e = store.entries[i]
                return (e.latitude == nil || e.longitude == nil)
            }
        }
    }

    /// ✅ IMPORTANT:
    /// SwiftUI grid must be keyed by a stable identity (entry.id), NOT the index.
    /// We still keep the index for navigation to EntryReviewView(entryIndex:).
    private var visibleDraftItems: [(id: UUID, index: Int)] {
        draftIndexes.map { i in
            (id: store.entries[i].id, index: i)
        }
    }

    private var totalDrafts: Int { allDraftIndexes.count }

    private var readyDrafts: Int {
        allDraftIndexes.filter { store.entries[$0].canFinalize }.count
    }

    private var selectedCount: Int { selectedDraftIDs.count }
    private var hasSelection: Bool { !selectedDraftIDs.isEmpty }

    // IDs -> current indexes (survives filtering + ordering changes)
    private var selectedIndexes: [Int] {
        store.entries.indices.filter { selectedDraftIDs.contains(store.entries[$0].id) }
    }

    // MARK: - Status

    private func status(for entry: TrailEntry) -> DraftStatus {
        if entry.species?.isEmpty != false { return .missingSpecies }
        let hasLocation = entry.locationUnknown || (entry.latitude != nil && entry.longitude != nil)
        if !hasLocation { return .missingLocation }
        return .ready
    }

    private func filterTitle(_ f: DraftFilter) -> String {
        switch f {
        case .all: return "All drafts"
        case .missingSpecies: return "Missing species"
        case .missingLocation: return "Missing location"
        case .hasGPS: return "Has location"
        case .noGPS: return "No location"
        }
    }

    // MARK: - Selection helpers

    private func clearSelection() {
        selectedDraftIDs.removeAll()
    }

    private func toggleSelection(for id: UUID) {
        if selectedDraftIDs.contains(id) {
            selectedDraftIDs.remove(id)
        } else {
            selectedDraftIDs.insert(id)
        }
    }

    private func selectAllVisibleDrafts() {
        for item in visibleDraftItems {
            selectedDraftIDs.insert(item.id)
        }
    }

    // MARK: - Batch apply functions

    private func applyBatchSpecies() {
        guard !batchSpecies.isEmpty else { return }
        for i in selectedIndexes {
            store.entries[i].species = batchSpecies
        }
    }

    private func applyBatchLocation() {
        for i in selectedIndexes {
            if batchLocationUnknown {
                store.entries[i].locationUnknown = true
                store.entries[i].latitude = nil
                store.entries[i].longitude = nil
            } else {
                store.entries[i].locationUnknown = false
                store.entries[i].latitude = batchLatitude
                store.entries[i].longitude = batchLongitude
            }
        }
    }

    private func applyBatchCamera() {
        let cam = batchCamera.trimmingCharacters(in: .whitespacesAndNewlines)
        for i in selectedIndexes {
            store.entries[i].camera = cam.isEmpty ? nil : cam
        }
    }

    private func parseTags(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func applyBatchTags() {
        let newTags = parseTags(batchTagsText)
        guard !newTags.isEmpty else { return }

        for i in selectedIndexes {
            if batchTagsModeAdd {
                let merged = Array(Set(store.entries[i].tags + newTags)).sorted()
                store.entries[i].tags = merged
            } else {
                store.entries[i].tags = Array(Set(newTags)).sorted()
            }
        }
    }

    private func finalizeSelectedDrafts() {
        let idxs = selectedIndexes
        guard !idxs.isEmpty else { return }

        var finalized = 0
        var skipped = 0

        for i in idxs {
            if store.entries[i].canFinalize {
                store.entries[i].isDraft = false
                finalized += 1
            } else {
                skipped += 1
            }
        }

        if skipped > 0 {
            finalizeAlertText = "Finalized \(finalized). Skipped \(skipped) because required information is missing."
            showFinalizeAlert = true
        }

        clearSelection()
        selectionMode = false
    }

    private func deleteSelectedDrafts() {
        let idxs = selectedIndexes
        guard !idxs.isEmpty else { return }

        // Safety: only delete drafts
        let draftIDsToDelete: Set<UUID> = Set(
            idxs
                .map { store.entries[$0] }
                .filter { $0.isDraft }
                .map { $0.id }
        )

        guard !draftIDsToDelete.isEmpty else { return }

        store.deleteEntries(ids: draftIDsToDelete)

        clearSelection()
        selectionMode = false
    }

    private func extractMetadataFromImageData(_ data: Data) -> (date: Date?, latitude: Double?, longitude: Double?) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return (nil, nil, nil)
        }

        // --- Date (EXIF DateTimeOriginal preferred) ---
        var date: Date? = nil

        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let s = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            date = parseExifDateString(s)
        }

        if date == nil,
           let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let s = tiff[kCGImagePropertyTIFFDateTime] as? String {
            date = parseExifDateString(s)
        }

        // --- GPS ---
        var lat: Double? = nil
        var lon: Double? = nil

        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            if let v = gps[kCGImagePropertyGPSLatitude] as? Double { lat = v }
            if let v = gps[kCGImagePropertyGPSLongitude] as? Double { lon = v }

            // Some files use N/S/E/W refs
            if let ref = gps[kCGImagePropertyGPSLatitudeRef] as? String, ref.uppercased() == "S" {
                if let v = lat { lat = -abs(v) }
            }
            if let ref = gps[kCGImagePropertyGPSLongitudeRef] as? String, ref.uppercased() == "W" {
                if let v = lon { lon = -abs(v) }
            }
        }

        return (date, lat, lon)
    }

    private func parseExifDateString(_ s: String) -> Date? {
        // Typical EXIF: "2026:01:17 17:09:12"
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return fmt.date(from: s)
    }

    // MARK: - Sheets

    private var batchSpeciesSheet: some View {
        NavigationStack {
            Form {
                Picker("Species", selection: $batchSpecies) {
                    Text("— Select —").tag("")
                    ForEach(SpeciesCatalog.all) { s in
                        Text(s.nameNO).tag(s.nameNO)
                    }
                }
            }
            .navigationTitle("Add species")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showBatchSpeciesSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        applyBatchSpecies()
                        showBatchSpeciesSheet = false
                    }
                    .disabled(batchSpecies.isEmpty || !hasSelection)
                }
            }
            .onAppear { batchSpecies = "" }
        }
    }

    private var batchLocationSheet: some View {
        NavigationStack {
            Form {
                Toggle("Mark location as unknown", isOn: $batchLocationUnknown)

                NavigationLink {
                    SavedLocationPickerView { loc in
                        batchLocationUnknown = false
                        batchLatitude = loc.latitude
                        batchLongitude = loc.longitude
                    }
                } label: {
                    Label("Choose saved location", systemImage: "bookmark")
                }

                if !batchLocationUnknown {
                    if let lat = batchLatitude, let lon = batchLongitude {
                        Text("Lat: \(lat)")
                        Text("Lon: \(lon)")
                    } else {
                        Text("Tap on the map to choose a location")
                            .foregroundStyle(.secondary)
                    }

                    MapLocationPickerInline(
                        latitude: $batchLatitude,
                        longitude: $batchLongitude
                    )
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Set location")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        didInitBatchLocationSheet = false
                        showBatchLocationSheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        applyBatchLocation()
                        didInitBatchLocationSheet = false
                        showBatchLocationSheet = false
                    }
                    .disabled(!hasSelection || (!batchLocationUnknown && (batchLatitude == nil || batchLongitude == nil)))
                }
            }
            .task {
                if !didInitBatchLocationSheet {
                    batchLatitude = nil
                    batchLongitude = nil
                    batchLocationUnknown = false
                    didInitBatchLocationSheet = true
                }
            }
        }
    }

    private var batchCameraSheet: some View {
        NavigationStack {
            Form {
                Picker("Camera", selection: $batchCamera) {
                    ForEach(CameraCatalog.all, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
            }
            .navigationTitle("Set camera")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showBatchCameraSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        applyBatchCamera()
                        showBatchCameraSheet = false
                    }
                    .disabled(!hasSelection)
                }
            }
            .onAppear { batchCamera = CameraCatalog.unknown }
        }
    }

    private var batchTagsSheet: some View {
        NavigationStack {
            Form {
                TextField("Tags (comma separated)", text: $batchTagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                Toggle("Add to existing tags", isOn: $batchTagsModeAdd)

                Text("Example: jerv, natt, snø")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Add tags")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showBatchTagsSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        applyBatchTags()
                        showBatchTagsSheet = false
                    }
                    .disabled(!hasSelection || parseTags(batchTagsText).isEmpty)
                }
            }
            .onAppear {
                batchTagsText = ""
                batchTagsModeAdd = true
            }
        }
    }

    // MARK: - v2 UI blocks

    private var compactImportRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Import")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.primary)

            Text("\(totalDrafts) draft(s) created")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)

            PhotosPicker(selection: $selection, matching: .images) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Import more photos")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColors.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if isImporting {
                ProgressView("Importing…")
            }

            if let lastImportCount {
                Text("Imported \(lastImportCount) draft(s).")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .onChange(of: selection) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await importItems(newItems) }
        }
    }

    private var fullImportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.primary)

            Text("Import photos, then review and finalize drafts")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import from Photos")
                            .font(.headline)
                            .foregroundStyle(AppColors.primary)

                        Text("Each image becomes a draft entry")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()
                }

                PhotosPicker(
                    selection: $selection,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Import")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                if isImporting {
                    ProgressView("Importing…")
                }

                if let lastImportCount {
                    Text("Imported \(lastImportCount) draft(s).")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppColors.primary.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .onChange(of: selection) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await importItems(newItems) }
        }
    }

    private var reviewHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Review drafts")
                .font(.title3.bold())
                .foregroundStyle(AppColors.primary)

            Text("\(readyDrafts) of \(totalDrafts) ready to finalize")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            if readyDrafts != totalDrafts && totalDrafts > 0 {
                Text("Some drafts are missing required information.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DraftFilter.allCases) { f in
                    Button {
                        filter = f
                    } label: {
                        Text(filterTitle(f))
                            .font(.subheadline).bold()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    filter == f
                                    ? AppColors.primary.opacity(0.18)
                                    : Color.black.opacity(0.06)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func batchActionButton(
        systemImage: String,
        title: String,
        role: ButtonRole? = nil,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role) { action() } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 56)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.45)
    }

    private var batchBar: some View {
        VStack(spacing: 10) {
            Divider()

            // Selection status
            HStack(spacing: 10) {
                if selectedCount == 0 {
                    Text("Tap drafts to select")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Label("\(selectedCount) selected", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColors.primary)
                }

                Spacer()

                if hasSelection {
                    Button("Clear") { clearSelection() }
                        .font(.footnote.weight(.semibold))
                }
            }
            .padding(.horizontal, 14)

            // Action row (icon + label)
            HStack(spacing: 10) {

                batchActionButton(
                    icon: "pawprint.fill",
                    title: "Species",
                    tint: AppColors.primary,
                    isEnabled: hasSelection
                ) { showBatchSpeciesSheet = true }

                batchActionButton(
                    icon: "mappin.and.ellipse",
                    title: "Location",
                    tint: AppColors.primary,
                    isEnabled: hasSelection
                ) { showBatchLocationSheet = true }

                batchActionButton(
                    icon: "camera",
                    title: "Camera",
                    tint: AppColors.primary,
                    isEnabled: hasSelection
                ) { showBatchCameraSheet = true }

                batchActionButton(
                    icon: "tag",
                    title: "Tags",
                    tint: AppColors.primary,
                    isEnabled: hasSelection
                ) { showBatchTagsSheet = true }

                // 🚨 destructive action last
                batchActionButton(
                    icon: "trash",
                    title: "Delete",
                    tint: .red,
                    isEnabled: hasSelection
                ) {
                    deleteDraftsMessage = "Delete \(selectedCount) draft(s)? This cannot be undone."
                    confirmDeleteSelectedDrafts = true
                }
            }

            .padding(.horizontal, 12)

            // Finalize (primary CTA)
            Button {
                finalizeSelectedDrafts()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text(selectedCount == 0 ? "Finalize" : "Finalize \(selectedCount)")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColors.primary.opacity(hasSelection ? 0.16 : 0.08))
                .foregroundStyle(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!hasSelection)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .background(.thinMaterial)
    }

    private func batchActionButton(
        icon: String,
        title: String,
        tint: Color,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.black.opacity(isEnabled ? 0.06 : 0.03))
            .foregroundStyle(isEnabled ? tint : AppColors.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {

                        compactImportRow

                        if totalDrafts > 0 {
                            reviewHeader
                            filterChips

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(visibleDraftItems, id: \.id) { item in
                                    let entry = store.entries[item.index]
                                    let st = status(for: entry)
                                    let isSelected = selectedDraftIDs.contains(item.id)

                                    Button {
                                        toggleSelection(for: item.id)
                                    } label: {
                                        DraftGridCell(
                                            entry: entry,
                                            status: st,
                                            isSelected: isSelected
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 140) // space for batchBar
                        } else {
                            // Empty state
                            VStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundStyle(AppColors.primary.opacity(0.8))
                                    .padding(.top, 24)

                                Text("No drafts yet")
                                    .font(.headline)

                                Text("Import photos to create draft entries you can review and finalize.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)

                                Spacer(minLength: 30)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 80)
                        }
                    }
                    .padding(.bottom, 40)
                }

                // Bottom batch bar
                if totalDrafts > 0 {
                    batchBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Select All") {
                        selectAllVisibleDrafts()
                    }
                    .disabled(visibleDraftItems.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        clearSelection()
                    }
                    .disabled(!hasSelection)
                }
            }
            .sheet(isPresented: $showBatchSpeciesSheet) { batchSpeciesSheet }
            .sheet(isPresented: $showBatchLocationSheet) { batchLocationSheet }
            .sheet(isPresented: $showBatchCameraSheet) { batchCameraSheet }
            .sheet(isPresented: $showBatchTagsSheet) { batchTagsSheet }
            .alert("Done", isPresented: $showFinalizeAlert) {
                Button("OK") { }
            } message: {
                Text(finalizeAlertText)
            }
            .alert("Confirm delete", isPresented: $confirmDeleteSelectedDrafts) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deleteSelectedDrafts() }
            } message: {
                Text(deleteDraftsMessage)
            }
        }
    }

    // MARK: - Cell

    private struct DraftGridCell: View {
        let entry: TrailEntry
        let status: DraftStatus
        let isSelected: Bool

        var body: some View {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.04))

                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .topLeading) {
                        EntryPhotoView(entry: entry, height: 100, cornerRadius: 14, maxPixel: 320)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // Status badge (high contrast)
                        Text(status.title)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(status.badgeBackground)
                            .foregroundStyle(status.badgeForeground)
                            .clipShape(Capsule())
                            .padding(6)
                    }

                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(10)

                // Selection ring
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 3)
                    .padding(2)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(height: 160)
        }
    }

    // MARK: - Import logic

    private func importItems(_ items: [PhotosPickerItem]) async {
        isImporting = true
        lastImportCount = nil

        var imported = 0

        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let meta = extractMetadataFromImageData(data)
                    let assetId = item.itemIdentifier

                    let filename: String? = {
                        guard assetId == nil else { return nil }
                        return ImageStorage.saveDownsampledJPEGToDocuments(data: data)
                    }()

                    // Keep entry even if file save fails when Photos asset id exists.
                    if assetId == nil, filename == nil { continue }

                    let newEntry = TrailEntry(
                        id: UUID(),
                        date: meta.date ?? Date(),
                        species: nil,
                        camera: nil,
                        notes: "",
                        tags: [],
                        photoFilename: filename,
                        latitude: meta.latitude,
                        longitude: meta.longitude,
                        locationUnknown: false,
                        isDraft: true,
                        originalFilename: nil,
                        photoAssetId: assetId
                    )

                    store.entries.insert(newEntry, at: 0)
                    imported += 1
                }

            } catch {
                // ignore individual failures
            }
        }

        await MainActor.run {
            isImporting = false
            lastImportCount = imported
            selection = []
        }
    }
}
