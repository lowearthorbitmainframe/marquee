import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

/// Reads the artists in someone's Spotify library: who they follow, their top artists and
/// the artists on their Liked Songs. Uses Spotify's sign-in with PKCE, so the app needs no
/// secret, and keeps no token: each import is a fresh, read-only sign-in.
enum SpotifyImport {
    /// From developer.spotify.com. Empty until the Spotify app is set up, which hides the button.
    static var clientID: String { Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? "" }
    static var isAvailable: Bool { !clientID.isEmpty }

    static let callbackScheme = "scenester-spotify"
    static let redirectURI = "scenester-spotify://callback"
    static let scopes = "user-follow-read user-top-read user-library-read"

    enum ImportError: LocalizedError {
        case cancelled, signInFailed, server(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: "Spotify sign-in was cancelled."
            case .signInFailed: "Spotify didn't finish signing in. Try again."
            case .server(let message): "Spotify said: \(message)"
            }
        }
    }

    /// Signs in through Spotify's web page, then returns every artist name found.
    static func artists(using session: WebAuthenticationSession) async throws -> [String] {
        let verifier = randomString(64)
        let state = randomString(16)
        var authorize = URLComponents(string: "https://accounts.spotify.com/authorize")!
        authorize.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge(for: verifier)),
            .init(name: "scope", value: scopes),
            .init(name: "state", value: state),
        ]
        let callback: URL
        do {
            callback = try await session.authenticate(using: authorize.url!, callbackURLScheme: callbackScheme,
                                                      preferredBrowserSession: .shared)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            throw ImportError.cancelled
        }
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else {
            if let error = items.first(where: { $0.name == "error" })?.value, error == "access_denied" { throw ImportError.cancelled }
            throw ImportError.signInFailed
        }
        let token = try await exchange(code: code, verifier: verifier)
        return try await collectArtists(token: token)
    }

    // MARK: Sign-in

    private static func exchange(code: String, verifier: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            .init(name: "grant_type", value: "authorization_code"),
            .init(name: "code", value: code),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "client_id", value: clientID),
            .init(name: "code_verifier", value: verifier),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Token: Decodable { var access_token: String?; var error_description: String? }
        let token = try JSONDecoder().decode(Token.self, from: data)
        guard let access = token.access_token else { throw ImportError.server(token.error_description ?? "no access token") }
        return access
    }

    private static func randomString(_ length: Int) -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    private static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: Library

    private struct Artist: Decodable { var name: String }
    private struct Page<Item: Decodable>: Decodable { var items: [Item]; var next: String? }
    private struct Following: Decodable { var artists: Page<Artist> }
    private struct Failure: Decodable { struct Detail: Decodable { var message: String? }; var error: Detail? }
    private struct SavedTrack: Decodable { struct Track: Decodable { var artists: [Artist] }; var track: Track? }

    private static func collectArtists(token: String) async throws -> [String] {
        var names = Set<String>()
        // Followed artists.
        var next: String? = "https://api.spotify.com/v1/me/following?type=artist&limit=50"
        while let url = next {
            let page: Following = try await get(url, token: token)
            names.formUnion(page.artists.items.map(\.name))
            next = page.artists.next
        }
        // Top artists over the last month, six months and all time.
        for range in ["short_term", "medium_term", "long_term"] {
            let page: Page<Artist> = try await get("https://api.spotify.com/v1/me/top/artists?limit=50&time_range=\(range)", token: token)
            names.formUnion(page.items.map(\.name))
        }
        // Artists on Liked Songs, up to the 2,000 most recent.
        next = "https://api.spotify.com/v1/me/tracks?limit=50"
        var pages = 0
        while let url = next, pages < 40 {
            let page: Page<SavedTrack> = try await get(url, token: token)
            names.formUnion(page.items.flatMap { $0.track?.artists.map(\.name) ?? [] })
            next = page.next
            pages += 1
        }
        return names.filter { !$0.isEmpty }.sorted()
    }

    private static func get<T: Decodable>(_ url: String, token: String) async throws -> T {
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let message = (try? JSONDecoder().decode(Failure.self, from: data))?.error?.message ?? "HTTP \(http.statusCode)"
            // Spotify apps in development mode only allow listed users.
            if http.statusCode == 403 { throw ImportError.server("this Spotify account isn't on Scenester's list of allowed users yet") }
            throw ImportError.server(message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
