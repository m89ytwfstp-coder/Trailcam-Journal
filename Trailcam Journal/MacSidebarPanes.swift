import SwiftUI
import AppKit
import Charts

#if os(macOS)
struct MacMapPane: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore

    private var geotaggedEntries: [TrailEntry] {
        store.entries
            .filter { !$0.isDraft && $0.latitude != nil && $0.longitude != nil }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppHeader(
                title: "Map",
                subtitle: "\(geotaggedEntries.count) finalized entries with coordinates"
            )

            if geotaggedEntries.isEmpty && savedLocationStore.locations.isEmpty {
                ContentUnavailableView(
                    "No mapped items",
                    systemImage: "map",
                    description: Text("Add locations during import/review and they will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !savedLocationStore.locations.isEmpty {
                        Section("Saved Locations") {
                            ForEach(savedLocationStore.locations) { location in
                                locationRow(
                                    title: location.name,
                                    subtitle: String(format: "%.4f, %.4f", location.latitude, location.longitude),
                                    latitude: location.latitude,
                                    longitude: location.longitude
                                )
                            }
                        }
                    }

                    if !geotaggedEntries.isEmpty {
                        Section("Recent Entry Locations") {
                            ForEach(geotaggedEntries) { entry in
                                if let lat = entry.latitude, let lon = entry.longitude {
                                    locationRow(
                                        title: entry.species ?? "Unknown species",
                                        subtitle: entry.date.formatted(date: .abbreviated, time: .shortened),
                                        latitude: lat,
                                        longitude: lon
                                    )
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appScreenBackground()
    }

    private func locationRow(title: String, subtitle: String, latitude: Double, longitude: Double) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                Text(String(format: "%.4f, %.4f", latitude, longitude))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Button("Open in Maps") {
                openInMaps(latitude: latitude, longitude: longitude)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private func openInMaps(latitude: Double, longitude: Double) {
        let urlString = "https://maps.apple.com/?ll=\(latitude),\(longitude)"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

struct MacStatsPane: View {
    @EnvironmentObject private var store: EntryStore

    @State private var timeframe: StatsTimeframe = .last30
    @State private var selectedCamera: String = ""
    @State private var trendMode: TrendMode = .entries
    @State private var timeOfDayMode: TimeOfDayMode = .histogram24h

    private var cameraOptions: [String] {
        let names = Set(
            store.entries.compactMap { entry in
                let trimmed = (entry.camera ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        )
        return Array(names).sorted()
    }

    private var filteredEntries: [TrailEntry] {
        StatsHelpers.filterFinalEntries(
            store.entries,
            timeframe: timeframe,
            selectedCamera: selectedCamera.isEmpty ? nil : selectedCamera
        )
    }

    private var metric: StatsMetric {
        StatsHelpers.metrics(from: filteredEntries)
    }

    private var topSpecies: [RankedCount] {
        StatsHelpers.topSpecies(entries: filteredEntries, limit: 5)
    }

    private var topCameras: [RankedCount] {
        StatsHelpers.topCameras(entries: filteredEntries, limit: 5)
    }

    private var trendDataPoints: [StatsBarPoint] {
        let calendar = Calendar.current
        let now = Date()

        switch timeframe {
        case .last7:
            return trendMode == .entries
            ? StatsHelpers.dailyCounts(lastDays: 7, entries: filteredEntries, now: now, calendar: calendar)
            : StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 7, entries: filteredEntries, now: now, calendar: calendar)
        case .last30:
            return trendMode == .entries
            ? StatsHelpers.dailyCounts(lastDays: 30, entries: filteredEntries, now: now, calendar: calendar)
            : StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 30, entries: filteredEntries, now: now, calendar: calendar)
        case .thisYear:
            let year = calendar.component(.year, from: now)
            return trendMode == .entries
            ? StatsHelpers.monthlyCounts(year: year, entries: filteredEntries, calendar: calendar)
            : StatsHelpers.uniqueSpeciesMonthlyCounts(year: year, entries: filteredEntries, calendar: calendar)
        case .allTime:
            return StatsHelpers.weeklyCounts(lastWeeks: 12, entries: filteredEntries, now: now, calendar: calendar)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppHeader(
                title: "Stats",
                subtitle: "\(filteredEntries.count) entries in current filter"
            )

            HStack(spacing: 12) {
                Picker("Timeframe", selection: $timeframe) {
                    ForEach(StatsTimeframe.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Camera", selection: $selectedCamera) {
                    Text("All cameras").tag("")
                    ForEach(cameraOptions, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)

                Spacer()
            }
            .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        statCard("Entries", "\(metric.entries)")
                        statCard("Active Days", "\(metric.activeDays)")
                        statCard("Species", "\(metric.uniqueSpecies)")
                        statCard("Locations", "\(metric.uniqueLocations)")
                        statCard("Cameras", "\(metric.uniqueCameras)")
                    }

                    trendSection
                    timeOfDaySection
                    rankingSection(title: "Top Species", items: topSpecies, emptyText: "No species yet")
                    rankingSection(title: "Top Cameras", items: topCameras, emptyText: "No cameras yet")
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appScreenBackground()
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Trend")
                    .font(.headline)
                Spacer()
            }
            .padding(.top, 8)

            Picker("Trend Mode", selection: $trendMode) {
                ForEach(TrendMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if trendDataPoints.isEmpty {
                Text("No data in this timeframe")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                chartContainer {
                    Chart(trendDataPoints) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Count", point.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.primary.opacity(0.30), AppColors.primary.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Count", point.count)
                        )
                        .foregroundStyle(AppColors.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                            AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(preset: .aligned, position: .bottom, values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                            AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(trendXAxisLabel(for: date))
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                        }
                    }
                    .frame(height: 190)
                }

                if let peak = trendDataPoints.max(by: { $0.count < $1.count }), peak.count > 0 {
                    Text("Peak: \(peak.count) on \(trendXAxisLabel(for: peak.date))")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var timeOfDaySection: some View {
        let histogram = StatsHelpers.hourHistogram(entries: filteredEntries)
        let dayNightCounts = StatsHelpers.dayNightCounts(entries: filteredEntries)
        let total = histogram.reduce(0, +)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Time of Day")
                    .font(.headline)
                Spacer()
            }
            .padding(.top, 8)

            Picker("Time of day mode", selection: $timeOfDayMode) {
                ForEach(TimeOfDayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch timeOfDayMode {
            case .histogram24h:
                if total == 0 {
                    Text("No data in this timeframe")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.vertical, 8)
                } else {
                    chartContainer {
                        Chart(Array(histogram.enumerated()), id: \.offset) { item in
                            BarMark(
                                x: .value("Hour", item.offset),
                                y: .value("Count", item.element)
                            )
                            .cornerRadius(3)
                            .foregroundStyle(AppColors.primary.opacity(0.85))
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                AxisValueLabel()
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                                AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                AxisValueLabel {
                                    if let hour = value.as(Int.self) {
                                        Text("\(hour)")
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                            }
                        }
                        .frame(height: 190)
                    }

                    if let peak = histogram.enumerated().max(by: { $0.element < $1.element }), peak.element > 0 {
                        Text("Most active: ~\(peak.offset):00 (\(peak.element) entries)")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

            case .dayNight:
                let dayNightTotal = dayNightCounts.day + dayNightCounts.night
                if dayNightTotal == 0 {
                    Text("No data in this timeframe")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.vertical, 8)
                } else {
                    let points = [
                        RankedCount(name: "Day", count: dayNightCounts.day),
                        RankedCount(name: "Night", count: dayNightCounts.night)
                    ]

                    chartContainer {
                        Chart(points) { point in
                            BarMark(
                                x: .value("Part", point.name),
                                y: .value("Count", point.count)
                            )
                            .cornerRadius(7)
                            .foregroundStyle(by: .value("Part", point.name))
                        }
                        .chartForegroundStyleScale([
                            "Day": AppColors.primary.opacity(0.85),
                            "Night": AppColors.primary.opacity(0.55)
                        ])
                        .chartYAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                AxisValueLabel()
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(position: .bottom) { _ in
                                AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                AxisValueLabel()
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .frame(height: 190)
                    }

                    let dayPct = Int((Double(dayNightCounts.day) / Double(dayNightTotal)) * 100)
                    let nightPct = 100 - dayPct
                    Text("Day: \(dayNightCounts.day) (\(dayPct)%) • Night: \(dayNightCounts.night) (\(nightPct)%)")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func chartContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }

    private func trendXAxisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        switch timeframe {
        case .last7:
            formatter.dateFormat = "EEE"
        case .last30:
            formatter.dateFormat = "d MMM"
        case .thisYear:
            formatter.dateFormat = "MMM"
        case .allTime:
            formatter.dateFormat = "d MMM"
        }

        return formatter.string(from: date)
    }

    private func rankingSection(title: String, items: [RankedCount], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.top, 8)

            if items.isEmpty {
                Text(emptyText)
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(items) { item in
                    HStack {
                        Text(item.name)
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.count)")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

struct MacMorePane: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore

    @State private var confirmDeleteDrafts = false
    @State private var confirmDeleteEntries = false
    @State private var confirmClearLocations = false

    private var draftCount: Int {
        store.entries.filter { $0.isDraft }.count
    }

    private var finalizedCount: Int {
        store.entries.filter { !$0.isDraft }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppHeader(
                title: "More",
                subtitle: "Maintenance and project info"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Data Overview")
                    .font(.headline)
                Text("Drafts: \(draftCount)")
                Text("Finalized entries: \(finalizedCount)")
                Text("Saved locations: \(savedLocationStore.locations.count)")
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                Button("Delete Drafts", role: .destructive) {
                    confirmDeleteDrafts = true
                }
                .disabled(draftCount == 0)

                Button("Delete All Entries", role: .destructive) {
                    confirmDeleteEntries = true
                }
                .disabled(store.entries.isEmpty)

                Button("Clear Locations", role: .destructive) {
                    confirmClearLocations = true
                }
                .disabled(savedLocationStore.locations.isEmpty)
            }
            .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appScreenBackground()
        .alert("Delete all drafts?", isPresented: $confirmDeleteDrafts) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteAllDrafts()
            }
        } message: {
            Text("Only drafts will be removed.")
        }
        .alert("Delete all entries?", isPresented: $confirmDeleteEntries) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteAllEntries()
            }
        } message: {
            Text("This removes all drafts and finalized entries.")
        }
        .alert("Clear all saved locations?", isPresented: $confirmClearLocations) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                savedLocationStore.clearAll()
            }
        } message: {
            Text("Entries remain unchanged.")
        }
    }
}
#endif
