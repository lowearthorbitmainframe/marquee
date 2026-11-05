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
        let venues = Dictionary(feed.venues.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let formatter = DateFormatter()
        formatter.timeZone = feed.city.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")

        let center = UNUserNotificationCenter.current()
        if found.count > maxPerRun {
            let content = UNMutableNotificationContent()
            content.title = "\(found.count) new shows by artists you follow"
            content.body = found.prefix(4).map(\.title).joined(separator: ", ") + "…"
            try? await center.add(UNNotificationRequest(identifier: "summary-\(Date().timeIntervalSince1970)", content: content, trigger: nil))
            return
        }
        for event in found {
            let content = UNMutableNotificationContent()
            content.title = "New show: \(event.title)"
            content.body = [venues[event.venueId], formatter.string(from: event.start)].compactMap { $0 }.joined(separator: " · ")
            content.sound = .default
            content.userInfo = ["eventId": event.id]
            try? await center.add(UNNotificationRequest(identifier: "show-\(event.id)", content: content, trigger: nil))
        }
    }
}

/// Shows alerts as banners even while the app is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
