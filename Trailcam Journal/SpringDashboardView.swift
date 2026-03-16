//
//  SpringDashboardView.swift
//  Trailcam Journal
//
//  Spring dashboard — shown as the default landing screen from 1 Apr to 15 Jul.
//  Shows:
//   • Arrivals card: species logged this week / total for the season
//   • Nestboxes card: active attempts / fledglings so far
//   • Recent arrivals list (last 7 days)
//   • Quick-log arrival button
//

#if os(macOS)
import SwiftUI

struct SpringDashboardView: View {

    @EnvironmentObject var arrivalStore: ArrivalStore
    @EnvironmentObject var nestboxStore: NestboxStore

    @AppStorage("app.currentSeasonYear")
    private var seasonYear: Int = Calendar.current.component(.year, from: Date())

    @State private var showQuickEntry = false

    // MARK: - Derived

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    private var seasonRecords: [ArrivalRecord] {
        arrivalStore.records.filter { $0.year == seasonYear }
    }

    private var recentArrivals: [ArrivalRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return seasonRecords
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
    }

    private var activeSeasons: [NestboxSeason] {
        nestboxStore.activeBoxes.compactMap { $0.season(for: seasonYear) }
    }

    private var totalAttempts:  Int { activeSeasons.flatMap(\.attempts).count }
    private var totalFledglings: Int { activeSeasons.map(\.totalChicksFledged).reduce(0, +) }
    private var watchlistTotal:  Int { arrivalStore.watchlist.count }
    private var arrivedCount:    Int {
        Set(seasonRecords.map(\.species))
            .filter { arrivalStore.watchlist.contains($0) }.count
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // ── Season header ─────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spring \(String(seasonYear))")
                            .font(.title.weight(.semibold))
                        Text(seasonSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Picker("Season", selection: $seasonYear) {
                        ForEach(
                            (0..<4).map { currentYear - $0 },
                            id: \.self
                        ) { y in Text(String(y)).tag(y) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()

                    Button {
                        showQuickEntry = true
                    } label: {
                        Label("Log Arrival", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(seasonYear != currentYear)
                }

                // ── Summary cards (or empty state) ───────────────────
                if seasonRecords.isEmpty {
                    seasonEmptyState
                } else {
                    HStack(spacing: 14) {
                        dashboardCard(
                            icon: "bird",
                            iconColor: AppColors.primary,
                            title: "Arrivals",
                            primary: "\(arrivedCount) / \(watchlistTotal)",
                            secondary: "species on watchlist"
                        )
                        dashboardCard(
                            icon: "house",
                            iconColor: .green,
                            title: "Nestboxes",
                            primary: "\(totalAttempts)",
                            secondary: "active attempt\(totalAttempts == 1 ? "" : "s")"
                        )
                        dashboardCard(
                            icon: "bird.fill",
                            iconColor: .orange,
                            title: "Chicks out",
                            primary: "\(totalFledglings)",
                            secondary: "left the nest this season"
                        )
                        dashboardCard(
                            icon: "checkmark.circle",
                            iconColor: .mint,
                            title: "Completed",
                            primary: "\(arrivedCount)",
                            secondary: "of \(watchlistTotal) arrived"
                        )
                    }
                }

                // ── Recent arrivals (last 7 days) ─────────────────────
                if !recentArrivals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Arrivals (last 7 days)")
                            .font(.headline)

                        ForEach(recentArrivals) { rec in
                            HStack(spacing: 12) {
                                Image(systemName: rec.how.symbol)
                                    .font(.body)
                                    .foregroundStyle(AppColors.primary)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rec.species)
                                        .font(.body.weight(.medium))
                                    Text(rec.date.formatted(date: .abbreviated, time: .omitted)
                                         + (rec.approximate ? " (approx.)" : ""))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if !rec.notes.isEmpty {
                                    Text(rec.notes)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                        .frame(maxWidth: 200, alignment: .trailing)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }

                // ── Still waiting (watchlist species not yet arrived) ──
                let waitingSpecies = arrivalStore.watchlist.filter { sp in
                    !seasonRecords.map(\.species).contains(sp)
                }
                if !waitingSpecies.isEmpty && seasonYear == currentYear {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Still Waiting")
                            .font(.headline)

                        FlowLayout(spacing: 6) {
                            ForEach(waitingSpecies, id: \.self) { sp in
                                Text(sp)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // ── Nestbox summary table ─────────────────────────────
                if !nestboxStore.activeBoxes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nestbox Season Summary")
                            .font(.headline)

                        ForEach(nestboxStore.activeBoxes.sorted { $0.name < $1.name }) { box in
                            if let season = box.season(for: seasonYear) {
                                nestboxSummaryRow(box: box, season: season)
                            } else {
                                nestboxEmptyRow(box: box)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Spring Dashboard")
        .sheet(isPresented: $showQuickEntry) {
            ArrivalQuickEntrySheet(
                targetYear: currentYear
            )
            .environmentObject(arrivalStore)
        }
    }

    // MARK: - Season subtitle

    private var seasonSubtitle: String {
        if seasonYear == currentYear {
            let remaining = arrivalStore.watchlist.count - arrivedCount
            if remaining == 0 { return "All species arrived!" }
            return "\(remaining) species still expected"
        }
        return "\(arrivedCount) species recorded"
    }

    // MARK: - Season empty state

    private var seasonEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bird")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AppColors.primary.opacity(0.45))

            VStack(spacing: 6) {
                Text("Spring \(String(seasonYear)) hasn't started yet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.primary)
                Text("Log your first arrival to begin tracking the season.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showQuickEntry = true
            } label: {
                Label("Log Arrival", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(seasonYear != currentYear)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Dashboard card

    private func dashboardCard(
        icon:      String,
        iconColor: Color,
        title:     String,
        primary:   String,
        secondary: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                Spacer()
            }
            Text(primary)
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(secondary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Nestbox rows

    private func nestboxSummaryRow(box: Nestbox, season: NestboxSeason) -> some View {
        HStack(spacing: 12) {
            Image(systemName: box.boxType.symbol)
                .foregroundStyle(AppColors.primary)
                .frame(width: 20)

            Text(box.name)
                .font(.body.weight(.medium))
                .frame(width: 100, alignment: .leading)

            Spacer()

            Label("\(season.attempts.count)", systemImage: "bird")
                .font(.caption)
                .foregroundStyle(.secondary)

            Label("\(season.totalChicksFledged)", systemImage: "bird.fill")
                .font(.caption)
                .foregroundStyle(season.totalChicksFledged > 0 ? .green : .secondary)

            if let outcome = season.attempts.last?.outcome {
                Image(systemName: outcome.symbol)
                    .font(.caption)
                    .foregroundStyle(outcome.isSuccess ? .green : .secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func nestboxEmptyRow(box: Nestbox) -> some View {
        HStack(spacing: 12) {
            Image(systemName: box.boxType.symbol)
                .foregroundStyle(.tertiary)
                .frame(width: 20)

            Text(box.name)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Text("Waiting for first activity")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
#endif
