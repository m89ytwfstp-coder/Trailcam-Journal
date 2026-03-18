
//
//  MacCustomPinSheets.swift
//  Trailcam Journal
//
//  Quick-add sheet, detail panel, edit sheet, and layer toggle panel
//  for the MapPins-v1 custom pins feature.
//

#if os(macOS)
import SwiftUI
import CoreLocation
import UniformTypeIdentifiers

// MARK: - MacQuickAddPinSheet
//
// Compact bottom-sheet that slides up when the user long-presses the map.
// Contains a type picker (grouped by category) and an optional name field.

struct MacQuickAddPinSheet: View {
    let coordinate: CLLocationCoordinate2D
    var onPlace: (CustomPin) -> Void
    var onCancel: () -> Void

    @State private var selectedType: CustomPinType = .den
    @State private var nameText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Drag handle hint
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: .tertiaryLabelColor))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Type picker — scrollable row grouped by category
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(CustomPinCategory.allCases, id: \.self) { category in
                        categoryColumn(category)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Divider()

            // Name field
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField(selectedType.displayName, text: $nameText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.escape)

                Spacer()

                Button {
                    var pin = CustomPin(
                        type: selectedType,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    pin.name = trimmed.isEmpty ? nil : trimmed
                    onPlace(pin)
                } label: {
                    Label("Place Pin", systemImage: "mappin.and.ellipse")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(radius: 12, y: -4)
    }

    @ViewBuilder
    private func categoryColumn(_ category: CustomPinCategory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.displayName.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            HStack(spacing: 6) {
                ForEach(CustomPinType.allCases.filter { $0.category == category }, id: \.self) { type in
                    typeButton(type)
                }
            }
        }
    }

    @ViewBuilder
    private func typeButton(_ type: CustomPinType) -> some View {
        let isSelected = selectedType == type
        Button {
            selectedType = type
            // Clear name if it was just the previous type's displayName
            if nameText == selectedType.displayName || nameText.isEmpty {
                nameText = ""
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? type.color : Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? type.color : Color(nsColor: .separatorColor),
                                        lineWidth: isSelected ? 2 : 1)
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: type.sfSymbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? .white : type.color)
                }

                Text(type.displayName)
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? type.color : .secondary)
                    .lineLimit(1)
                    .frame(width: 50)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MacCustomPinDetailPanel
//
// Slide-in panel on the right side of the map, shown when a custom pin is tapped.
// Matches the style of TripDetailPanel.

struct MacCustomPinDetailPanel: View {
    let pin: CustomPin
    var onClose: () -> Void
    var onUpdate: (CustomPin) -> Void
    var onDelete: (UUID) -> Void

    @State private var editingPin: CustomPin? = nil
    @State private var notesText: String = ""
    @State private var showDeleteConfirm = false
    @State private var photo: NSImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(alignment: .top, spacing: 8) {
                DiamondPinBadge(type: pin.type, size: 32)
                    .opacity(pin.isActive ? 1.0 : 0.4)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pin.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        Text(pin.type.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(pin.type.category.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        editingPin = pin
                    } label: {
                        Text("Edit")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)

            Divider()

            // Metadata
            VStack(alignment: .leading, spacing: 8) {
                metaRow(label: "Date added",
                        value: pin.dateAdded.formatted(date: .abbreviated, time: .omitted))
                metaRow(label: "Date sighted",
                        value: pin.dateSighted.map {
                            $0.formatted(date: .abbreviated, time: .omitted)
                        } ?? "—")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Active / Inactive toggle
            HStack {
                Text("Status")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Status", selection: Binding(
                    get: { pin.isActive },
                    set: { newVal in
                        var updated = pin
                        updated.isActive = newVal
                        onUpdate(updated)
                    }
                )) {
                    Text("Active").tag(true)
                    Text("Inactive").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Notes
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $notesText)
                    .font(.subheadline)
                    .frame(minHeight: 64, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onChange(of: notesText) { _, newVal in
                        var updated = pin
                        updated.notes = newVal.isEmpty ? nil : newVal
                        onUpdate(updated)
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Photo (if one has been set)
            if let img = photo {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
            }

            Divider()

            // Linked entries (MVP placeholder)
            VStack(alignment: .leading, spacing: 4) {
                Text("Linked entries")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("No linked entries")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Spacer(minLength: 0)

            Divider()

            // Delete button
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete Pin", systemImage: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .leading) { Divider() }
        .onAppear {
            notesText = pin.notes ?? ""
            loadPhoto()
        }
        .onChange(of: pin.notes) { _, newNotes in
            // Sync if notes changed externally (e.g., via Edit sheet)
            let external = newNotes ?? ""
            if external != notesText { notesText = external }
        }
        .onChange(of: pin.photoFilename) { _, _ in
            loadPhoto()
        }
        .confirmationDialog(
            "Delete \"\(pin.displayName)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Pin", role: .destructive) { onDelete(pin.id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(item: $editingPin) { p in
            MacPinEditSheet(pin: p, onSave: { updated in
                onUpdate(updated)
                editingPin = nil
            })
        }
    }

    private func loadPhoto() {
        photo = pin.photoFilename.flatMap { CustomPinStore.loadPhoto(filename: $0) }
    }

    @ViewBuilder
    private func metaRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}

// MARK: - MacPinEditSheet
//
// Full edit form for all pin metadata. Opened from the detail panel's Edit button.

struct MacPinEditSheet: View {
    var pin: CustomPin
    var onSave: (CustomPin) -> Void

    @State private var name:          String       = ""
    @State private var type:          CustomPinType = .den
    @State private var dateSighted:   Date?        = nil
    @State private var hasSighted:    Bool         = false
    @State private var isActive:      Bool         = true
    @State private var notes:         String       = ""
    @State private var photoFilename: String?      = nil  // filename in pinphotos/
    @State private var previewImage:  NSImage?     = nil  // loaded for preview

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Pin")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            Form {
                TextField("Name (optional)", text: $name)

                Picker("Type", selection: $type) {
                    ForEach(CustomPinType.allCases, id: \.self) { t in
                        Label(t.displayName, systemImage: t.sfSymbol).tag(t)
                    }
                }

                Toggle("Date sighted", isOn: $hasSighted)
                if hasSighted {
                    DatePicker("", selection: Binding(
                        get: { dateSighted ?? Date() },
                        set: { dateSighted = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                }

                Toggle("Active", isOn: $isActive)

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...)

                // Photo
                Section("Photo") {
                    if let img = previewImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button("Remove photo", role: .destructive) {
                            // Delete old photo file
                            if let fn = photoFilename { CustomPinStore.deletePhoto(filename: fn) }
                            photoFilename = nil
                            previewImage  = nil
                        }
                        .font(.subheadline)
                    }
                    Button(previewImage == nil ? "Add photo…" : "Replace photo…") {
                        choosePhoto()
                    }
                    .font(.subheadline)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(false)

            Divider()

            HStack {
                Spacer()
                Button("Save") {
                    var updated = pin
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.name         = trimmed.isEmpty ? nil : trimmed
                    updated.type         = type
                    updated.dateSighted  = hasSighted ? (dateSighted ?? Date()) : nil
                    updated.isActive     = isActive
                    updated.notes        = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.photoFilename = photoFilename
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
            }
            .padding(14)
        }
        .frame(width: 380)
        .onAppear {
            name          = pin.name ?? ""
            type          = pin.type
            isActive      = pin.isActive
            notes         = pin.notes ?? ""
            photoFilename = pin.photoFilename
            previewImage  = pin.photoFilename.flatMap { CustomPinStore.loadPhoto(filename: $0) }
            if let d = pin.dateSighted {
                hasSighted  = true
                dateSighted = d
            }
        }
    }

    // MARK: - Photo picker

    private func choosePhoto() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes   = [.jpeg, .png, .heic, .tiff]
        panel.canChooseFiles         = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose a photo for this pin"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let img = NSImage(contentsOf: url) else { return }

        // Delete the old photo file before replacing
        if let old = photoFilename { CustomPinStore.deletePhoto(filename: old) }

        if let filename = CustomPinStore.savePhoto(img) {
            photoFilename = filename
            previewImage  = img
        }
    }
}

// MARK: - MacSavedLocationDetailPanel
//
// Slide-in panel for saved locations / hubs when their map pin is tapped.
// Replaces the removed HubDetailPanel with a simpler read-only view.

struct MacSavedLocationDetailPanel: View {
    let location:      SavedLocation
    let nearbyEntries: [TrailEntry]
    var onClose:       () -> Void
    var onSelectEntry: (TrailEntry) -> Void
    var onDelete:      (() -> Void)? = nil

    @State private var showDeleteConfirm = false

    private var firstVisit: Date? { nearbyEntries.map(\.date).min() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(location.name)
                        .font(.headline)
                        .lineLimit(2)
                    if let r = location.radius {
                        Text(r >= 1000
                             ? String(format: "%.0f km radius", r / 1_000)
                             : String(format: "%.0f m radius", r))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Saved location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            Divider()

            // Stats row — entries count + first visit (matches old hub panel)
            HStack(spacing: 0) {
                statCell(label: "Entries",
                         value: "\(nearbyEntries.count)")
                Divider().frame(height: 32)
                statCell(label: "First Visit",
                         value: firstVisit.map {
                             $0.formatted(.dateTime.month(.abbreviated).year())
                         } ?? "—")
            }
            .padding(.vertical, 10)

            Divider()

            // Entry thumbnails
            if nearbyEntries.isEmpty {
                Text("No entries in this area yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 6
                    ) {
                        ForEach(nearbyEntries.prefix(30)) { entry in
                            Button { onSelectEntry(entry) } label: {
                                MacThumbnail(entry: entry, cornerRadius: 6)
                                    .frame(height: 80)
                                    .clipped()
                            }
                            .buttonStyle(.plain)
                            .help(entry.displayTitle)
                        }
                    }
                    .padding(10)
                }
            }

            Spacer(minLength: 0)

            // Delete button (hub only)
            if onDelete != nil {
                Divider()
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete Hub", systemImage: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(14)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .leading) { Divider() }
        .confirmationDialog(
            "Delete \"\(location.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Hub", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the hub and its radius. Your entries are kept.")
        }
    }

    @ViewBuilder
    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MacLayerPanel
//
// Popover content for the Layers toolbar button.
// All toggles are stored in AppStorage so they survive app restarts.

struct MacLayerPanel: View {
    @AppStorage("map.layer.entryPins")      var showEntryPins:      Bool = true
    @AppStorage("map.layer.customPins")     var showCustomPins:     Bool = true
    @AppStorage("map.layer.infrastructure") var showInfrastructure: Bool = true
    @AppStorage("map.layer.wildlifeSigns")  var showWildlifeSigns:  Bool = true
    @AppStorage("map.layer.terrain")        var showTerrain:        Bool = true
    @AppStorage("map.layer.tripTracks")     var showTripTracks:     Bool = true
    @AppStorage("map.layer.showInactive")   var showInactivePins:   Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Layers")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: 0) {

                layerRow(label: "Entry pins", symbol: "mappin.circle.fill",
                         binding: $showEntryPins)

                layerRow(label: "Custom pins", symbol: "diamond.fill",
                         binding: $showCustomPins)

                // Sub-toggles for custom pin categories
                Group {
                    subLayerRow(label: "Infrastructure",  symbol: "wrench.and.screwdriver",
                                binding: $showInfrastructure)
                    subLayerRow(label: "Wildlife signs",  symbol: "pawprint",
                                binding: $showWildlifeSigns)
                    subLayerRow(label: "Terrain",         symbol: "mountain.2",
                                binding: $showTerrain)
                }
                .opacity(showCustomPins ? 1.0 : 0.4)
                .disabled(!showCustomPins)

                layerRow(label: "Trip tracks", symbol: "point.bottomleft.forward.to.point.topright.scurvepath.fill",
                         binding: $showTripTracks)
            }
            .padding(.vertical, 4)

            Divider()

            layerRow(label: "Show inactive pins", symbol: "eye.slash",
                     binding: $showInactivePins)
                .padding(.bottom, 8)
        }
        .frame(width: 260)
    }

    @ViewBuilder
    private func layerRow(label: String, symbol: String, binding: Binding<Bool>) -> some View {
        HStack {
            Label(label, systemImage: symbol)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func subLayerRow(label: String, symbol: String, binding: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 16)
            Label(label, systemImage: symbol)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.vertical, 6)
    }
}
#endif
