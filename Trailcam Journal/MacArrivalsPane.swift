//
//  MacArrivalsPane.swift
//  Trailcam Journal
//
//  Spring-arrivals phenology view — year × species comparison table.
//  Sidebar item: .arrivals
//

#if os(macOS)
import SwiftUI

struct MacArrivalsPane: View {

    @EnvironmentObject var arrivalStore: ArrivalStore

    // MARK: - State

    @State private var showQuickEntry    = false
    @State private var showBulkEntry     = false
    @State private var showEditWatchlist = false
    @State private var bulkYear:  Int    = Calendar.current.component(.year, from: Date())
    @State private var selectedSpecies: String? = nil

    // MARK: - Derived data

    /// Years to show as columns — current year + up to 4 previous.
    private var displayYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let dataYears   = arrivalStore.years
        var years       = Array(Set([currentYear] + dataYears)).sorted(by: >)
        return Array(years.prefix(6))
    }

    /// Column width for each year column.
    private let yearColWidth: CGFloat = 88

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider()
            if arrivalStore.watchlist.isEmpty {
                emptyState
            } else {
                tableBody
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Spring Arrivals")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showQuickEntry) {
            ArrivalQuickEntrySheet(targetYear: Calendar.current.component(.year, from: Date()))
                .environmentObject(arrivalStore)
        }
        .sheet(isPresented: $showBulkEntry) {
            ArrivalQuickEntrySheet(targetYear: bulkYear, isHistorical: true)
                .environmentObject(arrivalStore)
        }
        .sheet(item: $selectedSpecies) { species in
            ArrivalSpeciesDetailView(species: species)
                .environmentObject(arrivalStore)
                .frame(minWidth: 560, minHeight: 480)
        }
        .sheet(isPresented: $showEditWatchlist) {
            ArrivalWatchlistEditor()
                .environmentObject(arrivalStore)
        }
    }

    // MARK: - Header row (year labels)

    private var tableHeader: some View {
        HStack(spacing: 0) {
            // Species column header
            Text("Species")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
                .padding(.leading, 16)

            Divider().frame(height: 28)

            // Year columns
            ForEach(displayYears, id: \.self) { year in
                Text(String(year))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        year == Calendar.current.component(.year, from: Date())
                            ? AppColors.primary
                            : .secondary
                    )
                    .frame(width: yearColWidth)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 32)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Table body (species rows)

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    private var hasCurrentYearData: Bool {
        arrivalStore.records.contains { $0.year == currentYear }
    }

    private var tableBody: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Empty-year banner when current year has no records at all
                if !hasCurrentYearData {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.body)
                            .foregroundStyle(AppColors.primary.opacity(0.7))
                        Text("No arrivals logged for \(String(currentYear)) yet. Tap + Log Arrival to add the first one.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppColors.primary.opacity(0.04))
                }

                ForEach(arrivalStore.watchlist, id: \.self) { species in
                    ArrivalTableRow(
                        species: species,
                        years: displayYears,
                        yearColWidth: yearColWidth,
                        arrivalStore: arrivalStore,
                        onTapSpecies: { selectedSpecies = species }
                    )
                    Divider().padding(.leading, 16)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bird")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No species on your watchlist")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button {
                showEditWatchlist = true
            } label: {
                Label("Edit Watchlist", systemImage: "list.bullet.indent")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showQuickEntry = true
            } label: {
                Label("Log Arrival", systemImage: "plus")
            }
            .help("Log a new spring arrival for this year")
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                ForEach(
                    (0..<6).map { Calendar.current.component(.year, from: Date()) - $0 },
                    id: \.self
                ) { y in
                    Button(String(y)) {
                        bulkYear      = y
                        showBulkEntry = true
                    }
                }
            } label: {
                Label("Historical Entry", systemImage: "clock.arrow.circlepath")
            }
            .help("Log arrivals for a past year")
        }

        ToolbarItem(placement: .automatic) {
            Button {
                showEditWatchlist = true
            } label: {
                Label("Edit Watchlist", systemImage: "list.bullet.indent")
            }
            .help("Add or remove species from your watchlist")
        }
    }
}

// MARK: - Single species row

private struct ArrivalTableRow: View {

    let species:      String
    let years:        [Int]
    let yearColWidth: CGFloat
    let arrivalStore: ArrivalStore
    let onTapSpecies: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Species name
            Button(action: onTapSpecies) {
                Text(species)
                    .font(.body)
                    .foregroundStyle(AppColors.primary)
                    .lineLimit(1)
                    .frame(width: 160, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)

            Divider().frame(height: 36)

            // Year cells
            ForEach(years, id: \.self) { year in
                ArrivalCell(record: arrivalStore.arrival(species: species, year: year))
                    .frame(width: yearColWidth)
            }
        }
        .frame(height: 38)
        .contentShape(Rectangle())
    }
}

// MARK: - Individual year cell

private struct ArrivalCell: View {

    let record: ArrivalRecord?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    var body: some View {
        if let rec = record {
            VStack(spacing: 1) {
                Text(Self.dayFormatter.string(from: rec.date))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(rec.approximate ? .secondary : .primary)
                Image(systemName: rec.how.symbol)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        } else {
            Text("–")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
    }
}

// Needed for .sheet(item:) — String must be Identifiable
extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - Watchlist editor sheet

struct ArrivalWatchlistEditor: View {

    @EnvironmentObject var arrivalStore: ArrivalStore
    @Environment(\.dismiss) private var dismiss

    @State private var newSpecies: String = ""
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Watchlist")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // Add new species row
            HStack(spacing: 8) {
                TextField("Add species…", text: $newSpecies)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitAdd() }
                Button("Add") { commitAdd() }
                    .buttonStyle(.bordered)
                    .disabled(newSpecies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // List
            if arrivalStore.watchlist.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bird")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("Watchlist is empty")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(arrivalStore.watchlist, id: \.self) { species in
                        HStack {
                            Text(species)
                            Spacer()
                            let count = arrivalStore.records(for: species).count
                            if count > 0 {
                                Text("\(count) record\(count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Button {
                                arrivalStore.removeFromWatchlist(species)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Remove \(species) from watchlist")
                        }
                    }
                    .onMove { from, to in
                        arrivalStore.watchlist.move(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer — reset button
            HStack {
                Button("Reset to defaults…") {
                    confirmReset = true
                }
                .foregroundStyle(.secondary)
                .font(.subheadline)
                Spacer()
                Text("\(arrivalStore.watchlist.count) species")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 360, height: 480)
        .confirmationDialog(
            "Reset to default watchlist?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                arrivalStore.resetWatchlistToDefault()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace your current watchlist with the 24 default Norwegian spring species.")
        }
    }

    private func commitAdd() {
        let trimmed = newSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        arrivalStore.addToWatchlist(trimmed)
        newSpecies = ""
    }
}
#endif
