import SwiftUI

struct EntryReviewView: View {
    @EnvironmentObject var store: EntryStore
    @EnvironmentObject var savedLocationStore: SavedLocationStore

    let entryIndex: Int

    @State private var showMapPicker = false
    @State private var showSavedLocationPicker = false

    private var entryBinding: Binding<TrailEntry> {
        $store.entries[entryIndex]
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let entry = store.entries[entryIndex]
        let savedName = savedLocationName(for: entry)

        Form {
            Section {
                EntryPhotoView(entry: entry, height: 220, cornerRadius: 14, maxPixel: 1200)
                    .padding(.vertical, 6)
            }

            Section("Required") {
                Picker(
                    "Species",
                    selection: Binding<String>(
                        get: { store.entries[entryIndex].species ?? "" },
                        set: { newValue in
                            store.entries[entryIndex].species = newValue.isEmpty ? nil : newValue
                        }
                    )
                ) {
                    Text("— Select —").tag("")
                    ForEach(SpeciesCatalog.all) { s in
                        Text(s.nameNO).tag(s.nameNO)
                    }
                }

                Toggle("Mark location as unknown", isOn: entryBinding.locationUnknown)

                if !store.entries[entryIndex].locationUnknown {
                    Button("Choose saved location") {
                        showSavedLocationPicker = true
                    }

                    Button("Pick location on map") {
                        showMapPicker = true
                    }

                    if let name = savedName {
                        Text("Saved location: \(name)")
                    }

                    if let lat = store.entries[entryIndex].latitude,
                       let lon = store.entries[entryIndex].longitude {
                        Text("Lat: \(lat)")
                        Text("Lon: \(lon)")
                    } else {
                        Text("No location set")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        store.entries[entryIndex].latitude = nil
                        store.entries[entryIndex].longitude = nil
                        store.entries[entryIndex].locationUnknown = false
                    } label: {
                        Text("Clear location")
                    }
                }
            }

            Section("Optional") {
                Picker(
                    "Camera",
                    selection: Binding<String>(
                        get: { store.entries[entryIndex].camera ?? CameraCatalog.unknown },
                        set: { newValue in
                            store.entries[entryIndex].camera = (newValue == CameraCatalog.unknown) ? nil : newValue
                        }
                    )
                ) {
                    ForEach(CameraCatalog.all, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                TextField("Notes", text: entryBinding.notes)
            }

            Section {
                Button {
                    if store.entries[entryIndex].canFinalize {
                        store.entries[entryIndex].isDraft = false
                        dismiss()
                    }
                } label: {
                    Text("Finalize Entry")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(!store.entries[entryIndex].canFinalize)
            } footer: {
                if !store.entries[entryIndex].canFinalize {
                    Text("To finalize: choose a species and set a location (or mark location as unknown).")
                }
            }
        }
        .navigationTitle("Review Entry")
        .sheet(isPresented: $showMapPicker) {
            MapLocationPickerView(
                latitude: entryBinding.latitude,
                longitude: entryBinding.longitude
            )
        }
        .sheet(isPresented: $showSavedLocationPicker) {
            SavedLocationPickerView { loc in
                store.entries[entryIndex].locationUnknown = false
                store.entries[entryIndex].latitude = loc.latitude
                store.entries[entryIndex].longitude = loc.longitude
            }
        }
    }

    private func savedLocationName(for entry: TrailEntry) -> String? {
        guard let lat = entry.latitude, let lon = entry.longitude else { return nil }

        let rLat = (lat * 10000).rounded() / 10000
        let rLon = (lon * 10000).rounded() / 10000

        return savedLocationStore.locations.first { loc in
            let lrLat = (loc.latitude * 10000).rounded() / 10000
            let lrLon = (loc.longitude * 10000).rounded() / 10000
            return lrLat == rLat && lrLon == rLon
        }?.name
    }
}
