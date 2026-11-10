import SwiftUI

struct VenuesView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore

    @State private var search = ""
    @State private var category: EventCategory?

    private var filtered: [Venue] {
        let term = search.trimmingCharacters(in: .whitespaces)
        let matching = store.venues.filter {
            (category == nil || store.venueKinds[$0.id]?.contains(category!) == true)
                && (term.isEmpty || $0.name.localizedCaseInsensitiveContains(term)
                    || ($0.neighborhood ?? "").localizedCaseInsensitiveContains(term))
        }
        // Alphabetical, filing "The Echo" under E.
        return matching.sorted { sortName($0).localizedStandardCompare(sortName($1)) == .orderedAscending }
    }

    private func sortName(_ venue: Venue) -> String {
        venue.name.hasPrefix("The ") ? String(venue.name.dropFirst(4)) : venue.name
    }

    private func showCount(_ venue: Venue) -> Int {
        store.showCounts[venue.id] ?? 0
    }

    @State private var isSuggesting = false
    // Kept apart from the search text, which iOS clears when the search field closes.
    @State private var suggestName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    CategoryChips(selection: $category)
                    ForEach(filtered) { venue in
                        NavigationLink(value: venue) {
                            VenueRow(venue: venue, nextShow: nextShow(at: venue), showCount: showCount(venue))
                        }
                        .buttonStyle(.plain)
                    }
                    // A search that finds nothing is the moment someone knows a venue is missing.
                    if !search.trimmingCharacters(in: .whitespaces).isEmpty && filtered.isEmpty {
                        ContentUnavailableView {
                            Label("No venue called \"\(search)\"", systemImage: "magnifyingglass")
                        } description: {
                            Text("Know a place we should list?")
                        } actions: {
                            Button("Suggest \(search)") { suggestName = search; isSuggesting = true }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 30)
                    }
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("Venues")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { suggestName = search; isSuggesting = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Suggest a venue")
                }
            }
            .sheet(isPresented: $isSuggesting) { SuggestVenueView(initialName: suggestName) }
            .searchable(text: $search, prompt: "Venue or neighborhood")
            .marqueeDestinations()
        }
    }

    private func nextShow(at venue: Venue) -> Event? {
        store.events.first { $0.venueId == venue.id && !$0.cancelled }
    }
}

struct VenueRow: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore

    var venue: Venue
    var nextShow: Event?
    var showCount: Int

    private var zone: TimeZone { store.city?.timeZone ?? .current }
    private var isFollowed: Bool { taste.profile.followedVenues.contains(venue.id) }

    /// Every kind of event the venue hosts, its main one first.
    private var kinds: [EventCategory] { store.venueKindOrder[venue.id] ?? [] }
    private var mainKind: EventCategory { kinds.first ?? .other }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(venue.name).font(.headline)
                    ForEach(kinds, id: \.self) { kind in
                        Circle().fill(kind.color).frame(width: 7, height: 7)
                    }
                }
                Text(summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                if let nextShow {
                    Text("Next: \(nextShow.title), \(Format.monthDay(nextShow.start, zone))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button {
                taste.toggleVenue(venue.id)
            } label: {
                Image(systemName: isFollowed ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isFollowed ? Theme.accent : Color.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFollowed ? "Unfollow \(venue.name)" : "Follow \(venue.name)")
        }
        .padding(12)
        .padding(.leading, 4)
        .background(Theme.card.overlay(mainKind.wash))
        .overlay(alignment: .leading) {
            Rectangle().fill(mainKind.color.opacity(0.55)).frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(venue.name), \(kinds.map(\.label).joined(separator: ", "))")
    }

    private var summary: String {
        [venue.neighborhood, "\(showCount) upcoming"].compactMap { $0 }.joined(separator: " · ")
    }
}

struct VenueDetailView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore
    @Environment(\.openURL) private var openURL

    var venue: Venue

    private var shows: [Event] { store.events.filter { $0.venueId == venue.id && !store.isHidden($0) } }
    private var isFollowed: Bool { taste.profile.followedVenues.contains(venue.id) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if let address = venue.address {
                    Text(address).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button(isFollowed ? "Following" : "Follow") { taste.toggleVenue(venue.id) }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Theme.onAccent)
                    if let maps = mapsURL {
                        Button("Directions") { openURL(maps) }.buttonStyle(.bordered)
                    }
                    if let site = venue.url.flatMap(URL.init(string:)) {
                        Button("Website") { openURL(site) }.buttonStyle(.bordered)
                    }
                }
                .controlSize(.large)

                SectionHeader(title: "Upcoming", subtitle: "\(shows.count) shows").padding(.top, 8)
                ForEach(shows) { EventLink(event: $0, showsDate: true) }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(venue.name)
        .inlineTitle()
    }

    private var mapsURL: URL? {
        // Some rooms keep their address private.
        guard let address = venue.address else { return nil }
        let query = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://maps.apple.com/?q=\(query)")
    }
}
