import Foundation
import UserNotifications

/// Notices new shows by watched artists by comparing each new feed with the last.
@MainActor
enum Alerts {
    static let refreshTaskID = "com.bryanstage.marquee.refresh"
    private static let maxPerRun = 6

    private static func seenKey(_ region: String) -> String { "alerts.seen.\(region)" }
    private static func knownKey(_ region: String) -> String { "alerts.known.\(region)" }
    private static let announcedKey = "alerts.announced"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// The same artist at the same venue on the same day, however the listing's title or ID changes.
    private static func showKey(_ artist: String, _ event: Event, _ zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = calendar.dateComponents([.year, .month, .day], from: event.start)
        return "\(artist)|\(event.venueId)|\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
    }

    /// The new shows by watched artists in this feed. Every show ever seen is remembered (until it
    /// has passed), so a venue whose calendar failed to load for one update doesn't come back as
    /// "new" the next time. The first feed a region sees only sets the baseline, so installing the
    /// app doesn't announce everything.
    static func newShows(in feed: Feed, region: String, watching: Set<String>, defaults: UserDefaults = .standard) -> [Event] {
        let now = Date()
        var known = (defaults.dictionary(forKey: knownKey(region)) as? [String: Double]) ?? [:]
        // Before this list existed, only the previous feed's IDs were kept.
        let isFirst = known.isEmpty && defaults.stringArray(forKey: seenKey(region)) == nil
        for id in defaults.stringArray(forKey: seenKey(region)) ?? [] where known[id] == nil {
            known[id] = now.addingTimeInterval(365 * 24 * 3600).timeIntervalSince1970
        }
        defaults.removeObject(forKey: seenKey(region))

        let fresh = feed.events.filter { known[$0.id] == nil }
        for event in feed.events { known[event.id] = event.start.timeIntervalSince1970 }
        let yesterday = now.addingTimeInterval(-24 * 3600).timeIntervalSince1970
        defaults.set(known.filter { $0.value > yesterday }, forKey: knownKey(region))
        guard !isFirst else { return [] }

        let announced = (defaults.dictionary(forKey: announcedKey) as? [String: Double]) ?? [:]
        let zone = feed.city.timeZone
        return fresh.filter { event in
            event.start > now && !event.cancelled && event.artists.contains { name in
                let key = ArtistKey.make(name)
                return watching.contains(key) && announced[showKey(key, event, zone)] == nil
            }
        }
    }

    /// Remembers which artist-venue-day shows were announced, so none is announced twice.
    private static func markAnnounced(_ keys: [String], until: [String: Date], defaults: UserDefaults = .standard) {
        let now = Date().timeIntervalSince1970
        var announced = (defaults.dictionary(forKey: announcedKey) as? [String: Double]) ?? [:]
        for key in keys { announced[key] = (until[key] ?? Date()).timeIntervalSince1970 }
        defaults.set(announced.filter { $0.value > now - 24 * 3600 }, forKey: announcedKey)
    }

    private static let ordinals = ["Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth", "Tenth"]

    /// What an alert says for one artist's new dates. When the artist already had shows here, the
    /// alert counts up ("Second show added!") instead of repeating "New show".
    static func wording(artist: String, new: [Event], alreadyListed: Int, place: (Event) -> String) -> (title: String, body: String) {
        let places = new.prefix(3).map(place).joined(separator: "\n") + (new.count > 3 ? "\n…" : "")
        switch (alreadyListed, new.count) {
        case (0, 1):
            return ("New show: \(new[0].title)", place(new[0]))
        case (0, _):
            return ("\(artist): \(new.count) new shows", places)
        case (_, 1):
            let index = alreadyListed - 1
            let ordinal = index < ordinals.count ? ordinals[index] + " show" : "Another show"
            return ("\(artist): \(ordinal) added!", place(new[0]))
        default:
            return ("\(artist): \(new.count) more shows added!", places)
        }
    }

    static func check(feed: Feed?, region: String, taste: TasteProfile) async {
        // Only your home area alerts; browsing elsewhere doesn't.
        guard let feed, region == taste.alertRegion else { return }
        let watching = taste.watchedArtistKeys
        let found = newShows(in: feed, region: region, watching: watching)
        guard taste.alertsEnabled == true, !found.isEmpty else { return }
        let zone = feed.city.timeZone
        let now = Date()

        // One alert per artist, however many dates they added at once.
        var groups: [(key: String, name: String, events: [Event])] = []
        for event in found.sorted(by: { $0.start < $1.start }) {
            guard let name = event.artists.first(where: { watching.contains(ArtistKey.make($0)) }) else { continue }
            let key = ArtistKey.make(name)
            if let i = groups.firstIndex(where: { $0.key == key }) {
                groups[i].events.append(event)
            } else {
                groups.append((key, name, [event]))
            }
        }
        var keys: [String] = [], until: [String: Date] = [:]
        for group in groups {
            for event in group.events {
                let key = showKey(group.key, event, zone)
                keys.append(key)
                until[key] = event.start
            }
        }
        markAnnounced(keys, until: until)
        AlertHistory.record(found.map(\.id))

        let venues = Dictionary(feed.venues.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        let place: (Event) -> String = { event in
            [venues[event.venueId], formatter.string(from: event.start)].compactMap { $0 }.joined(separator: " · ")
        }

        let center = UNUserNotificationCenter.current()
        if groups.count > maxPerRun {
            let content = UNMutableNotificationContent()
            content.title = "\(found.count) new shows by artists you follow"
            content.body = groups.prefix(4).map(\.name).joined(separator: ", ") + "…"
            content.userInfo = ["eventIds": found.map(\.id)]
            try? await center.add(UNNotificationRequest(identifier: "summary-\(now.timeIntervalSince1970)", content: content, trigger: nil))
            return
        }
        for group in groups {
            let newIds = Set(group.events.map(\.id))
            let alreadyListed = feed.events.filter { event in
                !newIds.contains(event.id) && event.start > now && !event.cancelled
                    && event.artists.contains { ArtistKey.make($0) == group.key }
            }.count
            let text = wording(artist: group.name, new: group.events, alreadyListed: alreadyListed, place: place)
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.sound = .default
            content.userInfo = ["eventIds": group.events.map(\.id)]
            let id = "artist-\(group.key)-" + group.events.map(\.id).joined(separator: "-")
            try? await center.add(UNNotificationRequest(identifier: String(id.prefix(200)), content: content, trigger: nil))
        }
    }
}

/// Which shows past alerts announced, so tapping one (or the You tab) can list them.
enum AlertHistory {
    private static let key = "alerts.history"
    private static let keepFor: TimeInterval = 14 * 24 * 60 * 60

    static func record(_ ids: [String], defaults: UserDefaults = .standard) {
        let now = Date().timeIntervalSince1970
        var history = (defaults.dictionary(forKey: key) as? [String: Double]) ?? [:]
        for id in ids { history[id] = now }
        history = history.filter { now - $0.value < keepFor }
        defaults.set(history, forKey: key)
    }

    /// Alerted shows still in the feed, most recently announced first.
    @MainActor static func recentEvents(in feed: Feed?, defaults: UserDefaults = .standard) -> [Event] {
        let history = (defaults.dictionary(forKey: key) as? [String: Double]) ?? [:]
        let now = Date()
        return (feed?.events ?? [])
            .filter { history[$0.id] != nil && $0.start > now }
            .sorted { (history[$0.id] ?? 0, $1.start) > (history[$1.id] ?? 0, $0.start) }
    }
}

/// Carries a tapped alert's shows to the screen that lists them.
@MainActor
final class AlertRouter: ObservableObject {
    static let shared = AlertRouter()

    struct Opened: Identifiable {
        let id = UUID()
        var eventIds: [String]
    }

    @Published var opened: Opened?

    func open(_ ids: [String]) { opened = Opened(eventIds: ids) }
}

/// Shows alerts as banners even while the app is open, and opens the new shows when one is tapped.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        // Older alerts carried a single "eventId".
        let ids = (info["eventIds"] as? [String]) ?? [(info["eventId"] as? String)].compactMap { $0 }
        await MainActor.run { AlertRouter.shared.open(ids) }
    }
}
