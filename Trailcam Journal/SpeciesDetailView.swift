//
//  SpeciesDetailView.swift
//  Trailcam Journal
//

import SwiftUI
import Charts

struct SpeciesDetailView: View {
    let speciesName: String
    let allEntries: [TrailEntry]

    @State private var timeframe: StatsTimeframe = .last30
    @State private var trendMode: TrendMode = .entries
    @State private var timeOfDayMode: TimeOfDayMode = .histogram24h

    private var entries: [TrailEntry] {
        allEntries.filter { ($0.species ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == speciesName }
    }

    private var filteredEntries: [TrailEntry] {
        StatsHelpers.filterFinalEntries(entries, timeframe: timeframe, selectedCamera: nil)
    }

    private var metrics: StatsMetric {
        StatsHelpers.metrics(from: filteredEntries)
    }

    private var trend: [StatsBarPoint] {
        let now = Date()
        let cal = Calendar.current

        switch timeframe {
        case .last7:
            return trendMode == .entries
            ? StatsHelpers.dailyCounts(lastDays: 7, entries: filteredEntries, now: now, calendar: cal)
            : StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 7, entries: filteredEntries, now: now, calendar: cal)
        case .last30:
            return trendMode == .entries
            ? StatsHelpers.dailyCounts(lastDays: 30, entries: filteredEntries, now: now, calendar: cal)
            : StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 30, entries: filteredEntries, now: now, calendar: cal)
        case .thisYear:
            let y = cal.component(.year, from: now)
            return trendMode == .entries
            ? StatsHelpers.monthlyCounts(year: y, entries: filteredEntries, calendar: cal)
            : StatsHelpers.uniqueSpeciesMonthlyCounts(year: y, entries: filteredEntries, calendar: cal)
        case .allTime:
            return StatsHelpers.weeklyCounts(lastWeeks: 12, entries: filteredEntries, now: now, calendar: cal)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppHeader(title: speciesName, subtitle: "Species performance")

                HStack(spacing: 10) {
                    Menu {
                        Picker("Timeframe", selection: $timeframe) {
                            ForEach(StatsTimeframe.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        StatsControlPill(text: timeframe.rawValue, systemImage: "calendar")
                    }

                    Spacer()
                }
                .padding(.horizontal)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        StatsMetricPill(title: "Entries", value: "\(metrics.entries)")
                        StatsMetricPill(title: "Cameras", value: "\(metrics.uniqueCameras)")
                    }
                    HStack(spacing: 12) {
                        StatsMetricPill(title: "Active days", value: "\(metrics.activeDays)")
                        StatsMetricPill(title: "Locations", value: "\(metrics.uniqueLocations)")
                    }
                }
                .padding(.horizontal)

                StatsCard(title: "Trend") {
                    VStack(alignment: .leading, spacing: 10) {
                        StatsSegmentedCapsule {
                            Picker("Trend", selection: $trendMode) {
                                ForEach(TrendMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if trend.reduce(0, { $0 + $1.count }) == 0 {
                            Text("No data in this timeframe")
                                .font(.footnote)
                                .foregroundStyle(AppColors.textSecondary)
                                .padding(.vertical, 8)
                        } else {
                            StatsChartContainer {
                                Chart(trend) { point in
                                    AreaMark(
                                        x: .value("Date", point.date),
                                        y: .value("Count", point.count)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [AppColors.primary.opacity(0.30), AppColors.primary.opacity(0.05)],
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
                                .frame(height: 190)
                                .chartXAxis {
                                    AxisMarks(preset: .aligned, position: .bottom, values: .automatic(desiredCount: 5)) { value in
                                        AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                        AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                        AxisValueLabel {
                                            if let date = value.as(Date.self) {
                                                Text(trendXAxisLabel(date: date, timeframe: timeframe))
                                                    .font(.caption2)
                                                    .foregroundStyle(AppColors.textSecondary)
                                            }
                                        }
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                        AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                        AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                        AxisValueLabel()
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                            }

                            if let peak = trend.max(by: { $0.count < $1.count }), peak.count > 0 {
                                Text("Peak: \(peak.count) on \(trendXAxisLabel(date: peak.date, timeframe: timeframe))")
                                    .font(.footnote)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                }

                StatsCard(title: "Top cameras") {
                    let top = StatsHelpers.topCameras(entries: filteredEntries, limit: 5)
                    if top.isEmpty {
                        Text("No camera names found")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(top) { item in
                                NavigationLink {
                                    CameraDetailView(cameraName: item.name, allEntries: allEntries)
                                } label: {
                                    HStack {
                                        Text(item.name)
                                            .foregroundStyle(AppColors.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(item.count)")
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                                .buttonStyle(.plain)

                                if item.id != top.last?.id {
                                    Divider().opacity(0.25)
                                }
                            }
                        }
                    }
                }

                StatsCard(title: "Time of day") {
                    let histogram = StatsHelpers.hourHistogram(entries: filteredEntries)
                    let dayNight = StatsHelpers.dayNightCounts(entries: filteredEntries)
                    let dayNightTotal = dayNight.day + dayNight.night

                    VStack(alignment: .leading, spacing: 10) {
                        StatsSegmentedCapsule {
                            Picker("Time of day mode", selection: $timeOfDayMode) {
                                ForEach(TimeOfDayMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        switch timeOfDayMode {
                        case .histogram24h:
                            if histogram.reduce(0, +) == 0 {
                                Text("No data in this timeframe")
                                    .font(.footnote)
                                    .foregroundStyle(AppColors.textSecondary)
                                .padding(.vertical, 8)
                            } else {
                                StatsChartContainer {
                                    Chart(Array(histogram.enumerated()), id: \.offset) { item in
                                        BarMark(
                                            x: .value("Hour", item.offset),
                                            y: .value("Count", item.element)
                                        )
                                        .cornerRadius(3)
                                        .foregroundStyle(AppColors.primary.opacity(0.85))
                                    }
                                    .frame(height: 190)
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
                                    .chartYAxis {
                                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                            AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                            AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                            AxisValueLabel()
                                                .font(.caption2)
                                                .foregroundStyle(AppColors.textSecondary)
                                        }
                                    }
                                }

                                if let peak = histogram.enumerated().max(by: { $0.element < $1.element }), peak.element > 0 {
                                    Text("Most active: ~\(peak.offset):00")
                                        .font(.footnote)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                        case .dayNight:
                            if dayNightTotal == 0 {
                                Text("No data in this timeframe")
                                    .font(.footnote)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .padding(.vertical, 8)
                            } else {
                                let points: [RankedCount] = [
                                    .init(name: "Day", count: dayNight.day),
                                    .init(name: "Night", count: dayNight.night)
                                ]

                                StatsChartContainer {
                                    Chart(points) { p in
                                        BarMark(
                                            x: .value("Part", p.name),
                                            y: .value("Count", p.count)
                                        )
                                        .cornerRadius(7)
                                        .foregroundStyle(by: .value("Part", p.name))
                                    }
                                    .chartForegroundStyleScale([
                                        "Day": AppColors.primary.opacity(0.85),
                                        "Night": AppColors.primary.opacity(0.55)
                                    ])
                                    .frame(height: 190)
                                    .chartXAxis {
                                        AxisMarks(position: .bottom) { _ in
                                            AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                            AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                            AxisValueLabel()
                                                .font(.caption2)
                                                .foregroundStyle(AppColors.textSecondary)
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                            AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                            AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                            AxisValueLabel()
                                                .font(.caption2)
                                                .foregroundStyle(AppColors.textSecondary)
                                        }
                                    }
                                }

                                let dayPct = Int((Double(dayNight.day) / Double(dayNightTotal)) * 100)
                                let nightPct = 100 - dayPct
                                Text("Day: \(dayNight.day) (\(dayPct)%) • Night: \(dayNight.night) (\(nightPct)%)")
                                    .font(.footnote)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .appScreenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
