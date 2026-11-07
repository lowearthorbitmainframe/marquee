import SwiftUI
#if os(iOS)
import MediaPlayer
#endif

struct YouView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore

    private var saved: [Event] {
        store.events.filter { taste.profile.savedEvents.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Saved shows")
                        if saved.isEmpty {
                            Text("Tap the heart on a show to keep it here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(saved) { EventLink(event: $0, showsDate: true) }
                    }
                    NewShowsSection()
                    YourArtistsShows()
                    RegionSection()
                    AlertsSection()
                    ArtistsEditor()
                    GenresEditor()
                    HiddenArtistsSection()
                    StatusSection()
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("You")
            .marqueeDestinations()
        }
    }
}

struct RegionSection: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Browsing", subtitle: "Your artists, venues and saved shows come with you")
            FlowLayout {
                ForEach(store.regions) { region in
                    Chip(title: region.name, isOn: region.id == store.regionId) {
                        Task { await store.switchRegion(to: region.id) }
                    }
                }
            }
            HStack {
                Text("Home area").font(.subheadline.weight(.semibold))
                Spacer()
                Menu {
                    ForEach(store.regions) { region in
                        Button(region.name) { taste.profile.homeRegion = region.id }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(store.regions.first { $0.id == taste.profile.alertRegion }?.name ?? "Los Angeles")
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: 44)
                }
            }
            Text("New show alerts only cover your home area.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct AlertsSection: View {
    @EnvironmentObject private var taste: TasteStore

    @State private var denied = false

    private var isOn: Binding<Bool> {
        Binding(
            get: { taste.profile.alertsEnabled == true },
            set: { wantsAlerts in
                if !wantsAlerts {
                    taste.profile.alertsEnabled = false
                    return
                }
                Task {
                    let allowed = await Alerts.requestPermission()
                    taste.profile.alertsEnabled = allowed
                    denied = !allowed
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("New show alerts").font(.headline)
                    let count = taste.profile.watchedArtistKeys.count
                    Text("Watching \(count) \(count == 1 ? "artist" : "artists") from your library, follows and hearted shows")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Theme.accent)
            if denied {
                Text("Notifications are off for Scenester. Turn them on in Settings to get alerts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Doubles as a way to check a library import: every row is an artist it found.
struct YourArtistsShows: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore

    @State private var showsAll = false

    private let previewCount = 5

    var body: some View {
        let result = taste.profile.shows(in: store.feed)
        if !taste.profile.favoriteArtists.isEmpty || !taste.profile.libraryArtists.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Your artists in \(store.city?.name ?? "town")", subtitle: subtitle(result))
                ForEach(showsAll ? result.events : Array(result.events.prefix(previewCount))) {
                    EventLink(event: $0, showsDate: true)
                }
                if result.events.count > previewCount {
                    Button(showsAll ? "Show fewer" : "Show all \(result.events.count)") { showsAll.toggle() }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }

    private func subtitle(_ result: (events: [Event], artists: Set<String>)) -> String {
        if result.events.isEmpty { return "None of your artists have listed shows yet" }
        let shows = result.events.count == 1 ? "1 upcoming show" : "\(result.events.count) upcoming shows"
        return "\(result.artists.count) of your artists, \(shows)"
    }
}

/// The first-run sheet: venues, then music.
struct SetupView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore
    @Environment(\.dismiss) private var dismiss

    @State private var showsAllVenues = false

    /// The busiest rooms first; the long tail waits behind "Show all".
    private var venues: [Venue] {
        let sorted = store.venues.sorted { (store.showCounts[$0.id] ?? 0) > (store.showCounts[$1.id] ?? 0) }
        return showsAllVenues ? sorted : Array(sorted.prefix(24))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Your venues", subtitle: "Their shows come first")
                        FlowLayout {
                            ForEach(venues) { venue in
                                Chip(title: venue.name, isOn: taste.profile.followedVenues.contains(venue.id)) {
                                    taste.toggleVenue(venue.id)
                                }
                            }
                        }
                        if store.venues.count > 24 {
                            Button(showsAllVenues ? "Show fewer" : "Show all \(store.venues.count) venues") { showsAllVenues.toggle() }
                                .frame(minHeight: 44)
                        }
                    }
                    ArtistsEditor()
                    GenresEditor()
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("What do you like?")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        taste.profile.finishedSetup = true
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ArtistsEditor: View {
    @EnvironmentObject private var taste: TasteStore

    @State private var draft = ""
    @State private var importMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Artists you love", subtitle: "Used to find them, and bands like them")

            HStack(spacing: 8) {
                TextField("Add an artist", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(add)
                Button("Add", action: add)
                    .buttonStyle(.bordered)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !taste.profile.favoriteArtists.isEmpty {
                FlowLayout {
                    ForEach(taste.profile.favoriteArtists, id: \.self) { artist in
                        Chip(title: artist, isOn: true) { taste.toggleFavorite(artist) }
                            .accessibilityHint("Removes this artist")
                    }
                }
            }

            #if os(iOS)
            Button {
                Task { await importLibrary() }
            } label: {
                Label("Import from Apple Music library", systemImage: "music.note.list")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            #endif

            if !taste.profile.libraryArtists.isEmpty {
                Text("\(taste.profile.libraryArtists.count) artists imported from your library")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let importMessage {
                Text(importMessage).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func add() {
        let name = draft.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if !taste.isFavorite(name) { taste.toggleFavorite(name) }
        draft = ""
    }

    #if os(iOS)
    private func importLibrary() async {
        let status = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else {
            importMessage = "Allow Media & Apple Music access in Settings to import."
            return
        }
        let names = (MPMediaQuery.artists().collections ?? []).compactMap { $0.representativeItem?.artist }
        taste.profile.libraryArtists = Array(Set(names)).sorted()
        importMessage = names.isEmpty ? "No artists found. Check that Sync Library is on in the Music section of Settings." : nil
    }
    #endif
}

struct GenresEditor: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore

    private var groups: [(title: String, genres: [String])] {
        [("Music", store.genres), ("Film", EventTags.filmTags), ("Comedy", EventTags.comedyTags)]
    }

    private var everyGenre: Set<String> { Set(groups.flatMap(\.genres)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Genres")
                Spacer()
                Button("Select all") { taste.profile.genres.formUnion(everyGenre) }
                    .disabled(everyGenre.isSubset(of: taste.profile.genres))
                Button("Clear") { taste.profile.genres.removeAll() }
                    .disabled(taste.profile.genres.isEmpty)
                    .padding(.leading, 12)
            }
            .font(.subheadline.weight(.medium))
            ForEach(groups, id: \.title) { group in
                if !group.genres.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        FlowLayout {
                            ForEach(group.genres, id: \.self) { genre in
                                Chip(title: EventTags.label(genre), isOn: taste.profile.genres.contains(genre)) { taste.toggleGenre(genre) }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Artists you gave a thumbs down. Tap one to see their shows again.
struct HiddenArtistsSection: View {
    @EnvironmentObject private var taste: TasteStore

    var body: some View {
        let hidden = taste.profile.dislikedArtists ?? []
        if !hidden.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Hidden artists", subtitle: "Their shows don't appear. Tap one to bring them back.")
                FlowLayout {
                    ForEach(hidden, id: \.self) { artist in
                        Chip(title: artist, isOn: false) { taste.toggleDisliked(artist) }
                            .accessibilityHint("Shows this artist again")
                    }
                }
            }
        }
    }
}

/// Shows that alerts told you about, newest first.
struct NewShowsSection: View {
    @EnvironmentObject private var store: FeedStore

    var body: some View {
        let events = AlertHistory.recentEvents(in: store.feed)
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Newly announced", subtitle: "From your alerts in the last two weeks")
            if events.isEmpty {
                Text("Nothing yet. When an alert finds a new show by one of your artists, it lands here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(events) { EventLink(event: $0, showsDate: true) }
        }
    }
}

struct StatusSection: View {
    @EnvironmentObject private var store: FeedStore

    private var failed: [SourceStatus] { (store.feed?.sources ?? []).filter { !$0.ok } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FreshnessFooter()
            if !failed.isEmpty {
                Text("Older listings for: \(failed.map(\.source).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
