//
//  TimeOfDayDetailView.swift
//  Trailcam Journal
//

import SwiftUI
import Charts

struct TimeOfDayDetailView: View {
    let entries: [TrailEntry]
    @State private var mode: TimeOfDayMode = .histogram24h

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppHeader(title: "Time of day", subtitle: "When your cameras are most active")

                VStack(alignment: .leading, spacing: 10) {
                    pickerCapsule {
                        Picker("Mode", selection: $mode) {
                            ForEach(TimeOfDayMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    switch mode {
                    case .histogram24h:
                        histogram24h
                    case .dayNight:
                        dayNight
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

private extension TimeOfDayDetailView {
    var histogram24h: some View {
        let histogram = StatsHelpers.hourHistogram(entries: entries)
        let total = histogram.reduce(0, +)

        return VStack(alignment: .leading, spacing: 10) {
            if total == 0 {
                Text("No data in this timeframe")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, 12)
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
                    .frame(height: 240)
                    .chartXAxis {
                        AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21, 23]) { value in
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
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                            AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
                if let peak = histogram.enumerated().max(by: { $0.element < $1.element }), peak.element > 0 {
                    Text("Peak hour: ~\(peak.offset):00 (\(peak.element) entries)")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    var dayNight: some View {
        let dn = StatsHelpers.dayNightCounts(entries: entries)
        let total = dn.day + dn.night
        let points: [RankedCount] = [
            .init(name: "Day", count: dn.day),
            .init(name: "Night", count: dn.night)
        ]

        return VStack(alignment: .leading, spacing: 10) {
            if total == 0 {
                Text("No data in this timeframe")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, 12)
            } else {
                chartContainer {
                    Chart(points) { p in
                        BarMark(
                            x: .value("Part", p.name),
                            y: .value("Count", p.count)
                        )
                        .cornerRadius(8)
                        .foregroundStyle(by: .value("Part", p.name))
                    }
                    .chartForegroundStyleScale([
                        "Day": AppColors.primary.opacity(0.85),
                        "Night": AppColors.primary.opacity(0.55)
                    ])
                    .frame(height: 220)
                    .chartXAxis {
                        AxisMarks { _ in
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
                }
                let dayPct = Int((Double(dn.day) / Double(total)) * 100)
                let nightPct = 100 - dayPct
                Text("Day: \(dn.day) (\(dayPct)%) • Night: \(dn.night) (\(nightPct)%)")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    func pickerCapsule<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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

    func chartContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
