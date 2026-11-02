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
                    ArtistsEditor()
                    GenresEditor()
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

/// The first-run sheet: venues, then music.
struct SetupView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Your venues", subtitle: "Their shows come first")
                        FlowLayout {
                            ForEach(store.venues) { venue in
                                Chip(title: venue.name, isOn: taste.profile.followedVenues.contains(venue.id)) {
                                    taste.toggleVenue(venue.id)
                                }
                            }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Genres")
            FlowLayout {
                ForEach(store.genres, id: \.self) { genre in
                    Chip(title: genre, isOn: taste.profile.genres.contains(genre)) { taste.toggleGenre(genre) }
                }
            }
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
