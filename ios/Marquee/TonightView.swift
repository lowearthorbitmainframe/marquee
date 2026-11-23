import SwiftUI

struct TonightView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore

    @State private var selectedDay: Date?
    @AppStorage("tonight.category") private var savedCategory = ""
    // Browse's filters, folded in here.
    @State private var search = ""
    @State private var range: BrowseRange = .day
    @State private var genre: String?
    @State private var venueId: String?
    @State private var myVenuesOnly = false
    @State private var picksDate = false

    private var category: Binding<EventCategory?> {
        Binding(get: { EventCategory(rawValue: savedCategory) }, set: { savedCategory = $0?.rawValue ?? "" })
    }

    private var zone: TimeZone { store.city?.timeZone ?? .current }
    private var day: Date { selectedDay ?? store.today }
    private var upcomingDays: [Date] {
        (0..<14).compactMap { store.calendar.date(byAdding: .day, value: $0, to: store.today) }
    }
    private var isSearching: Bool { !search.trimmingCharacters(in: .whitespaces).isEmpty }

    private var query: EventQuery {
        var query = EventQuery()
        query.search = search
        query.myVenuesOnly = myVenuesOnly
        query.category = category.wrappedValue
        query.genre = genre
        query.venueId = venueId
        return query
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                    CenteredScreenTitle(text: title)
                    if !isSearching {
                        HStack(spacing: 8) {
                            Picker("Show", selection: $range) {
                                ForEach(BrowseRange.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            Button {
                                picksDate = true
                            } label: {
                                Image(systemName: "calendar")
                                    .font(.title3)
                                    .frame(width: 44, height: 36)
                                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Pick a date")
                        }
                        DayStrip(days: stripDays, selected: day) { selectedDay = $0 }
                    }
                    CategoryChips(selection: category)
                    filters

                    if taste.profile.isEmpty && !isSearching {
                        PersonalizeCard()
                    }

                    if store.feed == nil {
                        ContentUnavailableView("Couldn't load shows", systemImage: "exclamationmark.triangle", description: Text("Pull down to try again."))
                            .padding(.top, 40)
                    } else if isSearching || range != .day {
                        groupedList
                    } else {
                        dayList
                    }
                    FreshnessFooter().padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .refreshable { await store.refresh() }
            .screenBackground()
            .screenTitle(title)
            .searchable(text: $search, prompt: "Artist, show, venue or genre")
            .marqueeDestinations()
            .sheet(isPresented: $picksDate) { datePicker }
        }
    }

    /// The next two weeks, plus a date picked further out so it shows as selected.
    private var stripDays: [Date] {
        var days = upcomingDays
        if let picked = selectedDay, !days.contains(where: { store.calendar.isDate($0, inSameDayAs: picked) }) {
            days.append(picked)
        }
        return days
    }

    // MARK: One day: For You, then everything else

    @ViewBuilder private var dayList: some View {
        let lists = sections
        if lists.isEmpty && !(category.wrappedValue == .museum && !store.exhibitions(on: day).isEmpty) {
            ContentUnavailableView("Nothing listed", systemImage: "moon.zzz", description: Text(emptyMessage))
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
        // Exhibitions belong under All (as one summary row) and Museums (in full),
        // not under Music, Comedy and the other show filters.
        if (category.wrappedValue == nil || category.wrappedValue == .museum) && genre == nil && venueId == nil && !myVenuesOnly {
            OnViewSection(exhibitions: store.exhibitions(on: day), expanded: category.wrappedValue == .museum) {
                category.wrappedValue = .museum
            }
        }
    }

    private var emptyMessage: String {
        if genre != nil || venueId != nil || myVenuesOnly { return "Nothing matches these filters this day." }
        if let category = category.wrappedValue { return "Nothing in \(category.label.lowercased()) this day. Try All." }
        return "No shows found for this day yet."
    }

    // MARK: A week, a month, or a search: grouped by day

    private var interval: DateInterval {
        let calendar = store.calendar
        switch range {
        case .day:
            return DateInterval(start: day, end: calendar.date(byAdding: .day, value: 1, to: day) ?? day)
        case .week:
            return DateInterval(start: day, end: calendar.date(byAdding: .day, value: 7, to: day) ?? day)
        case .month:
            return DateInterval(start: day, end: calendar.date(byAdding: .month, value: 1, to: day) ?? day)
        }
    }

    /// A search looks across every date; otherwise only the chosen range.
    private var groups: [(day: Date, events: [Event])] {
        let followed = taste.profile.followedVenues
        let query = query
        return store.sortedDays.compactMap { date in
            if !isSearching, !(interval.start..<interval.end).contains(date) { return nil }
            let events = store.events(on: date).filter { query.matches($0, store: store, followed: followed) }
            return events.isEmpty ? nil : (date, events)
        }
    }

    @ViewBuilder private var groupedList: some View {
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

    // MARK: Filters

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button("All genres") { genre = nil }
                    let category = category.wrappedValue
                    if category == nil || category == .music || category == .party {
                        Section("Music") {
                            ForEach(store.genres, id: \.self) { name in Button(name) { genre = name } }
                        }
                    }
                    if category == nil || category == .film {
                        Section("Film") {
                            ForEach(EventTags.filmTags, id: \.self) { tag in Button(EventTags.label(tag)) { genre = tag } }
                        }
                    }
                    if category == nil || category == .comedy {
                        Section("Comedy") {
                            ForEach(EventTags.comedyTags, id: \.self) { tag in Button(EventTags.label(tag)) { genre = tag } }
                        }
                    }
                } label: {
                    FilterMenuLabel(title: genre.map(EventTags.label) ?? "Genre", isOn: genre != nil)
                }
                Menu {
                    Button("All venues") { venueId = nil }
                    ForEach(store.venues) { venue in
                        Button(venue.name) { venueId = venue.id }
                    }
                } label: {
                    FilterMenuLabel(title: venueId.flatMap { store.venuesById[$0]?.name } ?? "Venue", isOn: venueId != nil)
                }
                Chip(title: "My venues", isOn: myVenuesOnly) { myVenuesOnly.toggle() }
            }
        }
        .scrollClipDisabled()
    }

    private var datePicker: some View {
        NavigationStack {
            DatePicker("Date", selection: Binding(get: { day }, set: {
                selectedDay = store.calendar.startOfDay(for: $0)
                picksDate = false
            }), in: store.today..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.timeZone, zone)
                .padding()
                .navigationTitle("Pick a date")
                .inlineTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { picksDate = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Today") { selectedDay = nil; picksDate = false }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    private var title: String {
        if isSearching { return "Search" }
        let isToday = store.calendar.isDate(day, inSameDayAs: store.today)
        switch range {
        case .day:
            return isToday ? "Tonight in \(store.regionName)" : Format.fullDay(day, zone)
        case .week:
            return isToday ? "This week in \(store.regionName)" : "Week of \(Format.monthDay(day, zone))"
        case .month:
            return isToday ? "This month in \(store.regionName)" : "Month from \(Format.monthDay(day, zone))"
        }
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

    /// Picks first, then everything else (your venues' shows included), each show appearing once.
    private var sections: [DaySection] {
        let recommender = Recommender(taste: taste.profile, feed: store.feed)
        let followed = taste.profile.followedVenues
        let query = query
        let scored = store.events(on: day)
            .filter { query.matches($0, store: store, followed: followed) }
            .map { (event: $0, match: recommender.recommend($0)) }
            .filter { $0.match.score >= 0 }

        let picks = scored.filter(\.match.isForYou).sorted { $0.match.score > $1.match.score }
        let pickIDs = Set(picks.map(\.event.id))
        let rest = scored.filter { !pickIDs.contains($0.event.id) }

        var result: [DaySection] = []
        if !picks.isEmpty {
            result.append(DaySection(title: "For you", subtitle: "Based on your artists and genres",
                                     items: picks.map { Item(event: $0.event, reason: $0.match.reason) }))
        }
        if !rest.isEmpty {
            result.append(DaySection(title: result.isEmpty ? "All shows" : "Everything else", subtitle: nil,
                                     items: rest.map { Item(event: $0.event, reason: nil) }))
        }
        return result
    }
}

/// A filter that opens a menu, drawn like a chip.
struct FilterMenuLabel: View {
    var title: String
    var isOn: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isOn ? Theme.accent : Theme.card, in: Capsule())
        .shadow(color: isOn ? Theme.chipGlow : .clear, radius: 8)
        .foregroundStyle(isOn ? Theme.onAccent : Color.primary)
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
                        .shadow(color: isOn ? Theme.chipGlow : .clear, radius: 8)
                        .foregroundStyle(isOn ? Theme.onAccent : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Format.fullDay(day, zone))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
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
                    Text("Pick your venues and what you're into").font(.subheadline).foregroundStyle(.secondary)
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

/// Exhibitions on view this day. Under "Museums" they're listed in full; under "All"
/// they fold into one row that switches to that filter.
struct OnViewSection: View {
    var exhibitions: [Event]
    var expanded: Bool
    var showAll: () -> Void

    var body: some View {
        if exhibitions.isEmpty {
            EmptyView()
        } else if expanded {
            SectionHeader(title: "On view", subtitle: "Exhibitions you can see this day").padding(.top, 8)
            ForEach(exhibitions) { EventLink(event: $0) }
        } else {
            Button(action: showAll) {
                HStack(spacing: 12) {
                    Image(systemName: EventCategory.museum.symbol)
                        .font(.title3)
                        .foregroundStyle(EventCategory.museum.color)
                        .frame(width: 44, height: 44)
                        .background(EventCategory.museum.wash, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(exhibitions.count) museum exhibitions on view").font(.headline)
                        Text("Exhibitions you can catch this day").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
}
