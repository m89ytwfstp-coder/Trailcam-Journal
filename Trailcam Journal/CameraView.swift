//
//  CameraView.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 23/12/2025.
//

import SwiftUI
import UIKit

struct CameraView: View {
    @EnvironmentObject private var store: EntryStore
    @State private var showMyCamerasOnly = false

    private var myCameras: [String] {
        let names = store.entries
            .map { ($0.camera ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

            .filter { !$0.isEmpty }
        return Array(Set(names)).sorted()
    }

    private var camerasToShow: [String] {
        showMyCamerasOnly ? myCameras : CameraCatalog.brands
    }

    private func thumbnailAssetName(for cameraName: String) -> String? {
        let key = cameraName
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if key.contains("zeiss") { return "thumb_zeiss_secacam" }
        if key.contains("browning") { return "thumb_browning" }
        if key.contains("reolink") { return "thumb_reolink" }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background (less “default iOS”)
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {

                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cameras")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(AppColors.primary)

                            Text(showMyCamerasOnly ? "Cameras found in your entries" : "Browse the catalog")
                                .font(.footnote)
                                .foregroundStyle(AppColors.textSecondary)

                        }
                        .padding(.horizontal)
                        .padding(.top, 10)

                        // Filter control (segmented feels more “pro” than a Toggle row)
                        Picker("Filter", selection: $showMyCamerasOnly) {
                            Text("Catalog").tag(false)
                            Text("My cameras").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        if camerasToShow.isEmpty {
                            ContentUnavailableView(
                                "No cameras yet",
                                systemImage: "camera",
                                description: Text("Add entries with a camera name to see them here.")
                            )
                            .padding()
                        } else {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 14),
                                    GridItem(.flexible(), spacing: 14)
                                ],
                                spacing: 14
                            ) {
                                ForEach(camerasToShow, id: \.self) { camera in
                                    NavigationLink {
                                        CameraEntriesView(camera: camera)
                                    } label: {
                                        CameraTileView(
                                            name: camera,
                                            assetName: thumbnailAssetName(for: camera)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .navigationTitle("") // we use our own header
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct CameraTileView: View {
    let name: String
    let assetName: String?

    var body: some View {
        VStack(spacing: 10) {
            
            // Thumbnail (no card)
            ZStack {
                if let assetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 42, weight: .regular))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(height: 110)
            
            // Brand name (centered)
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
            
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // keeps tap area generous
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.primary.opacity(0.15), lineWidth: 1)
        )

    }

}
