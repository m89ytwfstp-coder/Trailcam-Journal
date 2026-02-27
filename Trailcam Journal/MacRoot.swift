import SwiftUI

#if os(macOS)
struct ContentViewMac: View {
    enum SidebarSection: String, CaseIterable, Identifiable {
        case importQueue = "Import"
        case entries = "Entries"
        case map = "Map"
        case stats = "Stats"
        case bucketList = "Bucket List"
        case more = "More"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .importQueue: return "square.and.arrow.down"
            case .entries: return "list.bullet"
            case .map: return "map"
            case .stats: return "chart.bar"
            case .bucketList: return "checklist"
            case .more: return "ellipsis"
            }
        }
    }

    @State private var selection: SidebarSection = .importQueue

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                AppHeader(
                    title: "Trailcam Journal",
                    subtitle: "macOS native workspace"
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(SidebarSection.allCases) { item in
                            Button {
                                selection = item
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: item.symbol)
                                        .font(.headline)
                                        .frame(width: 20)
                                    Text(item.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                }
                                .foregroundStyle(selection == item ? Color.white : AppColors.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selection == item ? AppColors.primary : AppColors.primary.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }
            .appScreenBackground()
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .importQueue:
            MacImportPane()
        case .entries:
            MacEntriesPane()
        case .map:
            MacMapPane()
        case .stats:
            MacStatsPane()
        case .bucketList:
            MacBucketListPane()
        case .more:
            MacMorePane()
        }
    }

    private func placeholder(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
