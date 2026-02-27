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
            return StatsHelpers.weeklyCounts(lastWeeks: 12, entries: entries, now: now, calendar: cal)
        }
    }

    private var chartTitle: String {
        mode == .entries ? "Entries over time" : "Unique species over time"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppHeader(title: "Trend", subtitle: chartTitle)

                VStack(alignment: .leading, spacing: 10) {
                    pickerCapsule {
                        Picker("Mode", selection: $mode) {
                            ForEach(TrendMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

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
                        Text("No data in this timeframe")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.vertical, 12)
                    } else {
                        chartContainer {
                            Chart(points) { p in
                                AreaMark(
                                    x: .value("Date", p.date),
                                    y: .value("Count", p.count)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppColors.primary.opacity(0.30), AppColors.primary.opacity(0.04)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                LineMark(
                                    x: .value("Date", p.date),
                                    y: .value("Count", p.count)
                                )
                                .foregroundStyle(AppColors.primary)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.catmullRom)
                            }
                            .frame(height: 240)
                            .chartXAxis {
                                AxisMarks(preset: .aligned, position: .bottom, values: .automatic(desiredCount: 5)) { value in
                                    AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                    AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                    AxisValueLabel {
                                        if let date = value.as(Date.self) {
                                            Text(axisLabel(for: date))
                                                .font(.caption2)
                                                .foregroundStyle(AppColors.textSecondary)
                                        }
                                    }
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
                        }

                        let total = points.reduce(0, { $0 + $1.count })
                        let peak = points.max(by: { $0.count < $1.count })
                        let insight = if let peak, peak.count > 0 {
                            "Total: \(total) • Peak: \(peak.count) on \(axisLabel(for: peak.date))"
                        } else {
                            "Total: \(total)"
                        }

                        Text(insight)
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

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        if range == .thisYear || timeframe == .thisYear {
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }

        if timeframe == .allTime && range == .auto {
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }

        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func pickerCapsule<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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

    private func chartContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
}
