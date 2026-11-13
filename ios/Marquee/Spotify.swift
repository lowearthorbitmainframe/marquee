import AuthenticationServices
import CryptoKit
import Foundation
import Security
import SwiftUI

/// Reads the artists in someone's Spotify library: who they follow, their top artists and
/// the artists on their Liked Songs. Uses Spotify's sign-in with PKCE, so the app needs no
/// secret. The read-only refresh token is kept in the phone's keychain so the library can be
/// re-read weekly without signing in again; "Disconnect" (or a failed refresh) deletes it.
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
        let token = try await exchange(form: [
            .init(name: "grant_type", value: "authorization_code"),
            .init(name: "code", value: code),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "client_id", value: clientID),
            .init(name: "code_verifier", value: verifier),
        ])
        return try await collectArtists(token: token)
    }

    /// Whether the app can re-read the library without a new sign-in.
    static var isConnected: Bool { Keychain.read(refreshKey) != nil }

    /// Re-reads the library with the saved refresh token. Returns nil when there's no
    /// connection or Spotify no longer accepts it (the token is then forgotten).
    static func refreshArtists() async -> [String]? {
        guard let refresh = Keychain.read(refreshKey) else { return nil }
        do {
            let token = try await exchange(form: [
                .init(name: "grant_type", value: "refresh_token"),
                .init(name: "refresh_token", value: refresh),
                .init(name: "client_id", value: clientID),
            ])
            return try await collectArtists(token: token)
        } catch ImportError.server {
            disconnect()
            return nil
        } catch {
            return nil  // Offline and the like: try again next time.
        }
    }

    static func disconnect() { Keychain.delete(refreshKey) }

    private static let refreshKey = "spotify.refresh"

    // MARK: Sign-in

    private static func exchange(form items: [URLQueryItem]) async throws -> String {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = items
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Token: Decodable { var access_token: String?; var refresh_token: String?; var error_description: String? }
        let token = try JSONDecoder().decode(Token.self, from: data)
        guard let access = token.access_token else { throw ImportError.server(token.error_description ?? "no access token") }
        // Spotify may hand out a new refresh token each time; keep the latest.
        if let refresh = token.refresh_token { Keychain.save(refresh, for: refreshKey) }
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

/// A few strings in the keychain, readable only on this device after first unlock.
enum Keychain {
    private static let service = "com.bryanstage.marquee"

    static func save(_ value: String, for key: String) {
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}
