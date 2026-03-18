//
//  MacNestboxPane.swift
//  Trailcam Journal
//
//  Nestbox overview — 3-column card grid.
//  Clicking a card opens MacNestboxDetailView.
//

#if os(macOS)
import SwiftUI

struct MacNestboxPane: View {

    @EnvironmentObject var nestboxStore: NestboxStore

    @State private var selection:   Nestbox? = nil
    @State private var showAddBox   = false
    @State private var showInactive = false

    @AppStorage("app.currentSeasonYear")
    private var seasonYear: Int = Calendar.current.component(.year, from: Date())

    // MARK: - Derived

    private var displayBoxes: [Nestbox] {
        let boxes = showInactive ? nestboxStore.nestboxes : nestboxStore.activeBoxes
        return boxes.sorted { $0.name < $1.name }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 14)
    ]

    // MARK: - Body

    var body: some View {
        Group {
            if nestboxStore.nestboxes.isEmpty {
                emptyState
            } else {
                scrollGrid
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Nestboxes")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAddBox) {
            NestboxEditSheet(box: nil) { newBox in nestboxStore.add(newBox) }
        }
        .sheet(item: $selection) { box in
            MacNestboxDetailView(boxID: box.id)
                .environmentObject(nestboxStore)
                .frame(minWidth: 700, minHeight: 520)
        }
    }

    // MARK: - Grid

    private var scrollGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(displayBoxes) { box in
                    NestboxCard(box: box, seasonYear: seasonYear)
                        .onTapGesture { selection = box }
                        .contextMenu {
                            Button("Edit Box") {
                                selection = box
                            }
                            Divider()
                            Button(box.isActive ? "Mark Inactive" : "Mark Active") {
                                var updated = box
                                updated.isActive.toggle()
                                nestboxStore.update(updated)
                            }
                            Divider()
                            Button("Delete Box", role: .destructive) {
                                nestboxStore.delete(id: box.id)
                            }
                        }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "house")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No nestboxes yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Button {
                showAddBox = true
            } label: {
                Label("Add First Box", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showAddBox = true } label: {
                Label("Add Box", systemImage: "plus")
            }
            .help("Add a new nestbox")
        }

        ToolbarItem(placement: .automatic) {
            Toggle(isOn: $showInactive) {
                Label("Show inactive", systemImage: "eye.slash")
            }
            .toggleStyle(.checkbox)
            .help("Show inactive boxes")
        }

        ToolbarItem(placement: .automatic) {
            Picker("Season", selection: $seasonYear) {
                ForEach(
                    (0..<6).map { Calendar.current.component(.year, from: Date()) - $0 },
                    id: \.self
                ) { y in Text(String(y)).tag(y) }
            }
            .pickerStyle(.menu)
            .frame(width: 90)
            .help("Active season year")
        }
    }
}

// MARK: - Nestbox card

struct NestboxCard: View {

    let box:        Nestbox
    let seasonYear: Int

    private var currentSeason: NestboxSeason? { box.season(for: seasonYear) }
    private var fledglings:    Int             { currentSeason?.totalChicksFledged ?? 0 }
    private var attempts:      Int             { currentSeason?.attempts.count ?? 0 }
    private var outcome:       AttemptOutcome? { currentSeason?.attempts.last?.outcome }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover area — shows cover photo if set, otherwise box-type icon
            ZStack(alignment: .topTrailing) {
                Group {
                    if let name = box.coverPhotoName,
                       let url  = MacImageStore.fileURL(for: name),
                       let img  = NSImage(contentsOf: url) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 100)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                            .frame(height: 100)
                            .overlay {
                                Image(systemName: box.boxType.symbol)
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            }
                    }
                }

                // Active indicator
                if !box.isActive {
                    Text("Inactive")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(6)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(box.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(box.boxType.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let hole = box.entranceHoleMm {
                        Text("∅\(hole) mm")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider().padding(.vertical, 2)

                // Current season stats
                if attempts > 0 {
                    HStack(spacing: 10) {
                        Label("\(attempts)", systemImage: "bird")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                        Label("\(fledglings)", systemImage: "bird.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(fledglings > 0 ? .green : .secondary)
                        Spacer()
                        if let oc = outcome {
                            Image(systemName: oc.symbol)
                                .font(.caption)
                                .foregroundStyle(oc.isSuccess ? .green : .secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        // Status indicator — defaults to Unknown until data is logged
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.secondary.opacity(0.4))
                                .frame(width: 7, height: 7)
                            Text("Unknown")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("?")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text("No activity logged this season")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Button {
                            // Card tap opens detail where activity is logged
                        } label: {
                            Label("Log Activity", systemImage: "plus")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppColors.primary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(10)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
    }
}

// MARK: - Add / Edit box sheet

struct NestboxEditSheet: View {

    var box:    Nestbox?
    var onSave: (Nestbox) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name:           String      = ""
    @State private var boxType:        NestboxType = .standard
    @State private var entranceHoleMm: String      = ""
    @State private var material:       String      = ""
    @State private var facing:         String      = ""
    @State private var heightCm:       String      = ""
    @State private var installedYear:  String      = ""
    @State private var isActive:       Bool        = true
    @State private var notes:          String      = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(box == nil ? "New Nestbox" : "Edit Nestbox")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            Divider()

            Form {
                TextField("Name (e.g. Box 1)", text: $name)
                Picker("Type", selection: $boxType) {
                    ForEach(NestboxType.allCases) { t in
                        Label(t.label, systemImage: t.symbol).tag(t)
                    }
                }
                Toggle("Active", isOn: $isActive)

                Section("Details") {
                    TextField("Entrance hole (mm)", text: $entranceHoleMm)
                    TextField("Material", text: $material)
                    TextField("Facing (e.g. NE)", text: $facing)
                    TextField("Height from ground (cm)", text: $heightCm)
                    TextField("Installed year", text: $installedYear)
                }

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(14)
        }
        .frame(width: 400)
        .onAppear { populateFromBox() }
    }

    private func populateFromBox() {
        guard let b = box else { return }
        name           = b.name
        boxType        = b.boxType
        entranceHoleMm = b.entranceHoleMm.map(String.init) ?? ""
        material       = b.material
        facing         = b.facing
        heightCm       = b.heightCm.map(String.init) ?? ""
        installedYear  = b.installedYear.map(String.init) ?? ""
        isActive       = b.isActive
        notes          = b.notes
    }

    private func save() {
        var b           = box ?? Nestbox(name: "")
        b.name          = name.trimmingCharacters(in: .whitespacesAndNewlines)
        b.boxType       = boxType
        b.entranceHoleMm = Int(entranceHoleMm)
        b.material      = material
        b.facing        = facing
        b.heightCm      = Int(heightCm)
        b.installedYear = Int(installedYear)
        b.isActive      = isActive
        b.notes         = notes
        onSave(b)
        dismiss()
    }
}
#endif
