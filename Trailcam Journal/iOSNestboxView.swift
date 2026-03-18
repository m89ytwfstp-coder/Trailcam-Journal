
//
//  iOSNestboxView.swift
//  Trailcam Journal
//
//  iOS field view for nestbox monitoring.
//  The Mac companion has the full management view (MacNestboxPane).
//  This view focuses on checking boxes and logging seasonal data.
//  checkDate must NEVER default to today — Simon transcribes from paper.
//

#if os(iOS)
import SwiftUI

struct iOSNestboxView: View {
    @EnvironmentObject private var nestboxStore: NestboxStore

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showAddBox:   Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if nestboxStore.nestboxes.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(nestboxStore.nestboxes.filter(\.isActive)) { box in
                            NavigationLink {
                                iOSNestboxDetailView(box: box, year: selectedYear)
                                    .environmentObject(nestboxStore)
                            } label: {
                                iOSNestboxRow(box: box, year: selectedYear)
                            }
                        }
                        .onDelete { offsets in
                            let activeBoxes = nestboxStore.nestboxes.filter(\.isActive)
                            offsets.map { activeBoxes[$0].id }
                                   .forEach { nestboxStore.delete(id: $0) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Nestboxes \(selectedYear)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddBox = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddBox) {
                iOSAddNestboxSheet().environmentObject(nestboxStore)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bird")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(AppColors.primary.opacity(0.3))
            Text("No nestboxes yet")
                .font(.headline).foregroundStyle(AppColors.primary)
            Text("Tap + to add a nestbox.")
                .font(.subheadline).foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Row

private struct iOSNestboxRow: View {
    let box: Nestbox
    let year: Int

    private var season: NestboxSeason? { box.season(for: year) }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(box.name)
                    .font(.headline).foregroundStyle(AppColors.primary)
                Label(box.boxType.label, systemImage: box.boxType.symbol)
                    .font(.caption).foregroundStyle(AppColors.textSecondary)
                if let s = season, !s.attempts.isEmpty {
                    let species = s.attempts.compactMap { $0.species.isEmpty ? nil : $0.species }.joined(separator: ", ")
                    if !species.isEmpty {
                        Text(species)
                            .font(.caption).foregroundStyle(AppColors.textSecondary).lineLimit(1)
                    }
                } else {
                    Text("No data for \(year)")
                        .font(.caption).foregroundStyle(AppColors.textSecondary)
                }
            }
            Spacer()
            if let s = season {
                Text("\(s.totalChicksFledged) fledged")
                    .font(.caption2).foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail view

struct iOSNestboxDetailView: View {
    let box: Nestbox
    let year: Int

    @EnvironmentObject private var nestboxStore: NestboxStore
    @State private var showAddAttempt = false

    private var season: NestboxSeason? { box.season(for: year) }

    var body: some View {
        List {
            Section("Breeding attempts \(year)") {
                if let season = season, !season.attempts.isEmpty {
                    ForEach(season.attempts) { attempt in
                        iOSAttemptRow(attempt: attempt)
                    }
                } else {
                    Text("No attempts recorded")
                        .foregroundStyle(.secondary)
                }
                Button("Add attempt") {
                    showAddAttempt = true
                }
                .foregroundStyle(AppColors.primary)
            }
            if let season = season {
                Section("Season summary") {
                    LabeledContent("Eggs laid",    value: season.totalEggsLaid    > 0 ? "\(season.totalEggsLaid)"    : "—")
                    LabeledContent("Chicks fledged", value: season.totalChicksFledged > 0 ? "\(season.totalChicksFledged)" : "—")
                    if !season.notes.isEmpty {
                        Text(season.notes).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Box details") {
                LabeledContent("Type",     value: box.boxType.label)
                if let h = box.entranceHoleMm { LabeledContent("Entrance hole", value: "\(h) mm") }
                if let y = box.installedYear  { LabeledContent("Installed",     value: "\(y)") }
                if !box.notes.isEmpty { Text(box.notes).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(box.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddAttempt) {
            iOSAddAttemptSheet(box: box, year: year)
                .environmentObject(nestboxStore)
        }
    }
}

// MARK: - Attempt row

private struct iOSAttemptRow: View {
    let attempt: NestboxAttempt

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if !attempt.species.isEmpty {
                    Text(attempt.species).font(.headline).foregroundStyle(AppColors.primary)
                }
                Spacer()
                Label(attempt.outcome.label, systemImage: attempt.outcome.symbol)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            if let eggs = attempt.eggsLaid, let chicks = attempt.chicksFledged {
                Text("\(eggs) eggs → \(chicks) fledged")
                    .font(.subheadline).foregroundStyle(AppColors.textSecondary)
            }
            if !attempt.notes.isEmpty {
                Text(attempt.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add attempt sheet

struct iOSAddAttemptSheet: View {
    let box:  Nestbox
    let year: Int

    @EnvironmentObject private var nestboxStore: NestboxStore
    @Environment(\.dismiss) private var dismiss

    @State private var species:       String         = ""
    @State private var outcome:       AttemptOutcome = .unknown
    @State private var eggsLaid:      String         = ""
    @State private var chicksFledged: String         = ""
    @State private var firstEggDate:  Date?          = nil  // NEVER defaults to today
    @State private var notes:         String         = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Species & outcome") {
                    TextField("Species (e.g. Rødstjert)", text: $species)
                    Picker("Outcome", selection: $outcome) {
                        ForEach(AttemptOutcome.allCases) { o in
                            Label(o.label, systemImage: o.symbol).tag(o)
                        }
                    }
                }

                Section("Counts") {
                    TextField("Eggs laid", text: $eggsLaid)
                        .keyboardType(.numberPad)
                    TextField("Chicks fledged", text: $chicksFledged)
                        .keyboardType(.numberPad)
                }

                // First egg date — NEVER defaults to today
                Section("First egg date (optional)") {
                    if let date = firstEggDate {
                        DatePicker(
                            "Date",
                            selection: Binding(get: { date }, set: { firstEggDate = $0 }),
                            displayedComponents: .date
                        )
                        Button("Clear date") { firstEggDate = nil }
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Set first egg date…") {
                            firstEggDate = Calendar.current.date(
                                from: DateComponents(year: year, month: 4, day: 1)
                            )
                        }
                        .foregroundStyle(AppColors.primary)
                    }
                }

                Section("Notes (optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("New Attempt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        let attempt = NestboxAttempt(
            species:       species.trimmingCharacters(in: .whitespacesAndNewlines),
            eggsLaid:      Int(eggsLaid),
            chicksFledged: Int(chicksFledged),
            firstEggDate:  firstEggDate,
            outcome:       outcome,
            notes:         notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        // Find or create the season for this box and year
        var updatedBox = box
        if let si = updatedBox.seasons.firstIndex(where: { $0.year == year }) {
            updatedBox.seasons[si].attempts.append(attempt)
        } else {
            var newSeason = NestboxSeason(year: year)
            newSeason.attempts.append(attempt)
            updatedBox.seasons.append(newSeason)
        }
        nestboxStore.update(updatedBox)
        dismiss()
    }
}

// MARK: - Add nestbox sheet

struct iOSAddNestboxSheet: View {
    @EnvironmentObject private var nestboxStore: NestboxStore
    @Environment(\.dismiss) private var dismiss

    @State private var name:    String      = ""
    @State private var boxType: NestboxType = .standard
    @State private var notes:   String      = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Box details") {
                    TextField("Name (e.g. Box A)", text: $name)
                    Picker("Type", selection: $boxType) {
                        ForEach(NestboxType.allCases) { t in
                            Label(t.label, systemImage: t.symbol).tag(t)
                        }
                    }
                }
                Section("Notes (optional)") {
                    TextField("Location, height, notes…", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("New Nestbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let box = Nestbox(
                            name:    name.trimmingCharacters(in: .whitespacesAndNewlines),
                            boxType: boxType,
                            notes:   notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        nestboxStore.add(box)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
#endif
