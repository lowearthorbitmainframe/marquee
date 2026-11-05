import Foundation

enum FeedConfig {
    /// Where the scraper publishes the feed. The app falls back to the snapshot
    /// bundled at build time until the first download succeeds.
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/lowearthorbitmainframe/marquee/main/data/los-angeles.json")
    static let refreshInterval: TimeInterval = 60 * 60
}

@MainActor
final class FeedStore: ObservableObject {
    @Published private(set) var feed: Feed?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?

    private(set) var venuesById: [String: Venue] = [:]
    private(set) var eventsByDay: [Date: [Event]] = [:]
    /// Worked out once per feed, so lists of venues stay fast.
    private(set) var showCounts: [String: Int] = [:]
    private(set) var venueKinds: [String: Set<EventCategory>] = [:]
    private(set) var calendar = Calendar(identifier: .gregorian)
    private var lastChecked: Date?

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("feed.json")
    }

    var city: City? { feed?.city }
    var venues: [Venue] { feed?.venues ?? [] }
    var events: [Event] { feed?.events ?? [] }

    var sortedDays: [Date] { eventsByDay.keys.sorted() }

    var genres: [String] {
        let values = (feed?.artists.values).map { $0.compactMap(\.genre) } ?? []
        return Array(Set(values)).sorted()
    }

    func loadLocal() {
        if let data = try? Data(contentsOf: Self.cacheURL), let cached = try? Self.decoder.decode(Feed.self, from: data) {
            install(cached)
        } else if let url = Bundle.main.url(forResource: "los-angeles", withExtension: "json"),
                  let data = try? Data(contentsOf: url) {
            do {
                install(try Self.decoder.decode(Feed.self, from: data))
            } catch {
                lastError = "Couldn't read the show list."
            }
        }
    }

    func refreshIfNeeded() async {
        if let lastChecked, Date().timeIntervalSince(lastChecked) < FeedConfig.refreshInterval { return }
        await refresh()
    }

    func refresh() async {
        guard let url = FeedConfig.remoteURL else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fresh = try Self.decoder.decode(Feed.self, from: data)
            try? data.write(to: Self.cacheURL, options: .atomic)
            install(fresh)
            lastChecked = Date()
            lastError = nil
        } catch {
            lastError = "Couldn't update. Showing the last saved list."
        }
    }

    func install(_ feed: Feed) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = feed.city.timeZone
        self.calendar = calendar
        venuesById = Dictionary(feed.venues.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        eventsByDay = Dictionary(grouping: feed.events) { calendar.startOfDay(for: $0.start) }
        showCounts = feed.events.reduce(into: [:]) { $0[$1.venueId, default: 0] += 1 }
        venueKinds = feed.events.reduce(into: [:]) { $0[$1.venueId, default: []].insert($1.kind) }
        self.feed = feed
    }

    func venue(for event: Event) -> Venue? { venuesById[event.venueId] }

    func info(forArtist name: String) -> ArtistInfo? { feed?.artists[ArtistKey.make(name)] }

    func genres(for event: Event) -> [String] {
        var seen = Set<String>()
        return event.artists.compactMap { info(forArtist: $0)?.genre }.filter { seen.insert($0).inserted }
    }

    func events(on day: Date) -> [Event] {
        eventsByDay[calendar.startOfDay(for: day)] ?? []
    }

    var today: Date { calendar.startOfDay(for: Date()) }
}
