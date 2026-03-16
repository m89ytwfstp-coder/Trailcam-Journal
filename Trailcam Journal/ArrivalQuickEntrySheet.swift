//
//  ArrivalQuickEntrySheet.swift
//  Trailcam Journal
//
//  Quick-entry sheet for logging spring arrivals.
//  Used for both current-year (showQuickEntry) and historical bulk entry
//  (isHistorical = true, targetYear supplied by caller).
//
//  Flow:
//   1. Date picker (defaults to yesterday)
//   2. Scrollable species checklist (watchlist species not yet recorded)
//   3. Per-species: how (seen/heard/trailcam) + approximate toggle + notes
//

#if os(macOS)
import SwiftUI

struct ArrivalQuickEntrySheet: View {

    @EnvironmentObject var arrivalStore: ArrivalStore
    @Environment(\.dismiss) private var dismiss

    let targetYear:    Int
    var isHistorical:  Bool = false

    // MARK: - State

    @State private var selectedDate: Date = {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }()

    /// species → (how, approximate, notes)  for pending entries
    @State private var checked: [String: Bool] = [:]
    @State private var howMap:  [String: ArrivalHow]   = [:]
    @State private var approxMap: [String: Bool]       = [:]
    @State private var notesMap:  [String: String]     = [:]
    @State private var expanded:  String?              = nil   // species with notes expanded

    // MARK: - Derived

    private var speciesList: [String] {
        let alreadyRecorded = Set(
            arrivalStore.records
                .filter { $0.year == targetYear }
                .map(\.species)
        )
        return arrivalStore.watchlist.filter { !alreadyRecorded.contains($0) }
    }

    private var checkedSpecies: [String] {
        speciesList.filter { checked[$0] == true }
    }

    private var canSave: Bool { !checkedSpecies.isEmpty }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 420)
        .frame(minHeight: 480)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(isHistorical ? "Historical Entry — \(targetYear)" : "Log Arrivals")
                    .font(.headline)
                if isHistorical {
                    Text("Recording arrivals for \(targetYear)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Cancel") { dismiss() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Date picker
                GroupBox {
                    DatePicker(
                        "Arrival date",
                        selection: $selectedDate,
                        in: dateRange,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }

                // Species checklist
                if speciesList.isEmpty {
                    Text("All watchlist species already recorded for \(targetYear).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    Text("Arrived today / this date:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(speciesList, id: \.self) { species in
                        speciesRow(species)
                    }
                }
            }
            .padding(16)
        }
    }

    private var dateRange: ClosedRange<Date> {
        let cal = Calendar.current
        let jan1 = cal.date(from: DateComponents(year: targetYear, month: 1, day: 1))!
        let dec31 = cal.date(from: DateComponents(year: targetYear, month: 12, day: 31))!
        return jan1...min(dec31, Date())
    }

    // MARK: - Species row

    @ViewBuilder
    private func speciesRow(_ species: String) -> some View {
        let isChecked = checked[species] == true

        VStack(alignment: .leading, spacing: 0) {
            // Main toggle row
            HStack(spacing: 10) {
                Toggle(isOn: Binding(
                    get: { checked[species] == true },
                    set: { checked[species] = $0 }
                )) {
                    Text(species)
                        .font(.body)
                }
                .toggleStyle(.checkbox)

                Spacer()

                if isChecked {
                    // How picker
                    Picker("", selection: Binding(
                        get: { howMap[species] ?? .seen },
                        set: { howMap[species] = $0 }
                    )) {
                        ForEach(ArrivalHow.allCases) { h in
                            Label(h.label, systemImage: h.symbol).tag(h)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 130)

                    // Approx toggle
                    Toggle("~", isOn: Binding(
                        get: { approxMap[species] ?? false },
                        set: { approxMap[species] = $0 }
                    ))
                    .toggleStyle(.checkbox)
                    .help("Date is approximate")

                    // Notes disclosure
                    Button {
                        expanded = expanded == species ? nil : species
                    } label: {
                        Image(systemName: "note.text")
                            .foregroundStyle(
                                (notesMap[species]?.isEmpty == false) ? AppColors.primary : .secondary
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Add notes")
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                isChecked
                    ? AppColors.primary.opacity(0.07)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            // Notes field (expanded)
            if isChecked && expanded == species {
                TextField("Notes (optional)", text: Binding(
                    get: { notesMap[species] ?? "" },
                    set: { notesMap[species] = $0 }
                ), axis: .vertical)
                .lineLimit(2...)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(checkedSpecies.isEmpty
                 ? "No species selected"
                 : "\(checkedSpecies.count) species selected")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Save") { saveAll() }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
        }
        .padding(14)
    }

    // MARK: - Save

    private func saveAll() {
        for species in checkedSpecies {
            let record = ArrivalRecord(
                species:     species,
                year:        targetYear,
                date:        selectedDate,
                how:         howMap[species] ?? .seen,
                approximate: approxMap[species] ?? false,
                notes:       notesMap[species] ?? ""
            )
            arrivalStore.add(record)
        }
        dismiss()
    }
}
#endif
