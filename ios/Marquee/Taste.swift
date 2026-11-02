import Foundation

/// Everything the app knows about what you like. Stays on the phone.
struct TasteProfile: Codable, Equatable {
    var followedVenues: Set<String> = []
    var favoriteArtists: [String] = []
    var libraryArtists: [String] = []
    var genres: Set<String> = []
    var savedEvents: Set<String> = []
    var dismissedEvents: Set<String> = []
    var finishedSetup = false

    var isEmpty: Bool {
        followedVenues.isEmpty && favoriteArtists.isEmpty && libraryArtists.isEmpty && genres.isEmpty
    }
}

@MainActor
final class TasteStore: ObservableObject {
    @Published var profile: TasteProfile {
        didSet { save() }
    }

    private static let key = "taste.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode(TasteProfile.self, from: data) {
            profile = stored
        } else {
            profile = TasteProfile()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.key)
        }
    }

    func toggleVenue(_ id: String) { profile.followedVenues.toggle(id) }
    func toggleSaved(_ id: String) { profile.savedEvents.toggle(id) }
    func toggleGenre(_ genre: String) { profile.genres.toggle(genre) }

    func isFavorite(_ artist: String) -> Bool {
        let key = ArtistKey.make(artist)
        return profile.favoriteArtists.contains { ArtistKey.make($0) == key }
    }

    func toggleFavorite(_ artist: String) {
        let key = ArtistKey.make(artist)
        if isFavorite(artist) {
            profile.favoriteArtists.removeAll { ArtistKey.make($0) == key }
        } else {
            profile.favoriteArtists.insert(artist, at: 0)
        }
    }
}

extension Set {
    mutating func toggle(_ member: Element) {
        if contains(member) { remove(member) } else { insert(member) }
    }
}

extension TasteProfile {
    /// Upcoming shows by artists you follow or have in your library, soonest first.
    func shows(in feed: Feed?) -> (events: [Event], artists: Set<String>) {
        let keys = Set((favoriteArtists + libraryArtists).map(ArtistKey.make))
        var artists = Set<String>()
        let events = (feed?.events ?? []).filter { event in
            let matches = event.artists.filter { keys.contains(ArtistKey.make($0)) }
            artists.formUnion(matches.map(ArtistKey.make))
            return !matches.isEmpty && !event.cancelled
        }
        return (events, artists)
    }
}

struct Recommendation {
    var score: Int
    var reason: String?

    var isForYou: Bool { score >= Recommender.forYouThreshold }
}

/// Built once per screen update, so scoring hundreds of shows stays fast.
struct Recommender {
    static let forYouThreshold = 25

    private let favorites: [String: String]
    private let library: [String: String]
    private let genres: Set<String>
    private let followed: Set<String>
    private let dismissed: Set<String>
    private let artists: [String: ArtistInfo]

    init(taste: TasteProfile, feed: Feed?) {
        favorites = Dictionary(taste.favoriteArtists.map { (ArtistKey.make($0), $0) }, uniquingKeysWith: { first, _ in first })
        library = Dictionary(taste.libraryArtists.map { (ArtistKey.make($0), $0) }, uniquingKeysWith: { first, _ in first })
        genres = taste.genres
        followed = taste.followedVenues
        dismissed = taste.dismissedEvents
        artists = feed?.artists ?? [:]
    }

    func recommend(_ event: Event) -> Recommendation {
        if dismissed.contains(event.id) { return Recommendation(score: -1, reason: nil) }
        var score = 0
        var reasons: [(Int, String)] = []

        for name in event.artists {
            let key = ArtistKey.make(name)
            let info = artists[key]

            if favorites[key] != nil {
                score += 100
                reasons.append((100, "You follow \(name)"))
            } else if library[key] != nil {
                score += 80
                reasons.append((80, "\(name) is in your library"))
            }

            let similar = (info?.related ?? []).first {
                let relatedKey = ArtistKey.make($0)
                return favorites[relatedKey] != nil || library[relatedKey] != nil
            }
            if let similar {
                score += 50
                reasons.append((50, "Similar to \(similar)"))
            }

            if let genre = info?.genre, genres.contains(genre) {
                score += 25
                reasons.append((25, genre))
            }
        }

        if followed.contains(event.venueId) {
            score += 15
        }
        return Recommendation(score: score, reason: reasons.max { $0.0 < $1.0 }?.1)
    }
}
