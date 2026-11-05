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
    /// Everyone on a show you've hearted, kept after the show is over.
    /// Optional so profiles saved before this existed still load.
    var savedArtists: [String]?
    var alertsEnabled: Bool?
    /// Alerts only cover this region, whichever one you're browsing.
    var homeRegion: String?
    /// Artists you never want to see. Their shows are hidden.
    var dislikedArtists: [String]?

    var alertRegion: String { homeRegion ?? FeedConfig.defaultRegion.id }

    /// The artists whose new shows trigger an alert.
    var watchedArtistKeys: Set<String> {
        Set((favoriteArtists + libraryArtists + (savedArtists ?? [])).map(ArtistKey.make))
    }

    var dislikedKeys: Set<String> { Set((dislikedArtists ?? []).map(ArtistKey.make)) }

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
    func toggleSaved(_ event: Event) {
        profile.savedEvents.toggle(event.id)
        if profile.savedEvents.contains(event.id) && (event.kind.hasMusicLinks || event.kind == .comedy) {
            var artists = profile.savedArtists ?? []
            for name in event.artists where !artists.contains(where: { ArtistKey.make($0) == ArtistKey.make(name) }) {
                artists.append(name)
            }
            profile.savedArtists = artists
        }
    }
    func toggleGenre(_ genre: String) { profile.genres.toggle(genre) }

    func isDisliked(_ artist: String) -> Bool { profile.dislikedKeys.contains(ArtistKey.make(artist)) }

    /// Hides their shows and stops following them.
    func toggleDisliked(_ artist: String) {
        let key = ArtistKey.make(artist)
        var disliked = profile.dislikedArtists ?? []
        if isDisliked(artist) {
            disliked.removeAll { ArtistKey.make($0) == key }
        } else {
            disliked.insert(artist, at: 0)
            profile.favoriteArtists.removeAll { ArtistKey.make($0) == key }
        }
        profile.dislikedArtists = disliked
    }

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

enum Hidden {
    /// A show is hidden when its headliner (or, with no lineup, its title) is
    /// someone you disliked. A disliked opener doesn't hide a show you might want.
    static func hides(_ event: Event, disliked: Set<String>) -> Bool {
        guard !disliked.isEmpty else { return false }
        if let headliner = event.artists.first { return disliked.contains(ArtistKey.make(headliner)) }
        return disliked.contains(ArtistKey.make(event.title))
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
    private let disliked: Set<String>
    private let artists: [String: ArtistInfo]

    init(taste: TasteProfile, feed: Feed?) {
        favorites = Dictionary(taste.favoriteArtists.map { (ArtistKey.make($0), $0) }, uniquingKeysWith: { first, _ in first })
        library = Dictionary(taste.libraryArtists.map { (ArtistKey.make($0), $0) }, uniquingKeysWith: { first, _ in first })
        genres = taste.genres
        followed = taste.followedVenues
        dismissed = taste.dismissedEvents
        disliked = taste.dislikedKeys
        artists = feed?.artists ?? [:]
    }

    func recommend(_ event: Event) -> Recommendation {
        if dismissed.contains(event.id) || Hidden.hides(event, disliked: disliked) { return Recommendation(score: -1, reason: nil) }
        var score = 0
        var reasons: [(Int, String)] = []

        // Film and comedy genres come from the show itself, not an artist.
        if let tag = EventTags.tags(for: event).first(where: genres.contains) {
            score += 25
            reasons.append((25, EventTags.label(tag)))
        }

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
