//
//  SettingsView.swift
//  Trailcam Journal
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore

    @AppStorage("settings.showDraftsInEntries") private var showDraftsInEntries: Bool = true
    @AppStorage("settings.autoRecenterMap") private var autoRecenterMap: Bool = true
    @AppStorage("settings.clusterListMax") private var clusterListMax: Int = 12

    @State private var confirmDeleteDrafts = false
    @State private var confirmDeleteAllEntries = false
    @State private var confirmClearThumbCache = false
    @State private var confirmClearLocations = false

    // Section 11: live storage stats
    @State private var storageStats: StorageStats? = nil

    private struct StorageStats {
        let photoCount: Int
        let photosMB: Double
        let thumbCacheMB: Double
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    AppHeader(title: "Settings", subtitle: "Preferences and data tools")

                    card(title: "App") {
                        Toggle("Show drafts in Entries", isOn: $showDraftsInEntries)
                        Toggle("Auto recenter map on changes", isOn: $autoRecenterMap)
                    }

                    card(title: "Map") {
                        Stepper(value: $clusterListMax, in: 3...30, step: 1) {
                            HStack {
                                Text("Cluster list max")
                                Spacer()
                                Text("\(clusterListMax)")
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        Text("If a cluster has ≤ this number of entries, tapping it shows the list. Otherwise it zooms in.")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    card(title: "Maintenance") {
                        maintenanceButton(
                            title: "Delete all drafts",
                            systemImage: "trash",
                            role: .destructive
                        ) {
                            confirmDeleteDrafts = true
                        }

                        maintenanceButton(
                            title: "Delete all entries",
                            systemImage: "trash.fill",
                            role: .destructive
                        ) {
                            confirmDeleteAllEntries = true
                        }

                        maintenanceButton(
                            title: "Remove all saved locations",
                            systemImage: "mappin.slash",
                            role: .destructive
                        ) {
                            confirmClearLocations = true
                        }
                    }

                    // Section 11: Storage card
                    card(title: "Storage") {
                        let finalizedCount = store.entries.filter { !$0.isDraft }.count
                        let draftCount     = store.entries.filter {  $0.isDraft }.count

                        statRow("Entries", value: "\(store.entries.count)  (\(finalizedCount) final / \(draftCount) draft)")
                        statRow("Saved locations", value: "\(savedLocationStore.locations.count)")

                        if let stats = storageStats {
                            statRow("Photos on disk", value: "\(stats.photoCount) files  (\(String(format: "%.1f", stats.photosMB)) MB)")
                            statRow("Thumbnail cache", value: "\(String(format: "%.1f", stats.thumbCacheMB)) MB")
                        } else {
                            HStack {
                                Text("Calculating…")
                                    .foregroundStyle(AppColors.textSecondary)
                                    .font(.subheadline)
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }

                        Divider().padding(.vertical, 4)

                        maintenanceButton(
                            title: "Clear thumbnail cache",
                            systemImage: "sparkles",
                            role: .destructive
                        ) {
                            confirmClearThumbCache = true
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .appScreenBackground()
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear { loadStorageStats() }
        }
        .alert("Delete all drafts?", isPresented: $confirmDeleteDrafts) {
            Button("Delete drafts", role: .destructive) {
                store.deleteAllDrafts()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all draft entries. Saved entries are unchanged.")
        }
        .alert("Delete ALL entries?", isPresented: $confirmDeleteAllEntries) {
            Button("Delete everything", role: .destructive) {
                store.deleteAllEntries()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all entries (finalized + drafts). This cannot be undone.")
        }
        .alert("Clear thumbnail cache?", isPresented: $confirmClearThumbCache) {
            Button("Clear cache", role: .destructive) {
#if os(iOS)
                ImageStorage.clearThumbnailCache()
#endif
                loadStorageStats()   // refresh numbers immediately after clearing
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only removes cached thumbnails. Entries remain.")
        }
        .alert("Remove all saved locations?", isPresented: $confirmClearLocations) {
            Button("Remove locations", role: .destructive) {
                savedLocationStore.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all pinned locations. Entries are unchanged.")
        }
    }

    // MARK: - Storage stats helpers (Section 11)

    private func loadStorageStats() {
        Task.detached(priority: .utility) {
            let docs  = FileManager.default.urls(for: .documentDirectory,  in: .userDomainMask).first
            let cache = FileManager.default.urls(for: .cachesDirectory,    in: .userDomainMask).first?
                .appendingPathComponent("TrailcamThumbs")

            let photoBytes = directorySize(docs)
            let cacheBytes = directorySize(cache)
            let photoCount = (try? FileManager.default.contentsOfDirectory(atPath: docs?.path ?? ""))?
                .filter { $0.hasSuffix(".jpg") }.count ?? 0

            await MainActor.run {
                storageStats = StorageStats(
                    photoCount: photoCount,
                    photosMB:   Double(photoBytes) / 1_048_576,
                    thumbCacheMB: Double(cacheBytes) / 1_048_576
                )
            }
        }
    }

    private func directorySize(_ url: URL?) -> Int {
        guard let url else { return 0 }
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        return (enumerator?.compactMap {
            ($0 as? URL).flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
        }.reduce(0, +)) ?? 0
    }

    // MARK: - UI helpers

    @ViewBuilder
    private func card(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.surface.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // Keep Int overload for existing callsites
    private func statRow(_ label: String, value: Int) -> some View {
        statRow(label, value: "\(value)")
    }

    private func maintenanceButton(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24, alignment: .center)

                Text(title)
                    .font(.body)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .tint(.red)
    }

}
