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
