//
//  MacNestboxDetailView.swift
//  Trailcam Journal
//
//  Two-panel nestbox detail:
//   Left  — cover photo placeholder + GPS-linked entry thumbnails
//   Right — seasons list with per-attempt accordion
//

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct MacNestboxDetailView: View {

    let boxID: UUID

    @EnvironmentObject var nestboxStore: NestboxStore
    @EnvironmentObject var store:        EntryStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("app.currentSeasonYear")
    private var seasonYear: Int = Calendar.current.component(.year, from: Date())

    @State private var showEditBox      = false
    @State private var showAddAttempt   = false
    @State private var editingAttempt:  (attempt: NestboxAttempt, seasonID: UUID)? = nil
    @State private var editingSeasonNotes: NestboxSeason? = nil
    @State private var coverPhotoImage: NSImage? = nil   // cached loaded cover photo

    // MARK: - Derived

    private var box: Nestbox? { nestboxStore.nestboxes.first { $0.id == boxID } }

    private var currentSeason: NestboxSeason? { box?.season(for: seasonYear) }

    // MARK: - Body

    var body: some View {
        if let box = box {
            VStack(spacing: 0) {
                sheetHeader(box: box)
                Divider()
                rightPanel(box: box)
            }
            .onAppear { loadCoverPhoto(for: box) }
            .onChange(of: box.coverPhotoName) { _ in loadCoverPhoto(for: box) }
            .sheet(isPresented: $showEditBox) {
                NestboxEditSheet(box: box) { updated in nestboxStore.update(updated) }
            }
            .sheet(isPresented: $showAddAttempt) {
                NestboxAttemptForm(
                    boxID: boxID,
                    season: currentOrNewSeason(for: box),
                    attempt: nil
                )
                .environmentObject(nestboxStore)
            }
            .sheet(item: Binding(
                get: { editingAttempt.map { EditingAttemptID(attempt: $0.attempt, seasonID: $0.seasonID) } },
                set: { editingAttempt = $0.map { ($0.attempt, $0.seasonID) } }
            )) { ea in
                NestboxAttemptForm(boxID: boxID,
                                   season: box.seasons.first { $0.id == ea.seasonID } ?? currentOrNewSeason(for: box),
                                   attempt: ea.attempt)
                .environmentObject(nestboxStore)
            }
        } else {
            Text("Box not found").foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Header

    private func sheetHeader(box: Nestbox) -> some View {
        HStack(spacing: 12) {

            // Cover photo well — tappable to set/replace
            Button { pickCoverPhoto(for: box) } label: {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = coverPhotoImage {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: box.boxType.symbol)
                                    .font(.system(size: 20))
                                    .foregroundStyle(AppColors.primary.opacity(0.6))
                                if box.coverPhotoName == nil {
                                    Text("Add photo")
                                        .font(.system(size: 9))
                                        .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppColors.primary.opacity(0.06))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    // Pencil badge when photo is set
                    if coverPhotoImage != nil {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.primary)
                            .background(Color.white.clipShape(Circle()))
                            .offset(x: 4, y: 4)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(box.name)
                    .font(.title3.weight(.semibold))
                Text(box.boxType.label + (box.entranceHoleMm.map { " · ∅\($0) mm" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Season year pill — teal-bordered stepper
            seasonYearPill

            Button("Edit") { showEditBox = true }
                .buttonStyle(.bordered)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Season year pill

    private var seasonYearPill: some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        return HStack(spacing: 0) {
            Button {
                if seasonYear > currentYear - 5 { seasonYear -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Text(String(seasonYear))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .monospacedDigit()
                .frame(minWidth: 40)

            Button {
                if seasonYear < currentYear { seasonYear += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.primary, lineWidth: 1)
        )
    }

    // MARK: - Right panel (seasons & attempts)

    private func rightPanel(box: Nestbox) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Season header
            HStack {
                Text(seasonYear == Calendar.current.component(.year, from: Date())
                     ? "This Season (\(String(seasonYear)))"
                     : "Season \(String(seasonYear))")
                    .font(.headline)
                Spacer()
                Button {
                    showAddAttempt = true
                } label: {
                    Label("Add Attempt", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if let season = currentSeason, !season.attempts.isEmpty {
                ScrollView {
                    VStack(spacing: 10) {
                        // Season summary pill
                        HStack(spacing: 14) {
                            statPill("Attempts", value: "\(season.attempts.count)")
                            statPill("Eggs laid", value: "\(season.totalEggsLaid)")
                            statPill("Fledged", value: "\(season.totalChicksFledged)")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        ForEach(season.attempts) { attempt in
                            attemptRow(attempt, seasonID: season.id, box: box)
                        }
                    }
                    .padding(.bottom, 16)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "bird")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No attempts recorded for \(String(seasonYear))")
                        .foregroundStyle(.secondary)
                    Button {
                        showAddAttempt = true
                    } label: {
                        Label("Record First Attempt", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Historical seasons
            if !box.seasons.filter({ $0.year != seasonYear }).isEmpty {
                Divider()
                Text("Previous Seasons")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(
                            box.seasons.filter { $0.year != seasonYear }.sorted { $0.year > $1.year }
                        ) { season in
                            pastSeasonPill(season)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Attempt row

    private func attemptRow(_ attempt: NestboxAttempt, seasonID: UUID, box: Nestbox) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: attempt.outcome.symbol)
                    .foregroundStyle(attempt.outcome.isSuccess ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attempt.species.isEmpty ? "Unknown species" : attempt.species)
                        .font(.body.weight(.medium))
                    Text(attempt.outcome.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    if let eggs = attempt.eggsLaid {
                        Label("\(eggs)", systemImage: "circle.dotted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let fledged = attempt.chicksFledged {
                        Label("\(fledged)", systemImage: "feather")
                            .font(.caption)
                            .foregroundStyle(fledged > 0 ? .green : .secondary)
                    }
                }

                Button {
                    editingAttempt = (attempt, seasonID)
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    nestboxStore.deleteAttempt(id: attempt.id, seasonID: seasonID, boxID: boxID)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.7))
            }

            if !attempt.notes.isEmpty {
                Text(attempt.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Historical season pill

    private func pastSeasonPill(_ season: NestboxSeason) -> some View {
        VStack(spacing: 4) {
            Text(String(season.year))
                .font(.caption.weight(.semibold))
            HStack(spacing: 6) {
                Label("\(season.attempts.count)", systemImage: "bird")
                    .font(.system(size: 10))
                Label("\(season.totalChicksFledged)", systemImage: "feather")
                    .font(.system(size: 10))
                    .foregroundStyle(season.totalChicksFledged > 0 ? .green : .secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            season.wasSuccessful
                ? Color.green.opacity(0.1)
                : Color(nsColor: .controlBackgroundColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture { seasonYear = season.year }
    }

    // MARK: - Stat pill

    private func statPill(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Helpers

    private func currentOrNewSeason(for box: Nestbox) -> NestboxSeason {
        box.season(for: seasonYear) ?? NestboxSeason(year: seasonYear)
    }

    private func loadCoverPhoto(for box: Nestbox) {
        guard let name = box.coverPhotoName,
              let url  = MacImageStore.fileURL(for: name) else {
            coverPhotoImage = nil
            return
        }
        coverPhotoImage = NSImage(contentsOf: url)
    }

    private func pickCoverPhoto(for box: Nestbox) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false
        panel.allowedContentTypes     = [.jpeg, .png, .heic, .tiff]
        panel.message                 = "Choose a cover photo for \(box.name)"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }

        // Save a 400 px thumbnail via MacImageStore, store just that filename
        guard let pair = MacImageStore.saveImagePair(data: data) else { return }

        // Delete old cover photo file if one existed
        if let oldName = box.coverPhotoName {
            MacImageStore.deleteFile(filename: oldName)
        }

        var updated = box
        updated.coverPhotoName = pair.thumbnailFilename
        nestboxStore.update(updated)
        // Load immediately so the header updates without waiting for onAppear
        coverPhotoImage = NSImage(data: data)
    }
}

// Needed for .sheet(item:) on a tuple
private struct EditingAttemptID: Identifiable {
    let attempt:  NestboxAttempt
    let seasonID: UUID
    var id: UUID { attempt.id }
}
#endif
