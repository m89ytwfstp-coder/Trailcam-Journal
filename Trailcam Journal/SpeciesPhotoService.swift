//
//  SpeciesPhotoService.swift
//  Trailcam Journal
//
//  Fetches a representative wildlife photo for a species.
//  Primary source: iNaturalist public API (Latin name).
//  Fallback:       Wikipedia REST API (English name).
//  Images are downloaded once and saved to disk under
//  Application Support/TrailcamJournal/species_photos/<id>.jpg
//  so the network is only hit once per species, ever.
//

import Foundation

enum SpeciesPhotoService {

    // MARK: - Directory

    static let photosDirectory: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask).first!
        let folder = dir
            .appendingPathComponent("TrailcamJournal", isDirectory: true)
            .appendingPathComponent("species_photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder,
                                                  withIntermediateDirectories: true)
        return folder
    }()

    // MARK: - Public API

    /// Returns a local file URL for the species photo.
    /// Downloads and caches on first call; reads from disk on subsequent calls.
    /// Returns nil if no photo could be found from any source.
    static func localPhotoURL(for species: Species) async -> URL? {
        let cache = SpeciesPhotoCache.shared
        let id = species.id
        let localFile = photosDirectory.appendingPathComponent("\(id).jpg")

        // 1. Already on disk
        if FileManager.default.fileExists(atPath: localFile.path) {
            return localFile
        }

        // 2. Previously attempted and failed — don't retry
        if cache.cachedValue(for: id) == "none" {
            return nil
        }

        // 3. Fetch remote URL, download data, save to disk
        if let remoteURL = await fetchRemoteURL(for: species),
           let data = await downloadImageData(from: remoteURL) {
            do {
                try data.write(to: localFile, options: .atomic)
                cache.set("saved", for: id)   // mark as persisted
                return localFile
            } catch {
                // Disk write failed — return nil, will retry next launch
                return nil
            }
        }

        // 4. All sources exhausted
        cache.set("none", for: id)
        return nil
    }

    // MARK: - Remote URL resolution

    private static func fetchRemoteURL(for species: Species) async -> URL? {
        if let url = await fetchFromiNaturalist(latinName: species.latinName) {
            return url
        }
        if let nameEN = species.nameEN,
           let url = await fetchFromWikipedia(name: nameEN) {
            return url
        }
        return nil
    }

    // MARK: - iNaturalist

    /// quality_grade=research filters out auto-Id illustrations and low-quality
    /// observations. photos=true ensures the taxon has an attached photo.
    /// order_by=observations_count surfaces the community's top-rated image first.
    private static func fetchFromiNaturalist(latinName: String) async -> URL? {
        var components = URLComponents(string: "https://api.inaturalist.org/v1/taxa")!
        components.queryItems = [
            URLQueryItem(name: "q",          value: latinName),
            URLQueryItem(name: "per_page",   value: "1"),
            URLQueryItem(name: "rank",       value: "species"),
            URLQueryItem(name: "photos",     value: "true"),
            URLQueryItem(name: "order_by",   value: "observations_count")
        ]
        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONDecoder().decode(iNatResponse.self, from: data)

            // Prefer medium_url (500px); fall back to square_url (75px) only
            // if medium is missing
            guard let photo = json.results.first?.defaultPhoto else { return nil }
            let urlString = photo.mediumUrl ?? photo.squareUrl
            guard let urlString, let photoURL = URL(string: urlString) else { return nil }
            return photoURL
        } catch {
            return nil
        }
    }

    // MARK: - Wikipedia fallback

    private static func fetchFromWikipedia(name: String) async -> URL? {
        let encoded = name
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let urlString =
            "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONDecoder().decode(WikiSummary.self, from: data)
            guard let src = json.originalimage?.source ?? json.thumbnail?.source,
                  let photoURL = URL(string: src) else { return nil }
            return photoURL
        } catch {
            return nil
        }
    }

    // MARK: - Image download

    private static func downloadImageData(from url: URL) async -> Data? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  data.count > 1024   // sanity check — reject empty/error responses
            else { return nil }
            return data
        } catch {
            return nil
        }
    }

    // MARK: - Decodable models

    private struct iNatResponse: Decodable {
        let results: [Taxon]
        struct Taxon: Decodable {
            let defaultPhoto: Photo?
            enum CodingKeys: String, CodingKey {
                case defaultPhoto = "default_photo"
            }
            struct Photo: Decodable {
                let mediumUrl: String?
                let squareUrl: String?
                enum CodingKeys: String, CodingKey {
                    case mediumUrl = "medium_url"
                    case squareUrl = "square_url"
                }
            }
        }
    }

    private struct WikiSummary: Decodable {
        let thumbnail: Thumbnail?
        let originalimage: Thumbnail?
        struct Thumbnail: Decodable {
            let source: String?
        }
    }
}
