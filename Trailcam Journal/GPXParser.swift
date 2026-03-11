//
//  GPXParser.swift
//  Trailcam Journal
//
//  Parses a standard Garmin GPX file into a Trip value using Foundation.XMLParser.
//  No third-party libraries. Mac-only (GPX export from Garmin Connect is browser-based).
//

#if os(macOS)
import Foundation

final class GPXParser: NSObject, XMLParserDelegate {

    // MARK: - Public entry point

    /// Parse `data` as GPX and return a `Trip`.
    /// `fallbackName` is used when the GPX contains no `<name>` element.
    /// The returned trip has `gpxFilename = ""` — the caller sets it after saving the file.
    static func parse(data: Data, fallbackName: String) -> Trip? {
        let handler = GPXParser()
        let parser  = XMLParser(data: data)
        parser.delegate = handler
        guard parser.parse(), !handler.trackPoints.isEmpty else { return nil }

        let name      = handler.trackName ?? fallbackName
        let startDate = handler.trackPoints.compactMap(\.timestamp).min() ?? Date()

        return Trip(
            id:          UUID(),
            name:        name,
            date:        startDate,
            notes:       "",
            gpxFilename: "",           // caller fills this in after writing the file
            trackPoints: handler.trackPoints
        )
    }

    // MARK: - Private state

    private var trackName:    String?
    private var trackPoints:  [Trip.TrackPoint] = []

    // Current trkpt accumulation
    private var currentLat:  Double?
    private var currentLon:  Double?
    private var currentEle:  Double?
    private var currentTime: Date?

    // Text accumulation
    private var currentElement: String = ""
    private var currentText:    String = ""

    // ISO8601 formatter — reused across all points for performance
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText    = ""

        if elementName == "trkpt" {
            currentLat  = attributeDict["lat"].flatMap(Double.init)
            currentLon  = attributeDict["lon"].flatMap(Double.init)
            currentEle  = nil
            currentTime = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "name":
            // Only capture the first <name> (track name, not waypoint names)
            if trackName == nil, !text.isEmpty { trackName = text }

        case "ele":
            currentEle = Double(text)

        case "time":
            currentTime = isoFormatter.date(from: text)

        case "trkpt":
            if let lat = currentLat, let lon = currentLon {
                trackPoints.append(Trip.TrackPoint(
                    latitude:  lat,
                    longitude: lon,
                    timestamp: currentTime,
                    elevation: currentEle
                ))
            }
            currentLat = nil; currentLon = nil
            currentEle = nil; currentTime = nil

        default:
            break
        }

        currentText = ""
    }
}
#endif
