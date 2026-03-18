
//
//  MacStatsPane.swift
//  Trailcam Journal
//
//  macOS-native statistics pane.  Takes full advantage of the wide content area:
//    • Metrics row   – 4 tiles spanning full width
//    • Trend chart   – full width, with Entries / Unique species toggle
//    • Bottom row    – Time of day (left) + Species / Cameras ranking (right)
//  All data crunching delegated to the shared StatsHelpers + StatsModels.
//

#if os(macOS)
import SwiftUI
import Charts
import CoreLocation

struct MacStatsPane: View {

    @EnvironmentObject private var store:    EntryStore

    // ── Filter state ─────────────────────────────────────────────────────────
    @State private var timeframe:      StatsTimeframe = .last30
    @State private var selectedCamera: String?        = nil

    // ── Card toggle state ────────────────────────────────────────────────────
    @State private var trendMode:     TrendMode     = .entries
    @State private var timeOfDayMode: TimeOfDayMode = .histogram24h
    @State private var rankingTab:    RankingTab    = .species

    // ── Nested types ─────────────────────────────────────────────────────────
    enum RankingTab: String, CaseIterable { case species = "Species"; case cameras = "Cameras" }

    // ── Derived data ─────────────────────────────────────────────────────────
    private var filtered: [TrailEntry] {
        StatsHelpers.filterFinalEntries(store.entries, timeframe: timeframe, selectedCamera: selectedCamera)
    }
    private var metrics: StatsMetric { StatsHelpers.metrics(from: filtered) }
    private var availableCameras: [String] {
        Array(Set(store.entries.filter { !$0.isDraft }
            .compactMap { $0.camera?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        )).sorted()
    }

    // ── Body ─────────────────────────────────────────────────────────────────
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                filterBar

                metricsRow

                trendCard

                HStack(alignment: .top, spacing: 18) {
                    timeOfDayCard
                    rankingCard
                }
            }
            .padding(20)
            .padding(.bottom, 16)
        }
        .background(AppColors.background)
        .navigationTitle("Stats")
    }

    // ── Filter bar ────────────────────────────────────────────────────────────
    private var filterBar: some View {
        HStack(spacing: 10) {
            Picker("Timeframe", selection: $timeframe) {
                ForEach(StatsTimeframe.allCases) { tf in Text(tf.rawValue).tag(tf) }
            }
            .pickerStyle(.menu)
            .fixedSize()

            Menu {
                Button("All cameras") { selectedCamera = nil }
                if !availableCameras.isEmpty {
                    Divider()
                    ForEach(availableCameras, id: \.self) { cam in
                        Button(cam) { selectedCamera = cam }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "camera")
                        .font(.caption)
                    Text(selectedCamera ?? "All cameras")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .opacity(0.6)
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.primary.opacity(0.08))
                )
            }
            .fixedSize()

            if selectedCamera != nil {
                Button { selectedCamera = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            Spacer()

            // Entry count badge
            Text("\(metrics.entries) \(metrics.entries == 1 ? "entry" : "entries")")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // ── Metrics row ───────────────────────────────────────────────────────────
    private var metricsRow: some View {
        HStack(spacing: 12) {
            metricTile("Entries",     value: "\(metrics.entries)",        icon: "photo.on.rectangle")
            metricTile("Active days", value: "\(metrics.activeDays)",     icon: "calendar.badge.clock")
            metricTile("Species",     value: "\(metrics.uniqueSpecies)",  icon: "pawprint.fill")
            metricTile("Locations",   value: "\(metrics.uniqueLocations)",icon: "mappin.and.ellipse")
        }
    }

    private func metricTile(_ title: String, value: String, icon: String) -> some View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(cardBackground)
    }

    // ── Trend card (full width) ───────────────────────────────────────────────
    private var trendCard: some View {
        let points  = trendPoints()
        let insight = trendInsight(for: points)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                cardTitle("Trend")
                Spacer()
                Picker("Trend", selection: $trendMode) {
                    ForEach(TrendMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            if points.isEmpty {
                emptyState("No data in this timeframe")
            } else {
                Chart(points) { p in
                    AreaMark(
                        x: .value("Date",  p.date),
                        y: .value("Count", p.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary.opacity(0.28), AppColors.primary.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Date",  p.date),
                        y: .value("Count", p.count)
                    )
                    .foregroundStyle(AppColors.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                        AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.06))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(preset: .aligned, position: .bottom, values: .automatic(desiredCount: 6)) { v in
                        AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.06))
                        AxisValueLabel {
                            if let date = v.as(Date.self) {
                                Text(trendXAxisLabel(date: date, timeframe: timeframe))
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 200)

                if !insight.isEmpty {
                    insightPill(insight, icon: "sparkles")
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // ── Time of day card (bottom-left) ────────────────────────────────────────
    @ViewBuilder
    private var timeOfDayCard: some View {
        let histogram = StatsHelpers.hourHistogram(entries: filtered)
        let dn        = StatsHelpers.dayNightCounts(entries: filtered)
        let peakHour  = histogram.enumerated().max(by: { $0.element < $1.element })?.offset

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                cardTitle("Time of day")
                Spacer()
                Picker("Mode", selection: $timeOfDayMode) {
                    ForEach(TimeOfDayMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            switch timeOfDayMode {

            case .histogram24h:
                if histogram.reduce(0, +) == 0 {
                    emptyState("No data in this timeframe")
                } else {
                    Chart(Array(histogram.enumerated()), id: \.offset) { item in
                        BarMark(
                            x: .value("Hour",  item.offset),
                            y: .value("Count", item.element)
                        )
                        .cornerRadius(3)
                        .foregroundStyle(AppColors.primary.opacity(0.78))
                    }
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: [0, 6, 12, 18, 23]) { v in
                            AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.06))
                            AxisValueLabel {
                                if let h = v.as(Int.self) {
                                    Text("\(h):00")
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                        }
                    }
                    .frame(height: 160)

                    if let peakHour {
                        insightPill("Most active: ~\(peakHour):00", icon: "clock")
                    }
                }

            case .dayNight:
                let total = dn.day + dn.night
                if total == 0 {
                    emptyState("No data in this timeframe")
                } else {
                    let pts: [RankedCount] = [
                        .init(name: "Day",   count: dn.day),
                        .init(name: "Night", count: dn.night)
                    ]
                    Chart(pts) { p in
                        BarMark(
                            x: .value("Part",  p.name),
                            y: .value("Count", p.count)
                        )
                        .cornerRadius(6)
                        .foregroundStyle(by: .value("Part", p.name))
                    }
                    .chartForegroundStyleScale([
                        "Day":   AppColors.primary.opacity(0.85),
                        "Night": AppColors.primary.opacity(0.42)
                    ])
                    .chartYAxis(.hidden)
                    .frame(height: 160)

                    insightPill("Day: \(dn.day)  ·  Night: \(dn.night)", icon: "moon.stars")
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // ── Species / cameras ranking card (bottom-right) ─────────────────────────
    @ViewBuilder
    private var rankingCard: some View {
        let topSpecies = StatsHelpers.topSpecies(entries: filtered, limit: 10)
        let topCameras = StatsHelpers.topCameras(entries: filtered, limit: 10)
        let items      = rankingTab == .species ? topSpecies : topCameras
        let icon       = rankingTab == .species ? "pawprint.fill" : "camera"
        let maxCount   = items.map(\.count).max() ?? 1

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                cardTitle(rankingTab.rawValue)
                Spacer()
                Picker("Ranking", selection: $rankingTab) {
                    ForEach(RankingTab.allCases, id: \.rawValue) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            if items.isEmpty {
                emptyState("No data in this timeframe")
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            Image(systemName: icon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.primary.opacity(0.60))
                                .frame(width: 16)

                            Text(item.name)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.primary)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            // Inline progress bar
                            GeometryReader { geo in
                                Capsule()
                                    .fill(AppColors.primary.opacity(0.12))
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(AppColors.primary.opacity(0.60))
                                            .frame(width: max(4, geo.size.width
                                                             * CGFloat(item.count)
                                                             / CGFloat(maxCount)))
                                    }
                            }
                            .frame(width: 64, height: 6)

                            Text("\(item.count)")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(minWidth: 24, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // ── Shared building blocks ────────────────────────────────────────────────
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppColors.primary.opacity(0.07))
            )
    }

    private func cardTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(AppColors.primary)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    private func insightPill(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption.weight(.semibold))
            Text(text).font(.caption)
        }
        .foregroundStyle(AppColors.primary.opacity(0.85))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(AppColors.primary.opacity(0.10)))
    }

    // ── Trend data helpers ────────────────────────────────────────────────────
    private func trendPoints() -> [StatsBarPoint] {
        let cal = Calendar.current
        let now = Date()
        switch timeframe {
        case .last7:
            return trendMode == .entries
                ? StatsHelpers.dailyCounts(lastDays: 7,  entries: filtered, now: now, calendar: cal)
                : StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 7, entries: filtered, now: now, calendar: cal)
        case .last30:
            return trendMode == .entries
                ? StatsHelpers.dailyCounts(lastDays: 30, entries: filtered, now: now, calendar: cal)
                : StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 30, entries: filtered, now: now, calendar: cal)
        case .thisYear:
            let y = cal.component(.year, from: now)
            return trendMode == .entries
                ? StatsHelpers.monthlyCounts(year: y, entries: filtered, calendar: cal)
                : StatsHelpers.uniqueSpeciesMonthlyCounts(year: y, entries: filtered, calendar: cal)
        case .allTime:
            return StatsHelpers.weeklyCounts(lastWeeks: 16, entries: filtered, now: now, calendar: cal)
        }
    }

    private func trendInsight(for points: [StatsBarPoint]) -> String {
        guard let best = points.max(by: { $0.count < $1.count }), best.count > 0 else { return "" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = (timeframe == .thisYear) ? "MMM" : "MMM d"
        return "Peak: \(best.count) on \(df.string(from: best.date))"
    }
}
#endif
