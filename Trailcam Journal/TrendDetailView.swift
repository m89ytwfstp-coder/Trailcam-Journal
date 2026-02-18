//
//  TrendDetailView.swift
//  Trailcam Journal
//

import SwiftUI
import Charts

struct TrendDetailView: View {
    let entries: [TrailEntry]
    let timeframe: StatsTimeframe

    @State private var mode: TrendMode = .entries
    @State private var range: DetailRange = .auto

    private enum DetailRange: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case last30 = "Last 30"
        case last90 = "Last 90"
        case thisYear = "This year"

        var id: String { rawValue }
    }

    private var points: [StatsBarPoint] {
        let cal = Calendar.current
        let now = Date()

        let effective = (range == .auto) ? nil : range

        func daily(_ days: Int) -> [StatsBarPoint] {
            mode == .entries
            ? StatsHelpers.dailyCounts(lastDays: days, entries: entries, now: now, calendar: cal)
            : StatsHelpers.uniqueSpeciesDailyCounts(lastDays: days, entries: entries, now: now, calendar: cal)
        }

        func monthlyThisYear() -> [StatsBarPoint] {
            let y = cal.component(.year, from: now)
            return mode == .entries
            ? StatsHelpers.monthlyCounts(year: y, entries: entries, calendar: cal)
            : StatsHelpers.uniqueSpeciesMonthlyCounts(year: y, entries: entries, calendar: cal)
        }

        if let effective {
            switch effective {
            case .auto:
                return []
            case .last30:
                return daily(30)
            case .last90:
                return daily(90)
            case .thisYear:
                return monthlyThisYear()
            }
        }

        switch timeframe {
        case .last7:
            return daily(7)
        case .last30:
            return daily(30)
        case .thisYear:
            return monthlyThisYear()
        case .allTime:
            return daily(90)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppHeader(title: "Trend", subtitle: "Entries over time")

                VStack(alignment: .leading, spacing: 10) {
                    Picker("Mode", selection: $mode) {
                        ForEach(TrendMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Range")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Picker("Range", selection: $range) {
                            ForEach(DetailRange.allCases) { r in
                                Text(r.rawValue).tag(r)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if points.isEmpty {
                        Text("No data")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.vertical, 12)
                    } else {
                        Chart(points) { p in
                            BarMark(
                                x: .value("Date", p.date),
                                y: .value("Count", p.count)
                            )
                            .cornerRadius(5)
                            .foregroundStyle(AppColors.primary.opacity(0.85))
                        }
                        .frame(height: 260)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                AxisValueLabel()
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
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


                        let total = points.reduce(0) { $0 + $1.count }
                        Text("Total: \(total)")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .appScreenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
