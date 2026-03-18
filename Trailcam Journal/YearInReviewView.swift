//
//  YearInReviewView.swift
//  Trailcam Journal
//
//  Annual summary: metric tiles, monthly activity chart, top species/cameras,
//  and a spotlight on the first entry of the selected year.
//

#if os(macOS)
import SwiftUI
import Charts

struct YearInReviewView: View {

    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore

    // ── Year selection ────────────────────────────────────────────────────────
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var availableYears: [Int] {
        let cal   = Calendar.current
        let years = store.entries
            .filter { !$0.isDraft }
            .map { cal.component(.year, from: $0.date) }
        let sorted = Array(Set(years)).sorted(by: >)
        return sorted.isEmpty ? [cal.component(.year, from: Date())] : sorted
    }

    // ── Derived data ──────────────────────────────────────────────────────────
    private var yearEntries: [TrailEntry] {
        let cal = Calendar.current
        return store.entries.filter {
            !$0.isDraft && cal.component(.year, from: $0.date) == selectedYear
        }
    }

    private var metrics: StatsMetric { StatsHelpers.metrics(from: yearEntries) }

    private var topSpecies: [RankedCount] { StatsHelpers.topSpecies(entries: yearEntries, limit: 5) }
    private var topCameras: [RankedCount] { StatsHelpers.topCameras(entries: yearEntries, limit: 5) }

    private var monthlyPoints: [StatsBarPoint] {
        StatsHelpers.monthlyCounts(year: selectedYear, entries: yearEntries, calendar: .current)
    }

    private var bestMonth: (name: String, count: Int)? {
        guard let best = monthlyPoints.max(by: { $0.count < $1.count }),
              best.count > 0 else { return nil }
        let df = DateFormatter()
        df.locale   = .current
        df.dateFormat = "MMMM"
        return (df.string(from: best.date), best.count)
    }

    private var firstEntry: TrailEntry? {
        yearEntries.min(by: { $0.date < $1.date })
    }

    // ── Body ──────────────────────────────────────────────────────────────────
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header row
                HStack(spacing: 12) {
                    Text("Year in Review")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppColors.primary)

                    Spacer()

                    Picker("Year", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { y in
                            Text(String(y)).tag(y)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                if yearEntries.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 52))
                            .foregroundStyle(AppColors.primary.opacity(0.28))
                        Text("No entries recorded in \(String(selectedYear)).")
                            .font(.title3)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {

                    // ── Metric tiles ──────────────────────────────────────────
                    HStack(spacing: 12) {
                        metricTile("Entries",     value: "\(metrics.entries)",        icon: "photo.on.rectangle")
                        metricTile("Species",     value: "\(metrics.uniqueSpecies)",  icon: "pawprint.fill")
                        metricTile("Active days", value: "\(metrics.activeDays)",     icon: "calendar.badge.clock")
                        if let bm = bestMonth {
                            metricTile("Best month", value: bm.name, icon: "star.fill",
                                       sub: "\(bm.count) entries")
                        } else {
                            metricTile("Cameras",  value: "\(metrics.uniqueCameras)", icon: "camera")
                        }
                    }

                    // ── Monthly chart ─────────────────────────────────────────
                    sectionCard("Monthly Activity") {
                        Chart(monthlyPoints) { p in
                            BarMark(
                                x: .value("Month",   p.date, unit: .month),
                                y: .value("Entries", p.count)
                            )
                            .cornerRadius(4)
                            .foregroundStyle(AppColors.primary.opacity(0.75))
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) { v in
                                AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.06))
                                AxisValueLabel {
                                    if let d = v.as(Date.self) {
                                        Text(d, format: .dateTime.month(.abbreviated))
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                                AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.06))
                                AxisValueLabel()
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .frame(height: 180)
                    }

                    // ── Rankings row ──────────────────────────────────────────
                    HStack(alignment: .top, spacing: 16) {
                        sectionCard("Top Species") {
                            rankingList(items: topSpecies, icon: "pawprint.fill")
                        }
                        sectionCard("Top Cameras") {
                            rankingList(items: topCameras, icon: "camera")
                        }
                    }

                    // ── First entry spotlight ─────────────────────────────────
                    if let first = firstEntry {
                        sectionCard("First Entry of \(String(selectedYear))") {
                            HStack(spacing: 14) {
                                if let img = MacImageStore.loadThumbnail(for: first) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(first.displayTitle)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(AppColors.primary)
                                    Text(first.date.formatted(.dateTime.day().month(.wide).year()))
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textSecondary)
                                    // P8: location name below date
                                    let locationLabel = EntryFormatting.locationLabel(
                                        for: first,
                                        savedLocations: savedLocationStore.locations
                                    )
                                    if !locationLabel.isEmpty {
                                        Label(locationLabel, systemImage: "location.fill")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                    if !first.notes.isEmpty {
                                        Text(first.notes)
                                            .font(.callout)
                                            .foregroundStyle(AppColors.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 16)
        }
        .background(AppColors.background)
        .navigationTitle("")
        .onAppear {
            if let first = availableYears.first { selectedYear = first }
        }
    }

    // ── Building blocks ───────────────────────────────────────────────────────

    private func metricTile(_ title: String, value: String, icon: String, sub: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.primary.opacity(0.65))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let sub {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(cardBackground)
    }

    @ViewBuilder
    private func sectionCard<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.primary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    @ViewBuilder
    private func rankingList(items: [RankedCount], icon: String) -> some View {
        if items.isEmpty {
            Text("No data")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 60)
        } else {
            let maxCount = items.map(\.count).max() ?? 1
            VStack(spacing: 8) {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.primary.opacity(0.55))
                            .frame(width: 14)
                        Text(item.name)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.primary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        GeometryReader { geo in
                            Capsule()
                                .fill(AppColors.primary.opacity(0.10))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(AppColors.primary.opacity(0.55))
                                        .frame(width: max(4, geo.size.width
                                                         * CGFloat(item.count)
                                                         / CGFloat(maxCount)))
                                }
                        }
                        .frame(width: 56, height: 6)
                        Text("\(item.count)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(minWidth: 20, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppColors.primary.opacity(0.07))
            )
    }
}
#endif
