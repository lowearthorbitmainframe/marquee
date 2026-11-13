import Foundation
#if os(iOS)
import MediaPlayer
#endif

/// Re-reads the Apple Music and Spotify libraries someone already imported, about once a
/// week, so artists they've added since show up in their alerts and recommendations
/// without importing again.
@MainActor
enum LibrarySync {
    static let interval: TimeInterval = 7 * 24 * 60 * 60

    /// Runs when the app comes to the front. Returns how many new artists were found.
    @discardableResult
    static func runIfDue(taste: TasteStore, force: Bool = false) async -> Int {
        let hasAppleMusic = !taste.profile.libraryArtists.isEmpty
        let hasSpotify = SpotifyImport.isConnected
        guard hasAppleMusic || hasSpotify else { return 0 }
        if !force, let last = taste.profile.librarySyncedAt, Date().timeIntervalSince(last) < interval { return 0 }
        let before = Set(taste.profile.importedArtists.map(ArtistKey.make))

        #if os(iOS)
        // Only if access was already granted: this never asks.
        if hasAppleMusic, MPMediaLibrary.authorizationStatus() == .authorized {
            let names = (MPMediaQuery.artists().collections ?? []).compactMap { $0.representativeItem?.artist }
            if !names.isEmpty { taste.profile.libraryArtists = Array(Set(names)).sorted() }
        }
        #endif
        if hasSpotify, let names = await SpotifyImport.refreshArtists(), !names.isEmpty {
            taste.profile.spotifyArtists = names
        }
        taste.profile.librarySyncedAt = Date()
        return Set(taste.profile.importedArtists.map(ArtistKey.make)).subtracting(before).count
    }
}
