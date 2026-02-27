//
//  AppUI.swift
//  Trailcam Journal
//
//  Created by Simon Gervais on 05/01/2026.
//

import SwiftUI

struct AppHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.primary)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

extension View {
    func appScreenBackground() -> some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            self
        }
        .tint(AppColors.primary)
    }
}

#if os(macOS)
struct MacPaneCard<Content: View>: View {
    let compact: Bool
    @ViewBuilder let content: Content

    init(compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        content
            .padding(compact ? 10 : 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.76))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColors.primary.opacity(0.10), lineWidth: 1)
                    )
            )
    }
}

struct MacPaneSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.primary)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}

struct MacPanePill: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(AppColors.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppColors.primary.opacity(0.10))
                .overlay(
                    Capsule()
                        .stroke(AppColors.primary.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct MacPaneSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.primary.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

struct MacPaneEmptyState: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        MacPaneCard {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(message)
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        }
    }
}
#endif
