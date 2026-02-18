import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var store: EntryStore

    // Home controls
    @State private var timeframe: StatsTimeframe = .last30
    @State private var selectedCamera: String? = nil

    // Card toggles
    @State private var trendMode: TrendMode = .entries
    @State private var timeOfDayMode: TimeOfDayMode = .histogram24h

    private var finalEntriesFiltered: [TrailEntry] {
        StatsHelpers.filterFinalEntries(
            store.entries,
            timeframe: timeframe,
            selectedCamera: selectedCamera
        )
    }

    private var metrics: StatsMetric {
        StatsHelpers.metrics(from: finalEntriesFiltered)
    }

    private var availableCameras: [String] {
        let names = store.entries
            .filter { !$0.isDraft }
            .compactMap { $0.camera?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(names)).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AppHeader(title: "Stats", subtitle: "Clean insights — tap cards for details")

                    controlsRow

                    overviewCard
                    trendCard
                    timeOfDayCard
                    topSpeciesCard
                    camerasCard
                }
                .padding(.top, 2)
                .padding(.bottom, 20)
            }
            .appScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Controls

private extension StatsView {
    var controlsRow: some View {
        HStack(spacing: 10) {

            Menu {
                Picker("Timeframe", selection: $timeframe) {
                    ForEach(StatsTimeframe.allCases) { tf in
                        Text(tf.rawValue).tag(tf)
                    }
                }
            } label: {
                pillControlLabel(text: timeframe.rawValue, systemImage: "calendar")
            }

            Menu {
                Button("All cameras") { selectedCamera = nil }

                if !availableCameras.isEmpty {
                    Divider()
                }

                ForEach(availableCameras, id: \.self) { cam in
                    Button(cam) { selectedCamera = cam }
                }
            } label: {
                pillControlLabel(text: selectedCamera ?? "All cameras", systemImage: "camera")
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    func pillControlLabel(text: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .opacity(0.7)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AppColors.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.primary.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.primary.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

// MARK: - Cards

private extension StatsView {

    var overviewCard: some View {
        StatsCard(title: "Overview") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    metricCell(title: "Entries", value: "\(metrics.entries)", systemImage: "photo.on.rectangle")
                    metricCell(title: "Active days", value: "\(metrics.activeDays)", systemImage: "calendar.badge.clock")
                }
                HStack(spacing: 12) {
                    metricCell(title: "Unique species", value: "\(metrics.uniqueSpecies)", systemImage: "pawprint.fill")
                    metricCell(title: "Locations", value: "\(metrics.uniqueLocations)", systemImage: "mappin.and.ellipse")
                }
            }
        }
    }

    @ViewBuilder
    func metricCell(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.primary.opacity(0.85))

                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.80))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.primary.opacity(0.10), lineWidth: 1)
                )
        )
    }

    var trendCard: some View {
        let points = trendPoints()
        let insight = trendInsight(for: points)

        return NavigationLink {
            TrendDetailView(entries: finalEntriesFiltered, timeframe: timeframe)
        } label: {
            StatsCard(title: "Trend") {
                VStack(alignment: .leading, spacing: 10) {

                    segmentedPickerCapsule {
                        Picker("Trend", selection: $trendMode) {
                            ForEach(TrendMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if points.isEmpty {
                        emptyState(text: "No data in this timeframe")
                    } else {
                        premiumChartContainer {
                            Chart(points) { p in
                                AreaMark(
                                    x: .value("Date", p.date),
                                    y: .value("Count", p.count)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            AppColors.primary.opacity(0.35),
                                            AppColors.primary.opacity(0.05)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                LineMark(
                                    x: .value("Date", p.date),
                                    y: .value("Count", p.count)
                                )
                                .foregroundStyle(AppColors.primary)
                                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))

                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            }
                            .chartYAxis(.hidden)
                            .chartXAxis {
                                AxisMarks(preset: .aligned, position: .bottom, values: .automatic(desiredCount: 4)) { value in
                                    AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                    AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                    AxisValueLabel() {
                                        if let date = value.as(Date.self) {
                                            Text(trendXAxisLabel(date: date, timeframe: timeframe))

                                                .font(.caption2)
                                                .foregroundStyle(AppColors.textSecondary)
                                        }
                                    }
                                }
                            }
                            .frame(height: 150)
                            .padding(.bottom, 2)

                        }

                        if !insight.isEmpty {
                            pillInsight(text: insight, systemImage: "sparkles")
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    var timeOfDayCard: some View {
        let histogram = StatsHelpers.hourHistogram(entries: finalEntriesFiltered)
        let dn = StatsHelpers.dayNightCounts(entries: finalEntriesFiltered)
        let peakHour = histogram.enumerated().max(by: { $0.element < $1.element })?.offset

        return NavigationLink {
            TimeOfDayDetailView(entries: finalEntriesFiltered)
        } label: {
            StatsCard(title: "Time of day") {
                VStack(alignment: .leading, spacing: 10) {

                    segmentedPickerCapsule {
                        Picker("Mode", selection: $timeOfDayMode) {
                            ForEach(TimeOfDayMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    switch timeOfDayMode {
                    case .histogram24h:
                        if histogram.reduce(0, +) == 0 {
                            emptyState(text: "No data in this timeframe")
                        } else {
                            premiumChartContainer {
                                Chart(Array(histogram.enumerated()), id: \.offset) { item in
                                    BarMark(
                                        x: .value("Hour", item.offset),
                                        y: .value("Count", item.element)
                                    )
                                    .cornerRadius(3)
                                    .foregroundStyle(AppColors.primary.opacity(0.85))

                                }
                                .chartYAxis(.hidden)
                                .chartXAxis {
                                    AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                                        AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                        AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                        AxisValueLabel() {
                                            if let h = value.as(Int.self) {
                                                Text("\(h)")
                                                    .font(.caption2)
                                                    .foregroundStyle(AppColors.textSecondary)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 150)
                                .padding(.bottom, 2)

                            }

                            if let peakHour {
                                pillInsight(text: "Most active: ~\(peakHour):00", systemImage: "clock")
                            }
                        }

                    case .dayNight:
                        let total = dn.day + dn.night
                        if total == 0 {
                            emptyState(text: "No data in this timeframe")
                        } else {
                            let points: [RankedCount] = [
                                .init(name: "Day", count: dn.day),
                                .init(name: "Night", count: dn.night)
                            ]

                            premiumChartContainer {
                                Chart(points) { p in
                                    BarMark(
                                        x: .value("Part", p.name),
                                        y: .value("Count", p.count)
                                    )
                                    .cornerRadius(6)
                                    .foregroundStyle(by: .value("Part", p.name))
                                }
                                .chartForegroundStyleScale([
                                    "Day": AppColors.primary.opacity(0.85),
                                    "Night": AppColors.primary.opacity(0.55)
                                ])
                                .chartYAxis(.hidden)
                                .chartXAxis {
                                    AxisMarks(position: .bottom) { value in
                                        AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                        AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                        AxisValueLabel()
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                                .frame(height: 150)
                                .padding(.bottom, 2)


                            }

                            pillInsight(text: "Day: \(dn.day) • Night: \(dn.night)", systemImage: "moon.stars")
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    var topSpeciesCard: some View {
        let top = StatsHelpers.topSpecies(entries: finalEntriesFiltered, limit: 5)

        return NavigationLink {
            SpeciesRankingView(entries: finalEntriesFiltered)
        } label: {
            StatsCard(title: "Top species") {
                VStack(alignment: .leading, spacing: 10) {
                    if top.isEmpty {
                        emptyState(text: "No species yet in this timeframe")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(top) { item in
                                premiumRow(
                                    title: item.name,
                                    trailing: "\(item.count)",
                                    systemImage: "pawprint.fill"
                                )

                                if item.id != top.last?.id {
                                    Divider().opacity(0.25)
                                }
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    var camerasCard: some View {
        let top = StatsHelpers.topCameras(entries: finalEntriesFiltered, limit: 3)
        let total = finalEntriesFiltered
            .filter { !($0.camera ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count

        return NavigationLink {
            CameraRankingView(entries: finalEntriesFiltered)
        } label: {
            StatsCard(title: "Cameras") {
                VStack(alignment: .leading, spacing: 10) {
                    if top.isEmpty {
                        emptyState(text: "No camera names found")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(top) { item in
                                let pct = total == 0 ? 0 : Int((Double(item.count) / Double(total)) * 100)

                                premiumRow(
                                    title: item.name,
                                    trailing: "\(pct)%",
                                    systemImage: "camera"
                                )

                                if item.id != top.last?.id {
                                    Divider().opacity(0.25)
                                }
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Premium building blocks

    func segmentedPickerCapsule<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.70))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColors.primary.opacity(0.08), lineWidth: 1)
                    )
            )
    }

    func premiumChartContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColors.primary.opacity(0.08), lineWidth: 1)
                    )
            )
    }

    func pillInsight(text: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(AppColors.primary.opacity(0.95))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(AppColors.primary.opacity(0.10))
        )
    }

    func premiumRow(title: String, trailing: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primary.opacity(0.80))
                .frame(width: 22)

            Text(title)
                .foregroundStyle(AppColors.primary)
                .lineLimit(1)

            Spacer()

            Text(trailing)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    func emptyState(text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(AppColors.textSecondary)
            .padding(.vertical, 10)
    }
}

// MARK: - Trend helpers

private extension StatsView {
    func trendPoints() -> [StatsBarPoint] {
        let cal = Calendar.current
        let now = Date()

        switch timeframe {
        case .last7:
            return trendMode == .entries
            ? StatsHelpers.dailyCounts(lastDays: 7, entries: finalEntriesFiltered, now: now, calendar: cal)
            : StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 7, entries: finalEntriesFiltered, now: now, calendar: cal)

        case .last30:
            return trendMode == .entries
            ? StatsHelpers.dailyCounts(lastDays: 30, entries: finalEntriesFiltered, now: now, calendar: cal)
            : StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 30, entries: finalEntriesFiltered, now: now, calendar: cal)

        case .thisYear:
            let y = cal.component(.year, from: now)
            return trendMode == .entries
            ? StatsHelpers.monthlyCounts(year: y, entries: finalEntriesFiltered, calendar: cal)
            : StatsHelpers.uniqueSpeciesMonthlyCounts(year: y, entries: finalEntriesFiltered, calendar: cal)

        case .allTime:
            // Keep home screen compact: show last 12 weeks in all-time mode
            return StatsHelpers.weeklyCounts(lastWeeks: 12, entries: finalEntriesFiltered, now: now, calendar: cal)
        }
    }

    func trendInsight(for points: [StatsBarPoint]) -> String {
        guard let best = points.max(by: { $0.count < $1.count }), best.count > 0 else {
            return ""
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = (timeframe == .thisYear) ? "MMM" : "MMM d"
        return "Peak: \(best.count) on \(df.string(from: best.date))"
    }
}

func trendXAxisLabel(date: Date, timeframe: StatsTimeframe) -> String {
    let df = DateFormatter()
    df.locale = Locale.current

    switch timeframe {
    case .thisYear:
        df.dateFormat = "MMM"
    case .allTime:
        df.dateFormat = "MMM d"
    case .last7:
        df.dateFormat = "EEE"
    case .last30:
        df.dateFormat = "d MMM"
    }

    return df.string(from: date)
}



// StatsCard is in StatsCard.swift (reusable)
