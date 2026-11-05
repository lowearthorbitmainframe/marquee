import Foundation
import UserNotifications

/// Notices new shows by watched artists by comparing each new feed with the last.
@MainActor
enum Alerts {
    static let refreshTaskID = "com.bryanstage.marquee.refresh"
    private static let maxPerRun = 6

    private static func seenKey(_ region: String) -> String { "alerts.seen.\(region)" }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// The new shows by watched artists in this feed. The first feed a region
    /// sees only sets the baseline, so installing the app doesn't announce everything.
    static func newShows(in feed: Feed, region: String, watching: Set<String>, defaults: UserDefaults = .standard) -> [Event] {
        let key = seenKey(region)
        let previous = defaults.stringArray(forKey: key).map(Set.init)
        defaults.set(feed.events.map(\.id), forKey: key)
        guard let previous else { return [] }
        let now = Date()
        return feed.events.filter { event in
            !previous.contains(event.id) && event.start > now && !event.cancelled
                && event.artists.contains { watching.contains(ArtistKey.make($0)) }
        }
    }

    static func check(feed: Feed?, region: String, taste: TasteProfile) async {
        // Only your home area alerts; browsing elsewhere doesn't.
        guard let feed, region == taste.alertRegion else { return }
        let found = newShows(in: feed, region: region, watching: taste.watchedArtistKeys)
        guard taste.alertsEnabled == true, !found.isEmpty else { return }
        AlertHistory.record(found.map(\.id))
        let ids = found.map(\.id)
        let venues = Dictionary(feed.venues.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let formatter = DateFormatter()
        formatter.timeZone = feed.city.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")

        let center = UNUserNotificationCenter.current()
        if found.count > maxPerRun {
            let content = UNMutableNotificationContent()
            content.title = "\(found.count) new shows by artists you follow"
            content.body = found.prefix(4).map(\.title).joined(separator: ", ") + "…"
            content.userInfo = ["eventIds": ids]
            try? await center.add(UNNotificationRequest(identifier: "summary-\(Date().timeIntervalSince1970)", content: content, trigger: nil))
            return
        }
        for event in found {
            let content = UNMutableNotificationContent()
            content.title = "New show: \(event.title)"
            content.body = [venues[event.venueId], formatter.string(from: event.start)].compactMap { $0 }.joined(separator: " · ")
            content.sound = .default
            content.userInfo = ["eventIds": [event.id]]
            try? await center.add(UNNotificationRequest(identifier: "show-\(event.id)", content: content, trigger: nil))
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
