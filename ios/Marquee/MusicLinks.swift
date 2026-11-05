import Foundation

/// An artist's own pages, in the order a tap on their name tries them.
enum ArtistLink: String, CaseIterable, Identifiable {
    case website, instagram, tiktok, bandcamp, soundcloud

    var id: String { rawValue }

    var label: String {
        switch self {
        case .website: "Website"
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .bandcamp: "Bandcamp"
        case .soundcloud: "SoundCloud"
        }
    }

    var symbol: String {
        switch self {
        case .website: "globe"
        case .instagram: "camera"
        case .tiktok: "music.note.tv"
        case .bandcamp: "opticaldisc"
        case .soundcloud: "cloud"
        }
    }

    static func available(_ info: ArtistInfo?) -> [(ArtistLink, URL)] {
        allCases.compactMap { kind in
            guard let text = info?.links?[kind.rawValue], let url = URL(string: text) else { return nil }
            return (kind, url)
        }
    }

    /// Their first known page, or a web search when we don't know any.
    static func primary(for name: String, info: ArtistInfo?, searchHint: String) -> URL? {
        if let first = available(info).first { return first.1 }
        let query = "\(name) \(searchHint)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return URL(string: "https://www.google.com/search?q=\(query)")
    }
}

enum MusicService: String, CaseIterable, Identifiable {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case youtube = "YouTube"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .spotify: "waveform"
        case .appleMusic: "music.note"
        case .youtube: "play.rectangle.fill"
        }
    }

    /// These are universal links, so each opens in its own app when installed.
    func url(for artist: String, info: ArtistInfo?) -> URL? {
        let encoded = artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/&+?"))) ?? artist
        // Their own page when we found it, otherwise a search.
        switch self {
        case .spotify:
            if let direct = info?.links?["spotify"], let url = URL(string: direct) { return url }
            return URL(string: "https://open.spotify.com/search/\(encoded)/artists")
        case .appleMusic:
            if let direct = info?.appleUrl ?? info?.links?["applemusic"], let url = URL(string: direct) { return url }
            return URL(string: "https://music.apple.com/us/search?term=\(encoded)")
        case .youtube:
            if let direct = info?.links?["youtube"], let url = URL(string: direct) { return url }
            return URL(string: "https://www.youtube.com/results?search_query=\(encoded)%20band")
        }
    }
}

/// Where to hear a comedian: their podcast, Spotify (specials and podcasts) and YouTube.
enum ComedyService: String, CaseIterable, Identifiable {
    case podcasts = "Podcasts"
    case spotify = "Spotify"
    case youtube = "YouTube"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .podcasts: "mic.fill"
        case .spotify: "waveform"
        case .youtube: "play.rectangle.fill"
        }
    }

    func url(for name: String, info: ArtistInfo?) -> URL? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/&+?"))) ?? name
        let key: String
        switch self {
        case .podcasts: key = "podcast"
        case .spotify: key = "spotify"
        case .youtube: key = "youtube"
        }
        if let direct = info?.links?[key], let url = URL(string: direct) { return url }
        switch self {
        case .podcasts: return URL(string: "https://podcasts.apple.com/us/search?term=\(encoded)")
        case .spotify: return URL(string: "https://open.spotify.com/search/\(encoded)")
        case .youtube: return URL(string: "https://www.youtube.com/results?search_query=\(encoded)%20comedian")
        }
    }

    /// True when the button opens their own page rather than a search.
    func isDirect(_ info: ArtistInfo?) -> Bool {
        let key = self == .podcasts ? "podcast" : rawValue.lowercased()
        return info?.links?[key] != nil
    }
}
