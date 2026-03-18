//
//  ArrivalSpeciesDetailView.swift
//  Trailcam Journal
//
//  Full trend view for one watchlist species:
//   • Multi-year arrival date chart (day-of-year)
//   • Stats: earliest / latest / average / streak
//   • Sortable records table with inline edit / delete
//

#if os(macOS)
import SwiftUI
import Charts

struct ArrivalSpeciesDetailView: View {

    let species: String
    @EnvironmentObject var arrivalStore: ArrivalStore
    @Environment(\.dismiss) private var dismiss

    @State private var editingRecord: ArrivalRecord? = nil
    @State private var showAddRecord  = false

    // MARK: - Derived

    private var records: [ArrivalRecord] {
        arrivalStore.records(for: species).sorted { $0.year > $1.year }
    }

    private var dayOfYears: [Int] { records.map(\.dayOfYear).filter { $0 > 0 } }

    private var avgDay: Int? {
        guard !dayOfYears.isEmpty else { return nil }
        return dayOfYears.reduce(0, +) / dayOfYears.count
    }

    private var earliestRecord: ArrivalRecord? { records.min(by: { $0.dayOfYear < $1.dayOfYear }) }
    private var latestRecord:   ArrivalRecord? { records.max(by: { $0.dayOfYear < $1.dayOfYear }) }

    /// Consecutive years with a record (ending at most-recent year).
    private var streak: Int {
        guard let maxYear = records.map(\.year).max() else { return 0 }
        var count = 0
        var y = maxYear
        let yearSet = Set(records.map(\.year))
        while yearSet.contains(y) { count += 1; y -= 1 }
        return count
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(species)
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if records.isEmpty {
                        emptyState
                    } else {
                        statsRow
                        chartSection
                        recordsTable
                    }
                }
                .padding(20)
            }

            Divider()
            // Footer action
            HStack {
                Spacer()
                Button {
                    showAddRecord = true
                } label: {
                    Label("Add Record", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
        }
        .sheet(isPresented: $showAddRecord) {
            ArrivalSingleRecordSheet(species: species, record: nil)
                .environmentObject(arrivalStore)
        }
        .sheet(item: $editingRecord) { rec in
            ArrivalSingleRecordSheet(species: species, record: rec)
                .environmentObject(arrivalStore)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bird")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No records for \(species) yet.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(
                label: "Records",
                value: "\(records.count)"
            )
            Divider().frame(height: 44)
            statCell(
                label: "Earliest",
                value: earliestRecord.map { shortDate($0.date) + " '\(twoDigit($0.year))" } ?? "–"
            )
            Divider().frame(height: 44)
            statCell(
                label: "Latest",
                value: latestRecord.map { shortDate($0.date) + " '\(twoDigit($0.year))" } ?? "–"
            )
            Divider().frame(height: 44)
            statCell(
                label: "Avg arrival",
                value: avgDay.map { dayOfYearToShortDate($0) } ?? "–"
            )
            Divider().frame(height: 44)
            statCell(
                label: "Streak",
                value: streak > 0 ? "\(streak) yr" : "–"
            )
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Arrival date by year")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart {
                ForEach(records) { rec in
                    if rec.dayOfYear > 0 {
                        PointMark(
                            x: .value("Year", rec.year),
                            y: .value("Day", rec.dayOfYear)
                        )
                        .foregroundStyle(AppColors.primary)
                        .symbolSize(60)
                        .annotation(position: .top) {
                            Text(shortDate(rec.date))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let avg = avgDay {
                    RuleMark(y: .value("Average", avg))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .trailing) {
                            Text("avg")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartYAxis {
                AxisMarks(values: .stride(by: 7)) { val in
                    AxisGridLine()
                    if let day = val.as(Int.self) {
                        AxisValueLabel { Text(dayOfYearToShortDate(day)) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { val in
                    AxisGridLine()
                    if let year = val.as(Int.self) {
                        AxisValueLabel { Text(String(year)) }
                    }
                }
            }
            .frame(height: 180)
        }
    }

    // MARK: - Records table

    private var recordsTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Records")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(records) { rec in
                HStack(spacing: 10) {
                    Text(String(rec.year))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)

                    Text(mediumDate(rec.date) + (rec.approximate ? " ~" : ""))
                        .font(.body)
                        .frame(width: 100, alignment: .leading)

                    Label(rec.how.label, systemImage: rec.how.symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    if !rec.notes.isEmpty {
                        Text(rec.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Edit / Delete
                    Button { editingRecord = rec } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button(role: .destructive) {
                        arrivalStore.delete(id: rec.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.7))
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    // MARK: - Formatting helpers

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d MMM"; return f.string(from: date)
    }

    private func mediumDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f.string(from: date)
    }

    private func twoDigit(_ year: Int) -> String { String(year % 100) }

    private func dayOfYearToShortDate(_ day: Int) -> String {
        guard day > 0 else { return "–" }
        let cal  = Calendar.current
        let year = cal.component(.year, from: Date())
        guard let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let d    = cal.date(byAdding: .day, value: day - 1, to: jan1)
        else { return "–" }
        return shortDate(d)
    }
}

// MARK: - Single-record add/edit sheet

struct ArrivalSingleRecordSheet: View {

    let species:  String
    let record:   ArrivalRecord?

    @EnvironmentObject var arrivalStore: ArrivalStore
    @Environment(\.dismiss) private var dismiss

    @State private var date:        Date       = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var year:        Int        = Calendar.current.component(.year, from: Date())
    @State private var how:         ArrivalHow = .seen
    @State private var approximate: Bool       = false
    @State private var notes:       String     = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(record == nil ? "Add Record — \(species)" : "Edit Record — \(species)")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            Divider()

            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Year", selection: $year) {
                    ForEach(
                        (0..<10).map { Calendar.current.component(.year, from: Date()) - $0 },
                        id: \.self
                    ) { y in Text(String(y)).tag(y) }
                }
                Picker("How detected", selection: $how) {
                    ForEach(ArrivalHow.allCases) { h in
                        Label(h.label, systemImage: h.symbol).tag(h)
                    }
                }
                Toggle("Approximate date", isOn: $approximate)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Divider()

            HStack {
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(14)
        }
        .frame(width: 380)
        .onAppear {
            if let r = record {
                date        = r.date
                year        = r.year
                how         = r.how
                approximate = r.approximate
                notes       = r.notes
            }
        }
    }

    private func save() {
        var r      = record ?? ArrivalRecord(species: species, year: year, date: date)
        r.date        = date
        r.year        = year
        r.how         = how
        r.approximate = approximate
        r.notes       = notes
        if record != nil { arrivalStore.update(r) } else { arrivalStore.add(r) }
        dismiss()
    }
}
#endif
