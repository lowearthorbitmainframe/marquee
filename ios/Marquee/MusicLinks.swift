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

    /// Searches Instagram or TikTok for someone whose pages we don't know yet.
    static func socialSearches(for name: String) -> [(label: String, symbol: String, url: URL)] {
        let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return [
            ("Find on Instagram", "camera", URL(string: "https://www.instagram.com/explore/search/keyword/?q=\(query)")),
            ("Find on TikTok", "music.note.tv", URL(string: "https://www.tiktok.com/search/user?q=\(query)")),
        ].compactMap { item in item.2.map { (item.0, item.1, $0) } }
    }

    /// Their first known page, or an Instagram search when we don't know any.
    static func primary(for name: String, info: ArtistInfo?, searchHint: String) -> URL? {
        if let first = available(info).first { return first.1 }
        return socialSearches(for: name).first?.url
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
        switch self {
        case .spotify:
            return URL(string: "https://open.spotify.com/search/\(encoded)/artists")
        case .appleMusic:
            if let direct = info?.appleUrl, let url = URL(string: direct) { return url }
            return URL(string: "https://music.apple.com/us/search?term=\(encoded)")
        case .youtube:
            return URL(string: "https://www.youtube.com/results?search_query=\(encoded)%20band")
        }
    }
}
