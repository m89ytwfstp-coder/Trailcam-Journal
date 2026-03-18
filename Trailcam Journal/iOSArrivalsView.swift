
//
//  iOSArrivalsView.swift
//  Trailcam Journal
//
//  iOS field view for logging spring arrivals.
//  The Mac companion has the full dashboard (SpringDashboardView + MacArrivalsPane).
//  This view focuses on quick logging from paper notes — date is NEVER pre-filled.
//

#if os(iOS)
import SwiftUI

struct iOSArrivalsView: View {
    @EnvironmentObject private var arrivalStore: ArrivalStore

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showAddSheet:  Bool = false

    private var displayedRecords: [ArrivalRecord] {
        arrivalStore.records
            .filter { $0.year == selectedYear }
            .sorted { $0.date < $1.date }
    }

    private var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        let recorded = arrivalStore.years
        return Array(Set(recorded + [current, current - 1, current - 2])).sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                yearPicker
                Divider()

                if displayedRecords.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(displayedRecords) { record in
                            ArrivalRecordRow(record: record)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { displayedRecords[$0].id }
                            ids.forEach { arrivalStore.delete(id: $0) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Spring \(selectedYear)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                iOSAddArrivalSheet(year: selectedYear)
                    .environmentObject(arrivalStore)
            }
        }
    }

    private var yearPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableYears, id: \.self) { year in
                    Button {
                        selectedYear = year
                    } label: {
                        Text(String(year))
                            .font(.subheadline.weight(selectedYear == year ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(
                                selectedYear == year
                                ? AppColors.primary.opacity(0.15)
                                : Color.secondary.opacity(0.10)
                            ))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "leaf")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(AppColors.primary.opacity(0.3))
            Text("No arrivals for \(selectedYear)")
                .font(.headline)
                .foregroundStyle(AppColors.primary)
            Text("Tap + to record your first arrival.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Row

private struct ArrivalRecordRow: View {
    let record: ArrivalRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.species)
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)
                Label(record.how.label, systemImage: record.how.symbol)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                if !record.notes.isEmpty {
                    Text(record.notes)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                if record.approximate {
                    Text("approx.")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Add Sheet

struct iOSAddArrivalSheet: View {
    @EnvironmentObject private var arrivalStore: ArrivalStore
    @Environment(\.dismiss) private var dismiss

    let year: Int

    @State private var species:         String      = ""
    @State private var observationDate: Date?       = nil   // NEVER defaults to today
    @State private var how:             ArrivalHow  = .seen
    @State private var approximate:     Bool        = false
    @State private var notes:           String      = ""

    private var canSave: Bool {
        !species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && observationDate != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Arrival") {
                    TextField("Species (e.g. Gjøk)", text: $species)

                    // Date — NEVER defaults to today
                    if let date = observationDate {
                        DatePicker(
                            "Observation date",
                            selection: Binding(
                                get: { date },
                                set: { observationDate = $0 }
                            ),
                            in: yearRange,
                            displayedComponents: .date
                        )
                        Toggle("Approximate date", isOn: $approximate)
                    } else {
                        Button("Set observation date…") {
                            // Default to Jan 1 of the selected year — not today
                            observationDate = Calendar.current.date(
                                from: DateComponents(year: year, month: 1, day: 1)
                            )
                        }
                        .foregroundStyle(AppColors.primary)
                    }

                    Picker("How detected", selection: $how) {
                        ForEach(ArrivalHow.allCases) { h in
                            Label(h.label, systemImage: h.symbol).tag(h)
                        }
                    }
                }

                Section("Notes (optional)") {
                    TextField("Any context or notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("New Arrival")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var yearRange: ClosedRange<Date> {
        let cal   = Calendar.current
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end   = cal.date(from: DateComponents(year: year, month: 12, day: 31))!
        return start...end
    }

    private func save() {
        guard let date = observationDate else { return }
        let record = ArrivalRecord(
            species:     species.trimmingCharacters(in: .whitespacesAndNewlines),
            year:        year,
            date:        date,
            how:         how,
            approximate: approximate,
            notes:       notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        arrivalStore.add(record)
        dismiss()
    }
}
#endif
