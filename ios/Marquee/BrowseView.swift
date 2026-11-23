import SwiftUI

// Browse's date ranges and filters, now part of the Tonight page.

enum BrowseRange: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }

    var unit: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }
}

/// Filters live here, away from the view, so they can be tested without a screen.
struct EventQuery {
    var search = ""
    var myVenuesOnly = false
    var category: EventCategory?
    var genre: String?
    var venueId: String?

    @MainActor func matches(_ event: Event, store: FeedStore, followed: Set<String>) -> Bool {
        if myVenuesOnly, !followed.contains(event.venueId) { return false }
        if let venueId, event.venueId != venueId { return false }
        if !event.matches(category) { return false }
        if let genre, !store.genres(for: event).contains(genre) { return false }
        let term = search.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return true }
        let haystack = [event.title, store.venue(for: event)?.name ?? "", store.venue(for: event)?.neighborhood ?? ""]
            + event.artists + store.genres(for: event)
        return haystack.contains { $0.localizedCaseInsensitiveContains(term) }
    }
}
