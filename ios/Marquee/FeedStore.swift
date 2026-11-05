import Foundation

enum FeedConfig {
    /// Where the scraper publishes each region's feed and the list of regions.
    /// The app falls back to the Los Angeles snapshot bundled at build time.
    static let baseURL = "https://raw.githubusercontent.com/lowearthorbitmainframe/marquee/main/data/"
    static let refreshInterval: TimeInterval = 60 * 60
    static let defaultRegion = Region(id: "los-angeles", name: "Los Angeles")

    static func feedURL(for region: String) -> URL? { URL(string: baseURL + region + ".json") }
    static var regionsURL: URL? { URL(string: baseURL + "regions.json") }
}

struct Region: Codable, Hashable, Identifiable {
    var id: String
    var name: String
}

@MainActor
final class FeedStore: ObservableObject {
    @Published private(set) var feed: Feed?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var regions: [Region] = [FeedConfig.defaultRegion]
    @Published private(set) var regionId: String

    private let defaults: UserDefaults

    /// `region` loads a specific region, as background alert checks do for your home area.
    init(defaults: UserDefaults = .standard, region: String? = nil) {
        self.defaults = defaults
        regionId = region ?? defaults.string(forKey: "region") ?? FeedConfig.defaultRegion.id
        if let data = defaults.data(forKey: "regions"), let saved = try? JSONDecoder().decode([Region].self, from: data) {
            regions = saved
        }
    }

    private(set) var venuesById: [String: Venue] = [:]
    private(set) var eventsByDay: [Date: [Event]] = [:]
    /// Worked out once per feed, so lists of venues stay fast.
    private(set) var showCounts: [String: Int] = [:]
    private(set) var venueKinds: [String: Set<EventCategory>] = [:]
    /// Each venue's kinds of events, most frequent first.
    private(set) var venueKindOrder: [String: [EventCategory]] = [:]
    private(set) var calendar = Calendar(identifier: .gregorian)
    private var lastChecked: Date?

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("feed-\(regionId).json")
    }

    var regionName: String { regions.first { $0.id == regionId }?.name ?? feed?.city.name ?? "LA" }

    var city: City? { feed?.city }
    var venues: [Venue] { feed?.venues ?? [] }
    var events: [Event] { feed?.events ?? [] }

    var sortedDays: [Date] { eventsByDay.keys.sorted() }

    var genres: [String] {
        let values = (feed?.artists.values).map { $0.compactMap(\.genre) } ?? []
        return Array(Set(values)).sorted()
    }

    func loadLocal() {
        if let data = try? Data(contentsOf: cacheURL), let cached = try? Self.decoder.decode(Feed.self, from: data) {
            install(cached)
        } else if let url = Bundle.main.url(forResource: regionId, withExtension: "json"),
                  let data = try? Data(contentsOf: url) {
            do {
                install(try Self.decoder.decode(Feed.self, from: data))
            } catch {
                lastError = "Couldn't read the show list."
            }
        }
    }

    @discardableResult
    func refreshIfNeeded() async -> Bool {
        if let lastChecked, Date().timeIntervalSince(lastChecked) < FeedConfig.refreshInterval { return false }
        return await refresh()
    }

    /// Returns true when a newer feed was installed.
    @discardableResult
    func refresh() async -> Bool {
        guard let url = FeedConfig.feedURL(for: regionId) else { return false }
        isRefreshing = true
        defer { isRefreshing = false }
        await refreshRegions()
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fresh = try Self.decoder.decode(Feed.self, from: data)
            try? data.write(to: cacheURL, options: .atomic)
            install(fresh)
            lastChecked = Date()
            lastError = nil
            return true
        } catch {
            lastError = "Couldn't update. Showing the last saved list."
            return false
        }
    }

    private func refreshRegions() async {
        guard let url = FeedConfig.regionsURL,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let fresh = try? JSONDecoder().decode([Region].self, from: data), !fresh.isEmpty else { return }
        regions = fresh
        defaults.set(data, forKey: "regions")
    }

    func switchRegion(to id: String) async {
        guard id != regionId else { return }
        regionId = id
        defaults.set(id, forKey: "region")
        feed = nil
        lastChecked = nil
        loadLocal()
        await refresh()
    }

    func install(_ feed: Feed) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = feed.city.timeZone
        self.calendar = calendar
        venuesById = Dictionary(feed.venues.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        eventsByDay = Dictionary(grouping: feed.events) { calendar.startOfDay(for: $0.start) }
        showCounts = feed.events.reduce(into: [:]) { $0[$1.venueId, default: 0] += 1 }
        venueKinds = feed.events.reduce(into: [:]) { $0[$1.venueId, default: []].insert($1.kind) }
        let kindCounts = feed.events.reduce(into: [String: [EventCategory: Int]]()) { $0[$1.venueId, default: [:]][$1.kind, default: 0] += 1 }
        venueKindOrder = kindCounts.mapValues { counts in counts.sorted { $0.value > $1.value }.map(\.key) }
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
