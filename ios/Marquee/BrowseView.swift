import SwiftUI

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

struct BrowseView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore

    @State private var range: BrowseRange = .week
    @State private var anchor: Date?
    @State private var query = EventQuery()

    private var zone: TimeZone { store.city?.timeZone ?? .current }
    private var start: Date { anchor ?? store.today }
    private var isSearching: Bool { !query.search.trimmingCharacters(in: .whitespaces).isEmpty }

    private var interval: DateInterval {
        let calendar = store.calendar
        switch range {
        case .day:
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start) ?? start)
        case .week:
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 7, to: start) ?? start)
        case .month:
            return calendar.dateInterval(of: .month, for: start) ?? DateInterval(start: start, duration: 0)
        }
    }

    /// A search looks across every date; otherwise only the chosen range.
    private var groups: [(day: Date, events: [Event])] {
        store.sortedDays.compactMap { day in
            if !isSearching, !(interval.start..<interval.end).contains(day) { return nil }
            let events = store.events(on: day).filter { query.matches($0, store: store, followed: taste.profile.followedVenues) }
            return events.isEmpty ? nil : (day, events)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                CityBannerHeader()
                LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                    controls
                    let groups = groups
                    if groups.isEmpty {
                        ContentUnavailableView("No shows found", systemImage: "magnifyingglass", description: Text("Try another date or fewer filters."))
                            .padding(.top, 40)
                    }
                    ForEach(groups, id: \.day) { group in
                        Section {
                            ForEach(group.events) { EventLink(event: $0) }
                        } header: {
                            Text(Format.fullDay(group.day, zone))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .background(Theme.background)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .refreshable { await store.refresh() }
            .screenBackground()
            .navigationTitle("Browse")
            .searchable(text: $query.search, prompt: "Artist, show, venue or genre")
            .marqueeDestinations()
        }
    }

    @ViewBuilder private var controls: some View {
        Picker("Range", selection: $range) {
            ForEach(BrowseRange.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if !isSearching {
            HStack {
                Button { step(-1) } label: { stepLabel("chevron.left") }
                    .accessibilityLabel("Previous \(range.rawValue.lowercased())")
                    .disabled(start <= store.today)
                Spacer()
                Text(rangeTitle).font(.headline)
                Spacer()
                Button { step(1) } label: { stepLabel("chevron.right") }
                    .accessibilityLabel("Next \(range.rawValue.lowercased())")
            }
        }

        CategoryChips(selection: $query.category)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "My venues", isOn: query.myVenuesOnly) { query.myVenuesOnly.toggle() }
                Menu {
                    Button("All genres") { query.genre = nil }
                    if query.category == nil || query.category == .music || query.category == .party {
                        Section("Music") {
                            ForEach(store.genres, id: \.self) { genre in
                                Button(genre) { query.genre = genre }
                            }
                        }
                    }
                    if query.category == nil || query.category == .film {
                        Section("Film") {
                            ForEach(EventTags.filmTags, id: \.self) { tag in
                                Button(EventTags.label(tag)) { query.genre = tag }
                            }
                        }
                    }
                    if query.category == nil || query.category == .comedy {
                        Section("Comedy") {
                            ForEach(EventTags.comedyTags, id: \.self) { tag in
                                Button(EventTags.label(tag)) { query.genre = tag }
                            }
                        }
                    }
                } label: {
                    filterMenuLabel(query.genre.map(EventTags.label) ?? "Genre", isOn: query.genre != nil)
                }
                Menu {
                    Button("All venues") { query.venueId = nil }
                    ForEach(store.venues) { venue in
                        Button(venue.name) { query.venueId = venue.id }
                    }
                } label: {
                    filterMenuLabel(query.venueId.flatMap { store.venuesById[$0]?.name } ?? "Venue", isOn: query.venueId != nil)
                }
            }
        }
    }

    private func stepLabel(_ symbol: String) -> some View {
        Image(systemName: symbol).frame(width: 44, height: 44).contentShape(Rectangle())
    }

    private func filterMenuLabel(_ title: String, isOn: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isOn ? Theme.accent : Theme.card, in: Capsule())
        .foregroundStyle(isOn ? Color.black : Color.primary)
    }

    private var rangeTitle: String {
        switch range {
        case .day:
            return Format.fullDay(start, zone)
        case .week:
            let last = store.calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return "\(Format.monthDay(start, zone)) – \(Format.monthDay(last, zone))"
        case .month:
            return Format.month(start, zone)
        }
    }

    private func step(_ direction: Int) {
        let next = store.calendar.date(byAdding: range.unit, value: direction, to: start) ?? start
        anchor = max(next, store.today)
    }
}
