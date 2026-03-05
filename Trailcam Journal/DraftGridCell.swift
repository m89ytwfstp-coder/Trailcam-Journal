//
//  DraftGridCell.swift
//  Trailcam Journal
//
//  Extracted from ImportWorkflowView to keep view files focused.
//

import SwiftUI

// MARK: - DraftStatus

enum DraftStatus {
    case missingSpecies
    case missingLocation
    case ready

    var title: String {
        switch self {
        case .missingSpecies: return "Missing species"
        case .missingLocation: return "Missing location"
        case .ready: return "Ready to finalize"
        }
    }

    var badgeBackground: Color {
        switch self {
        case .ready:        return AppColors.primary.opacity(0.90)
        case .missingSpecies: return Color.orange.opacity(0.92)
        case .missingLocation: return Color.blue.opacity(0.85)
        }
    }

    var badgeForeground: Color { Color.white }
}

// MARK: - DraftGridCell

struct DraftGridCell: View {
    let entry: TrailEntry
    let status: DraftStatus
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.04))

            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    EntryPhotoView(entry: entry, height: 100, cornerRadius: 14, maxPixel: 320)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(status.title)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(status.badgeBackground)
                        .foregroundStyle(status.badgeForeground)
                        .clipShape(Capsule())
                        .padding(6)
                }

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(10)

            // Selection ring
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 3)
                .padding(2)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(height: 160)
    }
}
