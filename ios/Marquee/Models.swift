import Foundation

struct Feed: Codable {
    var city: City
    var generatedAt: Date
    var venues: [Venue]
    var artists: [String: ArtistInfo]
    var events: [Event]
    var sources: [SourceStatus]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        city = try container.decode(City.self, forKey: .city)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        venues = try container.decode([Venue].self, forKey: .venues)
        artists = try container.decode([String: ArtistInfo].self, forKey: .artists)
        events = try container.decode([LossyEvent].self, forKey: .events).compactMap(\.event)
        sources = try container.decode([SourceStatus].self, forKey: .sources)
    }
}

/// Skips a malformed show instead of losing the whole feed.
private struct LossyEvent: Decodable {
    var event: Event?

    init(from decoder: Decoder) {
        event = try? Event(from: decoder)
    }
}

struct City: Codable, Hashable {
    var id: String
    var name: String
    var timezone: String

    var timeZone: TimeZone { TimeZone(identifier: timezone) ?? .current }
}

struct Venue: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var neighborhood: String?
    var address: String?
    var lat: Double?
    var lon: Double?
    var url: String?
}

struct ArtistInfo: Codable, Hashable {
    var name: String
    var genre: String?
    var appleUrl: String?
    var image: String?
    var fans: Int?
    var related: [String]?
}

struct Event: Codable, Identifiable, Hashable {
    var id: String
    var venueId: String
    var title: String
    var artists: [String]
    var start: Date
    var category: String
    var soldOut: Bool
    var cancelled: Bool
    var timeTBA: Bool?
    var doors: Date?
    var ticketUrl: String?
    var url: String?
    var image: String?
    var age: String?
    var price: String?
    var tour: String?
}

struct SourceStatus: Codable, Hashable {
    var source: String
    var ok: Bool
    var count: Int?
    var error: String?
}

enum EventCategory: String, CaseIterable, Identifiable {
    case music, comedy, film, theater, party, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .music: "Music"
        case .comedy: "Comedy"
        case .film: "Film"
        case .theater: "Theater"
        case .party: "Nightlife"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .music: "music.mic"
        case .comedy: "face.smiling"
        case .film: "film"
        case .theater: "theatermasks"
        case .party: "sparkles"
        case .other: "star"
        }
    }

    /// The filters people pick from; "Other" is only ever part of "All".
    static let filters: [EventCategory] = [.music, .comedy, .film, .theater, .party]

    /// Music and nightlife acts have Apple Music pages; comedians and films don't.
    var hasMusicLinks: Bool { self == .music || self == .party }
}

extension Event {
    var kind: EventCategory { EventCategory(rawValue: category) ?? .other }
}

enum ArtistKey {
    /// Must stay in step with `artist_key` in scraper/titles.py.
    static func make(_ name: String) -> String {
        var text = name.decomposedStringWithCompatibilityMapping
        text = String(String.UnicodeScalarView(text.unicodeScalars.filter(\.isASCII))).lowercased()
        text = text.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("the ") { text.removeFirst(4) }
        text = text.replacingOccurrences(of: "&", with: "and")
        return String(text.filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
    }
}
