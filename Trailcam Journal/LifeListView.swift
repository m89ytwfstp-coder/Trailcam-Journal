//
//  LifeListView.swift
//  Trailcam Journal
//
//  A "lifer list" — every distinct species ever recorded as a finalized sighting,
//  with first-seen date, total count, and a thumbnail from one of its entries.
//

#if os(macOS)
import SwiftUI

struct LifeListView: View {

    @EnvironmentObject private var store: EntryStore

    // ── Sort / filter state ───────────────────────────────────────────────────
    enum SortOrder: String, CaseIterable, Identifiable {
        case alphabetical = "A–Z"
        case firstSeen    = "First seen"
        case mostSeen     = "Most sightings"
        case mostRecent   = "Most recent"
        var id: String { rawValue }
    }

    @State private var sortOrder: SortOrder = .alphabetical
    @State private var search: String = ""

    // ── Data model ────────────────────────────────────────────────────────────
    private struct LifeEntry: Identifiable {
        let species:      String
        let count:        Int
        let firstSeen:    Date
        let photoEntry:   TrailEntry?   // first entry with a photo (for thumbnail)
        let dates:        [Date]        // all sighting dates — for sparkline
        var id: String { species }
    }

    private var lifeList: [LifeEntry] {
        // Only finalized sightings with a species name
        let sightings = store.entries.filter {
            !$0.isDraft && $0.entryType == .sighting
        }

        var grouped: [String: [TrailEntry]] = [:]
        for entry in sightings {
            let s = (entry.species ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { continue }
            grouped[s, default: []].append(entry)
        }

        var list: [LifeEntry] = grouped.map { species, entries in
            let sorted      = entries.sorted { $0.date < $1.date }
            let withPhoto   = sorted.first { $0.photoThumbnailFilename != nil || $0.photoFilename != nil }
            return LifeEntry(
                species:    species,
                count:      entries.count,
                firstSeen:  sorted.first?.date ?? Date.distantPast,
                photoEntry: withPhoto,
                dates:      entries.map(\.date)
            )
        }

        // Search filter
        if !search.isEmpty {
            list = list.filter { $0.species.localizedCaseInsensitiveContains(search) }
        }

        // Sort
        switch sortOrder {
        case .alphabetical: list.sort { $0.species.localizedCompare($1.species) == .orderedAscending }
        case .firstSeen:    list.sort { $0.firstSeen < $1.firstSeen }
        case .mostSeen:     list.sort { $0.count > $1.count }
        case .mostRecent:   list.sort { $0.firstSeen > $1.firstSeen }
        }

        return list
    }

    // ── Derived stats for header bar ─────────────────────────────────────────
    private var allLifeEntries: [LifeEntry] {
        // Unsorted, unfiltered — for global stats
        let sightings = store.entries.filter { !$0.isDraft && $0.entryType == .sighting }
        var grouped: [String: [TrailEntry]] = [:]
        for entry in sightings {
            let s = (entry.species ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { continue }
            grouped[s, default: []].append(entry)
        }
        return grouped.map { species, entries in
            let sorted = entries.sorted { $0.date < $1.date }
            let withPhoto = sorted.first { $0.photoThumbnailFilename != nil || $0.photoFilename != nil }
            return LifeEntry(species: species, count: entries.count,
                             firstSeen: sorted.first?.date ?? Date.distantPast,
                             photoEntry: withPhoto,
                             dates: entries.map(\.date))
        }
    }

    private var totalSpecies: Int { allLifeEntries.count }
    private var totalSightings: Int { allLifeEntries.reduce(0) { $0 + $1.count } }
    private var earliestDate: Date? { allLifeEntries.map(\.firstSeen).min() }

    // ── Body ─────────────────────────────────────────────────────────────────
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if !allLifeEntries.isEmpty {
                statBar
                Divider()
            }
            content
        }
        .background(AppColors.background)
        .navigationTitle("Life List")
    }

    // ── Stat bar ─────────────────────────────────────────────────────────────
    private var statBar: some View {
        HStack(spacing: 0) {
            statPill(value: "\(totalSpecies)", label: "species")
            statDivider
            statPill(value: "\(totalSightings)", label: "total sightings")
            if let date = earliestDate {
                statDivider
                statPill(
                    value: date.formatted(.dateTime.month(.wide).year()),
                    label: "first sighting"
                )
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func statPill(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primary)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.trailing, 16)
    }

    private var statDivider: some View {
        Text("·")
            .font(.subheadline)
            .foregroundStyle(AppColors.textSecondary.opacity(0.5))
            .padding(.trailing, 16)
    }

    // ── Toolbar ───────────────────────────────────────────────────────────────
    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.callout)
                .foregroundStyle(AppColors.textSecondary)
            TextField("Search species…", text: $search)
                .textFieldStyle(.plain)

            Spacer()

            Text("\(lifeList.count) species")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            Picker("Sort", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { o in Text(o.rawValue).tag(o) }
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // ── Content ───────────────────────────────────────────────────────────────
    @ViewBuilder
    private var content: some View {
        if lifeList.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "pawprint")
                    .font(.system(size: 52))
                    .foregroundStyle(AppColors.primary.opacity(0.28))
                if search.isEmpty {
                    Text("Your life list is empty")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    Text("Every species you log will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                } else {
                    Text("No matches for \"\(search)\"")
                        .font(.title3)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(lifeList) { item in
                lifeRow(item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.visible)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .listStyle(.plain)
        }
    }

    // ── Row ───────────────────────────────────────────────────────────────────
    @ViewBuilder
    private func lifeRow(_ item: LifeEntry) -> some View {
        HStack(spacing: 12) {

            // Thumbnail
            Group {
                if let entry = item.photoEntry,
                   let img = MacImageStore.loadThumbnail(for: entry) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.primary.opacity(0.35))
                }
            }
            .frame(width: 52, height: 52)
            .background(AppColors.primary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            // Name + first-seen label
            VStack(alignment: .leading, spacing: 3) {
                Text(item.species)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppColors.primary.opacity(0.8))   // P6: link opacity

                Text("First seen " + item.firstSeen.formatted(.dateTime.day().month(.wide).year()))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            // Sparkline — 12-month sightings distribution
            SparklineView(dates: item.dates)
                .padding(.trailing, 8)

            // Sighting count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.count)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.primary)
                Text(item.count == 1 ? "sighting" : "sightings")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// ── Sparkline: 12-month sightings distribution bar chart ─────────────────────

private struct SparklineView: View {
    let dates: [Date]

    /// Count sightings per calendar month (Jan=0 … Dec=11).
    private var monthlyCounts: [Int] {
        let cal = Calendar.current
        var counts = [Int](repeating: 0, count: 12)
        for d in dates {
            let m = cal.component(.month, from: d) - 1
            counts[m] += 1
        }
        return counts
    }

    var body: some View {
        let counts   = monthlyCounts
        let maxCount = max(1, counts.max() ?? 1)

        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<12, id: \.self) { month in
                let count  = counts[month]
                let height = count == 0
                    ? 1.5
                    : max(2.0, 10.0 * Double(count) / Double(maxCount))

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(count == 0
                          ? AppColors.primary.opacity(0.12)
                          : AppColors.primary.opacity(0.60))
                    .frame(width: 2, height: height)
            }
        }
        .frame(width: 30, height: 12, alignment: .bottom)
    }
}
#endif
