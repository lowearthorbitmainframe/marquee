import SwiftUI

/// Every artist imported from Apple Music or Spotify, each with a checkmark. Switching one off
/// keeps them out of For You, Your Artists and new-show alerts, and survives the weekly re-check.
/// Artists with upcoming shows in the city you're browsing come first, since those are the ones
/// that actually change what you see.
struct LibraryArtistsView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var playing: [String: Int] {
        var counts: [String: Int] = [:]
        for event in store.events where !event.cancelled {
            for name in event.artists { counts[ArtistKey.make(name), default: 0] += 1 }
        }
        return counts
    }

    private var filtered: [String] {
        let key = ArtistKey.make(query)
        let all = taste.profile.allImportedArtists.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return key.isEmpty ? all : all.filter { ArtistKey.make($0).contains(key) }
    }

    var body: some View {
        let counts = playing
        let withShows = filtered.filter { counts[ArtistKey.make($0)] != nil }
        let others = filtered.filter { counts[ArtistKey.make($0)] == nil }
        NavigationStack {
            List {
                Section {
                    Text("Uncheck anyone you don't want shaping For You, Your Artists or alerts. Re-importing your library won't turn them back on.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                if !withShows.isEmpty {
                    Section("Playing in \(store.city?.name ?? "town") (\(withShows.count))") {
                        ForEach(withShows, id: \.self) { row($0, shows: counts[ArtistKey.make($0)]) }
                    }
                }
                if !others.isEmpty {
                    Section("No shows here right now (\(others.count))") {
                        ForEach(others, id: \.self) { row($0, shows: nil) }
                    }
                }
            }
            .searchable(text: $query, prompt: "Find an artist")
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Your library artists")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func row(_ artist: String, shows: Int?) -> some View {
        let on = !taste.profile.isExcluded(artist)
        return Button {
            taste.toggleExcluded(artist)
        } label: {
            HStack {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Theme.accent : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(artist).foregroundStyle(on ? .primary : .secondary)
                    if let shows {
                        Text(shows == 1 ? "1 upcoming show" : "\(shows) upcoming shows")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(on ? "On" : "Off")
    }
}
