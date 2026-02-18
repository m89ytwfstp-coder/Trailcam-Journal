//
//  ReviewQueueView.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 01/01/2026.
//

import SwiftUI
import MapKit

struct ReviewQueueView: View {
    @EnvironmentObject var store: EntryStore
    @EnvironmentObject var savedLocationStore: SavedLocationStore


    // Filter + selection
    @State private var filter: DraftFilter = .all
    @State private var selectionMode: Bool = false
    @State private var selectedDraftIDs: Set<UUID> = []

    // Sheets
    @State private var showBatchSpeciesSheet = false
    @State private var showBatchLocationSheet = false
    @State private var showBatchSavedLocationPicker = false
    @State private var showBatchCameraSheet = false
    @State private var showBatchTagsSheet = false


    // Batch values
    @State private var batchSpecies: String = ""
    @State private var batchCamera: String = CameraCatalog.unknown
    @State private var batchMapRefreshToken: Int = 0


    @State private var batchTagsText: String = ""       // comma separated
    @State private var batchTagsModeAdd: Bool = true    // Add vs Replace

    @State private var batchLatitude: Double? = nil
    @State private var batchLongitude: Double? = nil
    @State private var batchLocationUnknown: Bool = false
    @State private var batchSavedLocationName: String? = nil
    @State private var batchClearLocation: Bool = false

    // Alerts
    @State private var showFinalizeAlert = false
    @State private var finalizeAlertText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 10)
    ]

    // MARK: - Derived lists

    // draft indexes AFTER applying filter
    private var draftIndexes: [Int] {
        let indexes = store.entries.indices.filter { store.entries[$0].isDraft }

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

    private var totalDrafts: Int { draftIndexes.count }

    private var readyDrafts: Int {
        draftIndexes.filter { store.entries[$0].canFinalize }.count
    }

    private var selectedCount: Int {
        selectedDraftIDs.count
    }

    private var hasSelection: Bool {
        !selectedDraftIDs.isEmpty
    }

    // IDs -> current indexes (important: survives filtering + ordering changes)
    private var selectedIndexes: [Int] {
        store.entries.indices.filter { selectedDraftIDs.contains(store.entries[$0].id) }
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
        // selects drafts currently visible under the filter
        for i in draftIndexes {
            selectedDraftIDs.insert(store.entries[i].id)
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
            } else if batchClearLocation {
                // Explicitly clear GPS coordinates (but keep "unknown" off)
                store.entries[i].locationUnknown = false
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
            finalizeAlertText = "Finalized \(finalized). Skipped \(skipped) because they’re missing required fields (species and/or location/unknown)."
            showFinalizeAlert = true
        }

        // after finalizing, keep selection mode but clear selection (feels clean)
        clearSelection()
        if selectedDraftIDs.isEmpty {
            // no-op
        }
    }

    // MARK: - Views

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DraftFilter.allCases) { f in
                    Button {
                        filter = f
                    } label: {
                        Text(f.rawValue)
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

    // E5–E8 bottom bar
    private var batchBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Text("\(selectedCount) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Species") { showBatchSpeciesSheet = true }
                    .disabled(!hasSelection)

                Button("Location") { showBatchLocationSheet = true }
                    .disabled(!hasSelection)

                Button("Camera") { showBatchCameraSheet = true }
                    .disabled(!hasSelection)

                Button("Tags") { showBatchTagsSheet = true }
                    .disabled(!hasSelection)

                Button("Finalize \(selectedCount)") { finalizeSelectedDrafts() }
                    .disabled(!hasSelection)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thinMaterial)
        }
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
            .navigationTitle("Batch Species")
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

    // E5: Batch Location (pick on map OR mark unknown)
    private var batchLocationSheet: some View {
        NavigationStack {
            Form {
                Toggle("Mark location as unknown", isOn: $batchLocationUnknown)

                if !batchLocationUnknown {
                    Button("Choose saved location") {
                        showBatchSavedLocationPicker = true
                    }

                    if batchClearLocation {
                        Text("This will clear the location (no GPS, not unknown)")
                            .foregroundStyle(.secondary)
                    } else if let name = batchSavedLocationName, !name.isEmpty {
                        Text("Saved location: \(name)")
                    }

                    if let lat = batchLatitude, let lon = batchLongitude {
                        Text("Lat: \(lat)")
                        Text("Lon: \(lon)")
                    } else if !batchClearLocation {
                        Text("No location chosen yet")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        batchClearLocation = true
                        batchSavedLocationName = nil
                        batchLatitude = nil
                        batchLongitude = nil
                        batchLocationUnknown = false
                        batchMapRefreshToken += 1
                    } label: {
                        Text("Clear location")
                    }

                    MapLocationPickerInline(
                        latitude: $batchLatitude,
                        longitude: $batchLongitude,
                    )

                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.vertical, 6)
                    .onChange(of: batchLatitude) { _, newValue in
                        if newValue != nil {
                            batchClearLocation = false
                            batchSavedLocationName = nil
                        }
                    }
                    .onChange(of: batchLongitude) { _, newValue in
                        if newValue != nil {
                            batchClearLocation = false
                            batchSavedLocationName = nil
                        }
                    }
                }

            }
            .navigationTitle("Batch Location")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showBatchLocationSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        applyBatchLocation()
                        showBatchLocationSheet = false
                    }
                    .disabled(
                        !hasSelection ||
                        (
                            !batchLocationUnknown &&
                            !batchClearLocation &&
                            (batchLatitude == nil || batchLongitude == nil)
                        )
                    )

                }
            }
            .onAppear {
                batchLatitude = nil
                batchLongitude = nil
                batchLocationUnknown = false
                batchSavedLocationName = nil
                batchClearLocation = false
                batchMapRefreshToken = 0
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
            .navigationTitle("Batch Camera")
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
            .onAppear {
                batchCamera = CameraCatalog.unknown
            }
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
            .navigationTitle("Batch Tags")
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Progress line
                        HStack {
                            Text("Ready \(readyDrafts) / \(totalDrafts)")
                                .font(.headline)
                            Spacer()
                            if totalDrafts > 0 {
                                Text("Drafts")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        filterChips

                        if totalDrafts == 0 {
                            ContentUnavailableView(
                                "No drafts yet",
                                systemImage: "tray",
                                description: Text("Import photos to create draft entries for review.")
                            )
                            .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(draftIndexes, id: \.self) { i in
                                    let entry = store.entries[i]
                                    let isSel = selectedDraftIDs.contains(entry.id)

                                    if selectionMode {
                                        DraftThumbnailCell(entry: entry, isSelected: isSel)
                                            .onTapGesture {
                                                toggleSelection(for: entry.id)
                                            }
                                    } else {
                                        NavigationLink {
                                            EntryReviewView(entryIndex: i)
                                        } label: {
                                            DraftThumbnailCell(entry: entry, isSelected: false)
                                        }
                                        // E3/E5: long press enters selection mode + selects item
                                        .simultaneousGesture(
                                            LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                                                selectionMode = true
                                                selectedDraftIDs.insert(entry.id)
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, selectionMode ? 90 : 0)
                }

                if selectionMode {
                    batchBar
                }
            }
            .navigationTitle("Review")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selectionMode ? "Done" : "Select") {
                        selectionMode.toggle()
                        if !selectionMode { clearSelection() }
                    }
                    // E9: keyboard shortcut (iPad + external keyboard, future mac)
                    .keyboardShortcut(.escape, modifiers: [])
                }

                // E9: Select all visible drafts (only makes sense in selection mode)
                ToolbarItem(placement: .topBarLeading) {
                    if selectionMode {
                        Button("Select All") {
                            selectAllVisibleDrafts()
                        }
                        .keyboardShortcut("a", modifiers: [.command])
                    }
                }
            }
            .sheet(isPresented: $showBatchSpeciesSheet) { batchSpeciesSheet }
            .sheet(isPresented: $showBatchLocationSheet) { batchLocationSheet }
            .sheet(isPresented: $showBatchSavedLocationPicker) {
                SavedLocationPickerView { loc in
                    batchSavedLocationName = loc.name
                    batchLatitude = loc.latitude
                    batchLongitude = loc.longitude
                    batchLocationUnknown = false
                    batchClearLocation = false
                    batchMapRefreshToken += 1
                }

            }
            .sheet(isPresented: $showBatchCameraSheet) { batchCameraSheet }
            .sheet(isPresented: $showBatchTagsSheet) { batchTagsSheet }
            .alert("Finalize", isPresented: $showFinalizeAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(finalizeAlertText)
            }
            .background(AppColors.background)
        }
    }
}

// MARK: - Thumbnail cell

private struct DraftThumbnailCell: View {
    let entry: TrailEntry
    let isSelected: Bool

    private var missingSpecies: Bool {
        (entry.species?.isEmpty != false)
    }

    private var missingLocation: Bool {
        !(entry.locationUnknown || (entry.latitude != nil && entry.longitude != nil))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.primary.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 8) {
                EntryPhotoView(
                    entry: entry,
                    height: 110,
                    cornerRadius: 12,
                    maxPixel: 350
                )

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)

            VStack(alignment: .leading, spacing: 6) {
                if missingSpecies { Badge(text: "🐾 Species") }
                if missingLocation { Badge(text: "📍 Location") }
            }
            .padding(10)

            if isSelected {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.primary, lineWidth: 3)
            }
        }
    }
}

private struct Badge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2).bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.08))
            .clipShape(Capsule())
    }
}

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapLocationPickerInline

        init(_ parent: MapLocationPickerInline) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)

            parent.latitude = coord.latitude
            parent.longitude = coord.longitude
        }
    }


    

