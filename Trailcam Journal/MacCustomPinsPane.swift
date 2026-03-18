
//
//  MacCustomPinsPane.swift
//  Trailcam Journal
//
//  Sidebar list view for custom pins — Task 4 of MapPins-v1.
//

#if os(macOS)
import SwiftUI

struct MacCustomPinsPane: View {

    @EnvironmentObject private var customPinStore: CustomPinStore

    /// Called when the user taps a row — navigate to map with this pin focused.
    var onNavigateToPin: (UUID) -> Void = { _ in }

    @State private var categoryFilter: CustomPinCategory? = nil   // nil = All
    @State private var activeOnly = false

    private var filteredPins: [CustomPin] {
        customPinStore.pins
            .filter { pin in
                if let cat = categoryFilter, pin.type.category != cat { return false }
                if activeOnly && !pin.isActive { return false }
                return true
            }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            pinList
        }
        .navigationTitle("Pins")
        .appScreenBackground()
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 10) {

            // Category filter
            Picker("Category", selection: $categoryFilter) {
                Text("All").tag(CustomPinCategory?.none)
                ForEach(CustomPinCategory.allCases, id: \.self) { cat in
                    Text(cat.displayName).tag(CustomPinCategory?.some(cat))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
            .labelsHidden()

            Spacer()

            // Active only toggle
            Toggle("Active only", isOn: $activeOnly)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.subheadline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Pin list

    private var pinList: some View {
        Group {
            if filteredPins.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "mappin.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(customPinStore.pins.isEmpty
                         ? "No pins yet.\nLong-press on the map to place one."
                         : "No pins match this filter.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredPins) { pin in
                    PinRow(pin: pin)
                        .contentShape(Rectangle())
                        .onTapGesture { onNavigateToPin(pin.id) }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.white)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
            }
        }
    }
}

// MARK: - PinRow

private struct PinRow: View {
    let pin: CustomPin

    var body: some View {
        HStack(spacing: 10) {

            // Diamond icon
            DiamondPinBadge(type: pin.type, size: 30)
                .opacity(pin.isActive ? 1.0 : 0.45)

            // Name + type label
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(pin.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(pin.isActive ? AppColors.textPrimary : .secondary)
                        .lineLimit(1)
                    if !pin.isActive {
                        Text("Inactive")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 5) {
                    Text(pin.type.displayName)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(pin.type.category.displayName)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            // Date added
            Text(pin.dateAdded.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.tertiary)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 5)
        .opacity(pin.isActive ? 1.0 : 0.6)
    }
}

// MARK: - DiamondPinBadge (shared)

/// A colored diamond shape with the pin type's SF Symbol, used on the map and in list rows.
struct DiamondPinBadge: View {
    let type: CustomPinType
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Rectangle()
                .fill(type.color)
                .frame(width: size * 0.75, height: size * 0.75)
                .rotationEffect(.degrees(45))
                .clipShape(Rectangle())

            Image(systemName: type.sfSymbol)
                .font(.system(size: size * 0.33, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
#endif
