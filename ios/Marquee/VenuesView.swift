import SwiftUI

struct VenuesView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore

    @State private var search = ""

    private var filtered: [Venue] {
        let term = search.trimmingCharacters(in: .whitespaces)
        let matching = store.venues.filter {
            term.isEmpty || $0.name.localizedCaseInsensitiveContains(term)
                || ($0.neighborhood ?? "").localizedCaseInsensitiveContains(term)
        }
        return matching.sorted { first, second in
            let firstFollowed = taste.profile.followedVenues.contains(first.id)
            let secondFollowed = taste.profile.followedVenues.contains(second.id)
            if firstFollowed != secondFollowed { return firstFollowed }
            return showCount(first) > showCount(second)
        }
    }

    private func showCount(_ venue: Venue) -> Int {
        store.events.lazy.filter { $0.venueId == venue.id }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filtered) { venue in
                        NavigationLink(value: venue) {
                            VenueRow(venue: venue, nextShow: nextShow(at: venue), showCount: showCount(venue))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("Venues")
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

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(venue.name).font(.headline)
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
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
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

    private var shows: [Event] { store.events.filter { $0.venueId == venue.id } }
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
                        .foregroundStyle(.black)
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
        let query = (venue.address ?? venue.name).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://maps.apple.com/?q=\(query)")
    }
}
