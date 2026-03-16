//
//  NestboxAttemptForm.swift
//  Trailcam Journal
//
//  Add / edit a breeding attempt within a nestbox season.
//  Automatically creates or updates the parent season in NestboxStore.
//

#if os(macOS)
import SwiftUI

struct NestboxAttemptForm: View {

    let boxID:    UUID
    let season:   NestboxSeason    // the season this attempt belongs to
    let attempt:  NestboxAttempt?  // nil → new attempt

    @EnvironmentObject var nestboxStore: NestboxStore
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var species:       String         = ""
    @State private var eggsLaid:      String         = ""
    @State private var eggsHatched:   String         = ""
    @State private var chicksFledged: String         = ""
    @State private var firstEggDate:  Date?          = nil
    @State private var hatchDate:     Date?          = nil
    @State private var fledgeDate:    Date?          = nil
    @State private var outcome:       AttemptOutcome = .unknown
    @State private var notes:         String         = ""

    @State private var hasFirstEgg: Bool = false
    @State private var hasHatch:    Bool = false
    @State private var hasFledge:   Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 420)
        .onAppear { populate() }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Text(attempt == nil ? "New Breeding Attempt" : "Edit Attempt")
                .font(.headline)
            Spacer()
            Button("Cancel") { dismiss() }
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)
    }

    // MARK: - Form

    private var formContent: some View {
        Form {
            Section("Species & outcome") {
                TextField("Species (e.g. Rødstjert)", text: $species)
                Picker("Outcome", selection: $outcome) {
                    ForEach(AttemptOutcome.allCases) { o in
                        Label(o.label, systemImage: o.symbol).tag(o)
                    }
                }
            }

            Section("Counts") {
                HStack {
                    Text("Eggs laid")
                    Spacer()
                    TextField("–", text: $eggsLaid)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Eggs hatched")
                    Spacer()
                    TextField("–", text: $eggsHatched)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Chicks fledged")
                    Spacer()
                    TextField("–", text: $chicksFledged)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Key dates (optional)") {
                Toggle("First egg date", isOn: $hasFirstEgg)
                if hasFirstEgg {
                    DatePicker("", selection: Binding(
                        get: { firstEggDate ?? Date() },
                        set: { firstEggDate = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                }

                Toggle("Hatch date", isOn: $hasHatch)
                if hasHatch {
                    DatePicker("", selection: Binding(
                        get: { hatchDate ?? Date() },
                        set: { hatchDate = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                }

                Toggle("Fledge date", isOn: $hasFledge)
                if hasFledge {
                    DatePicker("", selection: Binding(
                        get: { fledgeDate ?? Date() },
                        set: { fledgeDate = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                }
            }

            Section("Notes") {
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("Save") { save() }
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
    }

    // MARK: - Populate from existing attempt

    private func populate() {
        guard let a = attempt else { return }
        species       = a.species
        eggsLaid      = a.eggsLaid.map(String.init)    ?? ""
        eggsHatched   = a.eggsHatched.map(String.init) ?? ""
        chicksFledged = a.chicksFledged.map(String.init) ?? ""
        outcome       = a.outcome
        notes         = a.notes
        if let d = a.firstEggDate { hasFirstEgg = true; firstEggDate = d }
        if let d = a.hatchDate    { hasHatch    = true; hatchDate    = d }
        if let d = a.fledgeDate   { hasFledge   = true; fledgeDate   = d }
    }

    // MARK: - Save

    private func save() {
        var a           = attempt ?? NestboxAttempt()
        a.species       = species.trimmingCharacters(in: .whitespacesAndNewlines)
        a.eggsLaid      = Int(eggsLaid)
        a.eggsHatched   = Int(eggsHatched)
        a.chicksFledged = Int(chicksFledged)
        a.firstEggDate  = hasFirstEgg ? firstEggDate : nil
        a.hatchDate     = hasHatch    ? hatchDate    : nil
        a.fledgeDate    = hasFledge   ? fledgeDate   : nil
        a.outcome       = outcome
        a.notes         = notes

        // Upsert season (creates it if it doesn't exist yet)
        var updatedSeason = season
        if let idx = updatedSeason.attempts.firstIndex(where: { $0.id == a.id }) {
            updatedSeason.attempts[idx] = a
        } else {
            updatedSeason.attempts.append(a)
        }
        nestboxStore.upsertSeason(updatedSeason, in: boxID)
        // Also sync the attempt directly for consistency
        nestboxStore.upsertAttempt(a, seasonID: updatedSeason.id, boxID: boxID)

        dismiss()
    }
}
#endif
