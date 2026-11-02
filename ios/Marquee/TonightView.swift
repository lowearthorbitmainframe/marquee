import SwiftUI

struct TonightView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore

    @State private var selectedDay: Date?

    private var zone: TimeZone { store.city?.timeZone ?? .current }
    private var day: Date { selectedDay ?? store.today }
    private var upcomingDays: [Date] {
        (0..<14).compactMap { store.calendar.date(byAdding: .day, value: $0, to: store.today) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    DayStrip(days: upcomingDays, selected: day) { selectedDay = $0 }

                    if taste.profile.isEmpty {
                        PersonalizeCard()
                    }

                    let lists = sections
                    if store.feed == nil {
                        ContentUnavailableView("Couldn't load shows", systemImage: "exclamationmark.triangle", description: Text("Pull down to try again."))
                            .padding(.top, 40)
                    } else if lists.isEmpty {
                        ContentUnavailableView("Nothing listed", systemImage: "moon.zzz", description: Text("No shows found for this day yet."))
                            .padding(.top, 40)
                    }
                    ForEach(lists, id: \.title) { section in
                        SectionHeader(title: section.title, subtitle: section.subtitle).padding(.top, 8)
                        ForEach(section.items, id: \.event.id) { item in
                            // The reason is part of the identity so a taste change redraws the row.
                            EventLink(event: item.event, reason: item.reason)
                                .id("\(item.event.id)-\(item.reason ?? "")")
                        }
                    }
                    FreshnessFooter().padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .refreshable { await store.refresh() }
            .screenBackground()
            .navigationTitle(title)
            .marqueeDestinations()
        }
    }

    private var title: String {
        if store.calendar.isDate(day, inSameDayAs: store.today) { return "Tonight in \(store.city?.name ?? "LA")" }
        return Format.fullDay(day, zone)
    }

    private struct Item {
        var event: Event
        var reason: String?
    }

    private struct DaySection {
        var title: String
        var subtitle: String?
        var items: [Item]
    }

    /// Your venues first, then picks, then everything else, each show appearing once.
    private var sections: [DaySection] {
        let recommender = Recommender(taste: taste.profile, feed: store.feed)
        let scored = store.events(on: day)
            .map { (event: $0, match: recommender.recommend($0)) }
            .filter { $0.match.score >= 0 }

        let picks = scored.filter(\.match.isForYou).sorted { $0.match.score > $1.match.score }
        let pickIDs = Set(picks.map(\.event.id))
        let atVenues = scored.filter { taste.profile.followedVenues.contains($0.event.venueId) && !pickIDs.contains($0.event.id) }
        let venueIDs = Set(atVenues.map(\.event.id))
        let rest = scored.filter { !pickIDs.contains($0.event.id) && !venueIDs.contains($0.event.id) }

        var result: [DaySection] = []
        if !picks.isEmpty {
            result.append(DaySection(title: "For you", subtitle: "Based on your artists and genres",
                                     items: picks.map { Item(event: $0.event, reason: $0.match.reason) }))
        }
        if !atVenues.isEmpty {
            result.append(DaySection(title: "At your venues", subtitle: nil, items: atVenues.map { Item(event: $0.event, reason: nil) }))
        }
        if !rest.isEmpty {
            result.append(DaySection(title: result.isEmpty ? "All shows" : "Everything else", subtitle: nil,
                                     items: rest.map { Item(event: $0.event, reason: nil) }))
        }
        return result
    }
}

struct DayStrip: View {
    @EnvironmentObject private var store: FeedStore

    var days: [Date]
    var selected: Date
    var onSelect: (Date) -> Void

    private var zone: TimeZone { store.city?.timeZone ?? .current }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    let isOn = store.calendar.isDate(day, inSameDayAs: selected)
                    Button {
                        onSelect(day)
                    } label: {
                        VStack(spacing: 2) {
                            Text(Format.weekday(day, zone)).font(.caption2.weight(.semibold))
                            Text(Format.dayNumber(day, zone)).font(.title3.weight(.bold))
                        }
                        .frame(width: 52, height: 56)
                        .background(isOn ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(isOn ? Color.black : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Format.fullDay(day, zone))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}

struct PersonalizeCard: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars").font(.title2).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Make this yours").font(.headline)
                    Text("Pick your venues and the music you like").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) { SetupView() }
    }
}

struct FreshnessFooter: View {
    @EnvironmentObject private var store: FeedStore

    var body: some View {
        if let generated = store.feed?.generatedAt {
            VStack(spacing: 2) {
                Text("Listings updated \(generated.formatted(.relative(presentation: .named)))")
                if let error = store.lastError { Text(error) }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
    }
}

extension View {
    func marqueeDestinations() -> some View {
        navigationDestination(for: Event.self) { EventDetailView(event: $0) }
            .navigationDestination(for: Venue.self) { VenueDetailView(venue: $0) }
    }
}
