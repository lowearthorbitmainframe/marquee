import Foundation

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
