
//
//  CustomPinStore.swift
//  Trailcam Journal
//
//  Persists CustomPin objects to JSON in Application Support,
//  following the same StorageEnvelope pattern as TripStore and NestboxStore.
//

import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

@MainActor
final class CustomPinStore: ObservableObject {

    private static let jsonFilename         = "custompins.json"
    private static let appSupportDir        = "TrailcamJournal"
    private static let currentSchemaVersion = 1

    private struct StorageEnvelope: Codable {
        let schemaVersion: Int
        let pins: [CustomPin]
    }

    @Published var pins: [CustomPin] = [] {
        didSet { save() }
    }

    init() { load() }

    // MARK: - Mutations

    func add(_ pin: CustomPin) {
        pins.append(pin)
    }

    func update(_ pin: CustomPin) {
        guard let i = pins.firstIndex(where: { $0.id == pin.id }) else { return }
        pins[i] = pin
    }

    func delete(id: UUID) {
        // Delete associated photo before removing the pin record
        if let pin = pins.first(where: { $0.id == id }),
           let filename = pin.photoFilename {
            Self.deletePhoto(filename: filename)
        }
        pins.removeAll { $0.id == id }
    }

    // MARK: - Photo storage

    static let photosSubdir = "pinphotos"

    static func photoDirectoryURL() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(appSupportDir, isDirectory: true)
            .appendingPathComponent(photosSubdir, isDirectory: true)
    }

    static func photoURL(filename: String) -> URL? {
        photoDirectoryURL()?.appendingPathComponent(filename)
    }

    #if os(macOS)
    /// Saves JPEG data to the pinphotos directory and returns the filename, or nil on failure.
    static func savePhoto(_ image: NSImage) -> String? {
        guard let dir = photoDirectoryURL() else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let tiff = image.tiffRepresentation,
              let rep  = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let url = dir.appendingPathComponent(filename)
        do {
            try jpeg.write(to: url, options: .atomic)
            return filename
        } catch {
            print("❌ CustomPinStore: photo save failed: \(error)")
            return nil
        }
    }

    /// Loads an NSImage for a given photo filename, or nil if not found.
    static func loadPhoto(filename: String) -> NSImage? {
        guard let url = photoURL(filename: filename) else { return nil }
        return NSImage(contentsOf: url)
    }
    #endif

    static func deletePhoto(filename: String) {
        guard let url = photoURL(filename: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Persistence

    private func dataFileURL() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.appSupportDir, isDirectory: true)
            .appendingPathComponent(Self.jsonFilename)
    }

    private func ensureDirectory() {
        guard let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.appSupportDir, isDirectory: true)
        else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func save() {
        ensureDirectory()
        guard let url = dataFileURL() else { return }
        let envelope = StorageEnvelope(schemaVersion: Self.currentSchemaVersion, pins: pins)
        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ CustomPinStore save failed: \(error)")
        }
    }

    private func load() {
        guard let url  = dataFileURL(),
              let data = try? Data(contentsOf: url) else { return }
        if let envelope = try? JSONDecoder().decode(StorageEnvelope.self, from: data) {
            pins = envelope.pins
            return
        }
        print("❌ CustomPinStore load failed")
    }
}
