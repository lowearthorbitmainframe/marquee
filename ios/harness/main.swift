import AppKit
import SwiftUI

// Runs the real app code on a Mac, with no Xcode, against the real feed:
//   logic checks first, then renders each screen to preview/*.png.
@MainActor func run() async {
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    var feed = try! decoder.decode(Feed.self, from: Data(contentsOf: root.appendingPathComponent("data/los-angeles.json")))
    if let data = try? Data(contentsOf: root.appendingPathComponent("data/artists.json")),
       let cache = try? JSONDecoder().decode([String: ArtistRecord].self, from: data) {
        for (key, r) in cache where r.genre != nil || r.related != nil {
            feed.artists[key] = ArtistInfo(name: r.name, genre: r.genre, appleUrl: r.appleUrl, image: r.image, fans: r.fans, related: r.related)
        }
    }
    let store = FeedStore(); store.install(feed)
    let suite = UserDefaults(suiteName: "marquee.harness")!
    suite.removePersistentDomain(forName: "marquee.harness")
    let taste = TasteStore(defaults: suite)

    var failures = 0
    func check(_ ok: Bool, _ label: String) { print(ok ? "ok   \(label)" : "FAIL \(label)"); if !ok { failures += 1 } }

    check(feed.events.count > 300, "feed decodes: \(feed.events.count) events, \(feed.venues.count) venues, \(feed.artists.count) artists")
    check(ArtistKey.make("The Beyoncé") == "beyonce", "artist key strips the and accents")
    check(ArtistKey.make("Simon & Garfunkel") == "simonandgarfunkel", "artist key handles ampersand")

    let echoplex = feed.events.filter { $0.venueId == "echoplex" }
    check(!echoplex.isEmpty, "Echoplex has \(echoplex.count) shows")
    check(Set(echoplex.map(\.id)).isDisjoint(with: feed.events.filter { $0.venueId == "the-echo" }.map(\.id)), "Echoplex and Echo stay separate")

    var q = EventQuery(); q.search = "echoplex"
    check(feed.events.filter { q.matches($0, store: store, followed: []) }.count == echoplex.count, "search by venue finds Echoplex shows")
    let target = echoplex.first { !$0.artists.isEmpty } ?? echoplex[0]
    q = EventQuery(); q.search = target.artists.first ?? target.title
    check(feed.events.contains { $0.id == target.id && q.matches($0, store: store, followed: []) }, "search by artist finds the show")
    q = EventQuery(); q.myVenuesOnly = true
    check(!q.matches(target, store: store, followed: []), "my-venues filter excludes unfollowed")
    check(q.matches(target, store: store, followed: ["echoplex"]), "my-venues filter includes followed")

    let days = Set(feed.events.map { store.calendar.startOfDay(for: $0.start) })
    check(store.sortedDays.count == days.count, "events grouped into \(days.count) LA days")
    let zone = feed.city.timeZone
    let sample = feed.events.first { $0.venueId == "echoplex" }!
    print("     sample: \(sample.title) \(Format.fullDay(sample.start, zone)) \(Format.time(sample.start, zone))")

    do {
        let artist = target.artists[0]
        let fav = Recommender(taste: TasteProfile(favoriteArtists: [artist]), feed: feed).recommend(target)
        check(fav.score >= 100 && fav.isForYou, "favorite artist ranks as For You: \(fav.reason ?? "")")
    }
    if let (event, name, similar) = feed.events.lazy.compactMap({ e -> (Event, String, String)? in
        for a in e.artists { if let r = feed.artists[ArtistKey.make(a)]?.related?.first { return (e, a, r) } }; return nil }).first {
        let rec = Recommender(taste: TasteProfile(favoriteArtists: [similar]), feed: feed).recommend(event)
        check(rec.isForYou && rec.reason?.contains(similar) == true, "similar-artist pick: \(rec.reason ?? "none") (\(name))")
    } else { print("skip similar-artist check: no enrichment yet") }
    var dismissedTaste = TasteProfile(); dismissedTaste.dismissedEvents = [target.id]
    check(Recommender(taste: dismissedTaste, feed: feed).recommend(target).score < 0, "dismissed show is hidden")

    let service = MusicService.spotify.url(for: "Sigur Rós & Friends", info: nil)
    check(service?.absoluteString == "https://open.spotify.com/search/Sigur%20R%C3%B3s%20%26%20Friends/artists", "Spotify link encodes names: \(service?.absoluteString ?? "nil")")
    check(MusicService.youtube.url(for: "AC/DC", info: nil) != nil, "YouTube link handles a slash")

    // Render with a realistic profile.
    taste.profile = TasteProfile(followedVenues: ["echoplex", "the-echo", "lodge-room", "teragram-ballroom"], favoriteArtists: ["Slow Pulp", "Big Thief"], genres: ["Indie Rock", "Alternative"], finishedSetup: true)
    let out = root.appendingPathComponent("ios/preview")
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    func render<V: View>(_ name: String, _ view: V, height: CGFloat = 844) async {
        let width: CGFloat = name == "icon" ? 512 : 390
        let content = view.environmentObject(store).environmentObject(taste).tint(Theme.accent).preferredColorScheme(.dark).environment(\.colorScheme, .dark)
        let host = NSHostingView(rootView: content.frame(width: width, height: height))
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        window.orderBack(nil)
        try? await Task.sleep(nanoseconds: 3_500_000_000)
        host.layoutSubtreeIfNeeded()
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name + ".png"))
        window.orderOut(nil)
        print("rendered \(name)")
    }
    await render("tonight", TonightView())
    await render("browse", BrowseView())
    await render("venues", VenuesView())
    let detail = echoplex.first { $0.artists.count >= 2 } ?? echoplex[0]
    await render("event", NavigationStack { EventDetailView(event: detail) }, height: 1000)
    await render("you", YouView())
    await render("setup", SetupView())
    await render("icon", AppIconArt(), height: 512)
    print(failures == 0 ? "ALL CHECKS PASSED" : "\(failures) CHECKS FAILED")
    exit(failures == 0 ? 0 : 1)
}

struct AppIconArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.11, green: 0.09, blue: 0.16), Color(red: 0.05, green: 0.04, blue: 0.08)], startPoint: .top, endPoint: .bottom)
            RoundedRectangle(cornerRadius: 44).strokeBorder(Theme.accent, lineWidth: 14).padding(62)
            Text("M").font(.system(size: 250, weight: .black, design: .rounded)).foregroundStyle(Theme.accent)
            ForEach(0..<8, id: \.self) { i in
                let t = CGFloat(i) / 7 * 320 - 160
                Group {
                    Circle().frame(width: 20, height: 20).offset(x: t, y: -192)
                    Circle().frame(width: 20, height: 20).offset(x: t, y: 192)
                }.foregroundStyle(Color(red: 1, green: 0.93, blue: 0.75))
            }
        }
    }
}

struct ArtistRecord: Decodable { var name: String; var genre: String?; var appleUrl: String?; var image: String?; var fans: Int?; var related: [String]? }

NSApplication.shared.setActivationPolicy(.accessory)
Task { @MainActor in await run() }
NSApplication.shared.run()
