//
//  CameraDetailView.swift
//  Trailcam Journal
//

import SwiftUI
import Charts

struct CameraDetailView: View {
    let cameraName: String
    let allEntries: [TrailEntry]

    @State private var trendMode: TrendMode = .entries

    private var entries: [TrailEntry] {
        allEntries.filter { ($0.camera ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == cameraName }
    }

    private var metrics: StatsMetric {
        StatsHelpers.metrics(from: entries)
    }

    private var trend: [StatsBarPoint] {
        let now = Date()
        let cal = Calendar.current
        if trendMode == .entries {
            return StatsHelpers.dailyCounts(lastDays: 30, entries: entries, now: now, calendar: cal)
        } else {
            return StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 30, entries: entries, now: now, calendar: cal)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppHeader(title: cameraName, subtitle: "Camera performance")

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        metricPill(title: "Entries", value: "\(metrics.entries)")
                        metricPill(title: "Species", value: "\(metrics.uniqueSpecies)")
                    }
                    HStack(spacing: 12) {
                        metricPill(title: "Active days", value: "\(metrics.activeDays)")
                        metricPill(title: "Locations", value: "\(metrics.uniqueLocations)")
                    }
                }
                .padding(.horizontal)

                StatsCard(title: "Last 30 days") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Trend", selection: $trendMode) {
                            ForEach(TrendMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)

                        Chart(trend) { p in
                            BarMark(
                                x: .value("Date", p.date),
                                y: .value("Count", p.count)
                            )
                        }
                        .frame(height: 200)
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
                        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                    }
                }

                StatsCard(title: "Top species") {
                    let top = StatsHelpers.topSpecies(entries: entries, limit: 5)
                    if top.isEmpty {
                        Text("No species yet")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.vertical, 10)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(top) { item in
                                HStack {
                                    Text(item.name)
                                        .foregroundStyle(AppColors.primary)
                                    Spacer()
                                    Text("\(item.count)")
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                if item.id != top.last?.id { Divider().opacity(0.3) }
                            }
                        }
                    }
                }

                StatsCard(title: "Time of day") {
                    let histogram = StatsHelpers.hourHistogram(entries: entries)
                    if histogram.reduce(0, +) == 0 {
                        Text("No data")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.vertical, 10)
                    } else {
                        Chart(Array(histogram.enumerated()), id: \.offset) { item in
                            BarMark(
                                x: .value("Hour", item.offset),
                                y: .value("Count", item.element)
                            )
                        }
                        .frame(height: 200)
                        .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 23]) }
                        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .appScreenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.primary.opacity(0.10), lineWidth: 1)
                )
        )
    }
}
