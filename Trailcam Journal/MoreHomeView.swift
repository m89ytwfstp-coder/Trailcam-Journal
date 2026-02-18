import SwiftUI

struct MoreHomeView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                AppHeader(
                    title: "More",
                    subtitle: "Other sections"
                )

                VStack(spacing: 12) {

                    // ✅ Camera lives under More now (since it's not a home tab)
                    NavigationLink {
                        CameraView()   // or CameraView() — use the one you already have
                    } label: {
                        MoreRow(title: "Camera", systemImage: "camera", subtitle: "Browse photos by camera")
                    }

                    NavigationLink {
                        BucketListTabView()
                    } label: {
                        MoreRow(title: "Bucketlist", systemImage: "checklist", subtitle: "Your species checklist")
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        MoreRow(title: "Settings", systemImage: "gearshape", subtitle: "Preferences and data tools")
                    }
                }

                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 2)
            .appScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MoreRow: View {
    let title: String
    let systemImage: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppColors.primary.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
