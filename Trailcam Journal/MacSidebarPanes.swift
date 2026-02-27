import SwiftUI
import AppKit
import Charts
import MapKit

#if os(macOS)
private struct MapEditorSelection: Identifiable {
    let id: UUID
}

enum MacMapPaneLogic {
    static func applyFilters(entries: [TrailEntry], selectedSpecies: String?, selectedCamera: String?) -> [TrailEntry] {
        entries.filter { entry in
            let speciesMatches: Bool = {
                guard let selectedSpecies, !selectedSpecies.isEmpty else { return true }
                return (entry.species ?? "") == selectedSpecies
            }()
            let cameraMatches: Bool = {
                guard let selectedCamera, !selectedCamera.isEmpty else { return true }
                return (entry.camera ?? "") == selectedCamera
            }()
            return speciesMatches && cameraMatches
        }
    }
}

struct MacMapPane: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var selectedEntryID: UUID?
    @State private var selectedSpecies: String = ""
    @State private var selectedCamera: String = ""
    @State private var editorSelection: MapEditorSelection?

    private var geotaggedEntries: [TrailEntry] {
        store.entries
            .filter { !$0.isDraft && $0.latitude != nil && $0.longitude != nil }
            .sorted { $0.date > $1.date }
    }

    private var speciesOptions: [String] {
        Array(
            Set(geotaggedEntries.compactMap { $0.species?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        ).sorted()
    }

    private var cameraOptions: [String] {
        Array(
            Set(geotaggedEntries.compactMap { $0.camera?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        ).sorted()
    }

    private var filteredEntries: [TrailEntry] {
        MacMapPaneLogic.applyFilters(
            entries: geotaggedEntries,
            selectedSpecies: selectedSpecies.isEmpty ? nil : selectedSpecies,
            selectedCamera: selectedCamera.isEmpty ? nil : selectedCamera
        )
    }

    private struct EntryPin: Identifiable {
        let id: UUID
        let title: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D
    }

    private var entryPins: [EntryPin] {
        filteredEntries.compactMap { entry in
            guard let lat = entry.latitude, let lon = entry.longitude else { return nil }
            return EntryPin(
                id: entry.id,
                title: entry.species ?? "Unknown species",
                subtitle: entry.date.formatted(date: .abbreviated, time: .shortened),
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
            )
        }
    }

    private var selectedEntry: TrailEntry? {
        guard let selectedEntryID else { return nil }
        return filteredEntries.first(where: { $0.id == selectedEntryID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppHeader(
                title: "Map",
                subtitle: "\(filteredEntries.count) / \(geotaggedEntries.count) entries shown"
            )

            mapFilterBar
                .padding(.horizontal)

            if geotaggedEntries.isEmpty {
                MacPaneEmptyState(
                    title: "No mapped entries",
                    systemImage: "map",
                    message: "Add coordinates to finalized entries and they will appear as pins here."
                )
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredEntries.isEmpty {
                MacPaneEmptyState(
                    title: "No matching pins",
                    systemImage: "line.3.horizontal.decrease.circle",
                    message: "Try clearing camera/species filters to show all mapped entries."
                )
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    mapCard
                        .padding(.horizontal)

                    if let selectedEntry {
                        selectedEntryCard(selectedEntry)
                            .padding(.horizontal)
                    } else {
                        Text("Click a pin to inspect an entry")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal)
                    }
                }
                .onAppear {
                    recenterToPins()
                }
                .onChange(of: entryPins.map(\.id)) { _, _ in
                    recenterToPins()
                }
                .onChange(of: filteredEntries.map(\.id)) { _, ids in
                    if let selectedEntryID, !ids.contains(selectedEntryID) {
                        self.selectedEntryID = nil
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appScreenBackground()
        .sheet(item: $editorSelection) { selection in
            MacEntryEditorPane(entryID: selection.id)
        }
    }

    private var mapFilterBar: some View {
        MacPaneCard(compact: true) {
            HStack(spacing: 10) {
                Picker("Species", selection: $selectedSpecies) {
                    Text("All species").tag("")
                    ForEach(speciesOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Camera", selection: $selectedCamera) {
                    Text("All cameras").tag("")
                    ForEach(cameraOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                if !selectedSpecies.isEmpty || !selectedCamera.isEmpty {
                    Button("Clear Filters") {
                        selectedSpecies = ""
                        selectedCamera = ""
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private var mapCard: some View {
        MacPaneCard(compact: true) {
            Map(position: $mapPosition) {
                ForEach(entryPins) { pin in
                    Annotation(pin.title, coordinate: pin.coordinate) {
                        Button {
                            selectedEntryID = pin.id
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(selectedEntryID == pin.id ? AppColors.primary.opacity(0.15) : Color.clear)
                                    .frame(width: 38, height: 38)
                                Image(systemName: selectedEntryID == pin.id ? "mappin.circle.fill" : "mappin.circle")
                                    .font(selectedEntryID == pin.id ? .title : .title2)
                                    .foregroundStyle(selectedEntryID == pin.id ? AppColors.primary : AppColors.primary.opacity(0.85))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                ForEach(savedLocationStore.locations) { location in
                    Annotation(location.name, coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                        Image(systemName: "bookmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange.opacity(0.95))
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(minHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button {
                    recenterToPins()
                } label: {
                    Label("Recenter", systemImage: "scope")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .padding(10)
            }
        }
    }

    private func selectedEntryCard(_ entry: TrailEntry) -> some View {
        MacPaneCard(compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                MacPaneSectionHeader(entry.species ?? "Unknown species", subtitle: entry.date.formatted(date: .abbreviated, time: .shortened))

                if let camera = entry.camera, !camera.isEmpty {
                    MacPanePill(text: camera, systemImage: "camera")
                }

                if let lat = entry.latitude, let lon = entry.longitude {
                    HStack {
                        Text(String(format: "%.5f, %.5f", lat, lon))
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        Spacer()

                        Button("Open Entry") {
                            editorSelection = MapEditorSelection(id: entry.id)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Open in Maps") {
                            openInMaps(latitude: lat, longitude: lon)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func recenterToPins() {
        guard !entryPins.isEmpty else { return }
        let lats = entryPins.map { $0.coordinate.latitude }
        let lons = entryPins.map { $0.coordinate.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0, longitude: (minLon + maxLon) / 2.0)
        let latDelta = max(0.04, (maxLat - minLat) * 1.5)
        let lonDelta = max(0.04, (maxLon - minLon) * 1.5)

        mapPosition = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        )
    }

    private func openInMaps(latitude: Double, longitude: Double) {
        let urlString = "https://maps.apple.com/?ll=\(latitude),\(longitude)"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

struct MacStatsPane: View {
    @EnvironmentObject private var store: EntryStore

    @State private var timeframe: StatsTimeframe = .last30
    @State private var selectedCamera: String = ""
    @State private var trendMode: TrendMode = .entries
    @State private var timeOfDayMode: TimeOfDayMode = .histogram24h

    private var cameraOptions: [String] {
        let names = Set(
            store.entries.compactMap { entry in
                let trimmed = (entry.camera ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        )
        return Array(names).sorted()
    }

    private var filteredEntries: [TrailEntry] {
        StatsHelpers.filterFinalEntries(
            store.entries,
            timeframe: timeframe,
            selectedCamera: selectedCamera.isEmpty ? nil : selectedCamera
        )
    }

    private var metric: StatsMetric {
        StatsHelpers.metrics(from: filteredEntries)
    }

    private var topSpecies: [RankedCount] {
        StatsHelpers.topSpecies(entries: filteredEntries, limit: 5)
    }

    private var topCameras: [RankedCount] {
        StatsHelpers.topCameras(entries: filteredEntries, limit: 5)
    }

    private var trendDataPoints: [StatsBarPoint] {
        let calendar = Calendar.current
        let now = Date()

        switch timeframe {
        case .last7:
            return trendMode == .entries
            ? StatsHelpers.dailyCounts(lastDays: 7, entries: filteredEntries, now: now, calendar: calendar)
            : StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 7, entries: filteredEntries, now: now, calendar: calendar)
        case .last30:
            return trendMode == .entries
            ? StatsHelpers.dailyCounts(lastDays: 30, entries: filteredEntries, now: now, calendar: calendar)
            : StatsHelpers.uniqueSpeciesDailyCounts(lastDays: 30, entries: filteredEntries, now: now, calendar: calendar)
        case .thisYear:
            let year = calendar.component(.year, from: now)
            return trendMode == .entries
            ? StatsHelpers.monthlyCounts(year: year, entries: filteredEntries, calendar: calendar)
            : StatsHelpers.uniqueSpeciesMonthlyCounts(year: year, entries: filteredEntries, calendar: calendar)
        case .allTime:
            return StatsHelpers.weeklyCounts(lastWeeks: 12, entries: filteredEntries, now: now, calendar: calendar)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppHeader(
                title: "Stats",
                subtitle: "\(filteredEntries.count) entries in current filter"
            )

            MacPaneCard(compact: true) {
                HStack(spacing: 12) {
                    Picker("Timeframe", selection: $timeframe) {
                        ForEach(StatsTimeframe.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Camera", selection: $selectedCamera) {
                        Text("All cameras").tag("")
                        ForEach(cameraOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()

                    MacPanePill(text: timeframe.rawValue, systemImage: "calendar")
                }
            }
            .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        statCard("Entries", "\(metric.entries)")
                        statCard("Active Days", "\(metric.activeDays)")
                        statCard("Species", "\(metric.uniqueSpecies)")
                        statCard("Locations", "\(metric.uniqueLocations)")
                        statCard("Cameras", "\(metric.uniqueCameras)")
                    }

                    trendSection
                    timeOfDaySection
                    rankingSection(title: "Top Species", items: topSpecies, emptyText: "No species yet")
                    rankingSection(title: "Top Cameras", items: topCameras, emptyText: "No cameras yet")
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appScreenBackground()
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        MacPaneCard(compact: true) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MacPaneSectionHeader("Trend")
            .padding(.top, 8)

            Picker("Trend Mode", selection: $trendMode) {
                ForEach(TrendMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if trendDataPoints.isEmpty {
                Text("No data in this timeframe")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                chartContainer {
                    Chart(trendDataPoints) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Count", point.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.primary.opacity(0.30), AppColors.primary.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Count", point.count)
                        )
                        .foregroundStyle(AppColors.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                            AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(preset: .aligned, position: .bottom, values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                            AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(trendXAxisLabel(for: date))
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                        }
                    }
                    .frame(height: 190)
                }

                if let peak = trendDataPoints.max(by: { $0.count < $1.count }), peak.count > 0 {
                    Text("Peak: \(peak.count) on \(trendXAxisLabel(for: peak.date))")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var timeOfDaySection: some View {
        let histogram = StatsHelpers.hourHistogram(entries: filteredEntries)
        let dayNightCounts = StatsHelpers.dayNightCounts(entries: filteredEntries)
        let total = histogram.reduce(0, +)

        return VStack(alignment: .leading, spacing: 8) {
            MacPaneSectionHeader("Time of Day")
            .padding(.top, 8)

            Picker("Time of day mode", selection: $timeOfDayMode) {
                ForEach(TimeOfDayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch timeOfDayMode {
            case .histogram24h:
                if total == 0 {
                    Text("No data in this timeframe")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.vertical, 8)
                } else {
                    chartContainer {
                        Chart(Array(histogram.enumerated()), id: \.offset) { item in
                            BarMark(
                                x: .value("Hour", item.offset),
                                y: .value("Count", item.element)
                            )
                            .cornerRadius(3)
                            .foregroundStyle(AppColors.primary.opacity(0.85))
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                AxisValueLabel()
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                                AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                AxisValueLabel {
                                    if let hour = value.as(Int.self) {
                                        Text("\(hour)")
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                            }
                        }
                        .frame(height: 190)
                    }

                    if let peak = histogram.enumerated().max(by: { $0.element < $1.element }), peak.element > 0 {
                        Text("Most active: ~\(peak.offset):00 (\(peak.element) entries)")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

            case .dayNight:
                let dayNightTotal = dayNightCounts.day + dayNightCounts.night
                if dayNightTotal == 0 {
                    Text("No data in this timeframe")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.vertical, 8)
                } else {
                    let points = [
                        RankedCount(name: "Day", count: dayNightCounts.day),
                        RankedCount(name: "Night", count: dayNightCounts.night)
                    ]

                    chartContainer {
                        Chart(points) { point in
                            BarMark(
                                x: .value("Part", point.name),
                                y: .value("Count", point.count)
                            )
                            .cornerRadius(7)
                            .foregroundStyle(by: .value("Part", point.name))
                        }
                        .chartForegroundStyleScale([
                            "Day": AppColors.primary.opacity(0.85),
                            "Night": AppColors.primary.opacity(0.55)
                        ])
                        .chartYAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                AxisValueLabel()
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(position: .bottom) { _ in
                                AxisGridLine().foregroundStyle(AppColors.primary.opacity(0.08))
                                AxisTick().foregroundStyle(AppColors.primary.opacity(0.25))
                                AxisValueLabel()
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .frame(height: 190)
                    }

                    let dayPct = Int((Double(dayNightCounts.day) / Double(dayNightTotal)) * 100)
                    let nightPct = 100 - dayPct
                    Text("Day: \(dayNightCounts.day) (\(dayPct)%) • Night: \(dayNightCounts.night) (\(nightPct)%)")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func chartContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }

    private func trendXAxisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        switch timeframe {
        case .last7:
            formatter.dateFormat = "EEE"
        case .last30:
            formatter.dateFormat = "d MMM"
        case .thisYear:
            formatter.dateFormat = "MMM"
        case .allTime:
            formatter.dateFormat = "d MMM"
        }

        return formatter.string(from: date)
    }

    private func rankingSection(title: String, items: [RankedCount], emptyText: String) -> some View {
        MacPaneCard(compact: true) {
            VStack(alignment: .leading, spacing: 8) {
                MacPaneSectionHeader(title)

                if items.isEmpty {
                    Text(emptyText)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    ForEach(items) { item in
                        HStack {
                            Text(item.name)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.count)")
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }
}

struct MacMorePane: View {
    @EnvironmentObject private var store: EntryStore
    @EnvironmentObject private var savedLocationStore: SavedLocationStore

    @State private var confirmDeleteDrafts = false
    @State private var confirmDeleteEntries = false
    @State private var confirmClearLocations = false

    private var draftCount: Int {
        store.entries.filter { $0.isDraft }.count
    }

    private var finalizedCount: Int {
        store.entries.filter { !$0.isDraft }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppHeader(
                title: "More",
                subtitle: "Maintenance and project info"
            )

            MacPaneCard {
                VStack(alignment: .leading, spacing: 8) {
                    MacPaneSectionHeader("Data Overview")
                    Text("Drafts: \(draftCount)")
                    Text("Finalized entries: \(finalizedCount)")
                    Text("Saved locations: \(savedLocationStore.locations.count)")
                }
            }
            .padding(.horizontal)

            MacPaneCard(compact: true) {
                HStack(spacing: 10) {
                    Button("Delete Drafts", role: .destructive) {
                        confirmDeleteDrafts = true
                    }
                    .disabled(draftCount == 0)

                    Button("Delete All Entries", role: .destructive) {
                        confirmDeleteEntries = true
                    }
                    .disabled(store.entries.isEmpty)

                    Button("Clear Locations", role: .destructive) {
                        confirmClearLocations = true
                    }
                    .disabled(savedLocationStore.locations.isEmpty)

                    Spacer()
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appScreenBackground()
        .alert("Delete all drafts?", isPresented: $confirmDeleteDrafts) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteAllDrafts()
            }
        } message: {
            Text("Only drafts will be removed.")
        }
        .alert("Delete all entries?", isPresented: $confirmDeleteEntries) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteAllEntries()
            }
        } message: {
            Text("This removes all drafts and finalized entries.")
        }
        .alert("Clear all saved locations?", isPresented: $confirmClearLocations) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                savedLocationStore.clearAll()
            }
        } message: {
            Text("Entries remain unchanged.")
        }
    }
}

struct MacBucketListPane: View {
    @EnvironmentObject private var store: EntryStore

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 12)]

    private var firstSightingByID: [String: Date] {
        BucketListLogic.firstSightingBySpeciesID(from: store.entries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppHeader(
                title: "Bucket List",
                subtitle: "Unlock species with first sightings"
            )

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(SpeciesCatalog.all) { species in
                        let firstDate = firstSightingByID[species.id]
                        MacBucketSpeciesTile(species: species, firstSightingDate: firstDate)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appScreenBackground()
    }
}

private struct MacBucketSpeciesTile: View {
    let species: Species
    let firstSightingDate: Date?

    private var isSeen: Bool {
        firstSightingDate != nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(species.thumbnailName)
                .resizable()
                .scaledToFill()
                .scaleEffect(1.25)
                .frame(maxWidth: .infinity, minHeight: 116)
                .clipped()
                .opacity(isSeen ? 1.0 : 0.35)

            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(species.nameNO)
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                    if let firstSightingDate {
                        Text(firstSightingDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.black.opacity(0.7))
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.0), Color.white.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            if isSeen {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.black)
                    .padding(6)
                    .background(Circle().fill(Color.white.opacity(0.85)))
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.35), lineWidth: 1.8)
        )
    }
}
#endif
