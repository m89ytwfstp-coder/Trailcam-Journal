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
                            title: "Clear thumbnail cache",
                            systemImage: "sparkles",
                            role: .destructive
                        ) {
                            confirmClearThumbCache = true
                        }

                        maintenanceButton(
                            title: "Remove all saved locations",
                            systemImage: "mappin.slash",
                            role: .destructive
                        ) {
                            confirmClearLocations = true
                        }

                        Divider().padding(.vertical, 4)

                        statRow("Entries total", value: store.entries.count)
                        statRow("Drafts", value: store.entries.filter { $0.isDraft }.count)
                        statRow("Saved locations", value: savedLocationStore.locations.count)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .appScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
                ImageStorage.clearThumbnailCache()
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

    private func statRow(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .foregroundStyle(AppColors.textSecondary)
        }
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
        .tint(.red) // makes icon + text match in a consistent destructive style
    }

}
