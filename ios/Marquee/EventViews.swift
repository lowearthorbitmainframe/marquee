import SwiftUI

struct Poster: View {
    var url: String?
    var title: String
    var symbol = "music.mic"
    /// When set, the placeholder takes the event type's color.
    var tint: Color?

    var body: some View {
        // The overlay keeps a filled image from widening whatever layout holds it.
        LinearGradient(colors: tint.map { [$0.opacity(0.55), $0.opacity(0.18)] } ?? Self.colors(for: title),
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: symbol).font(.title2).foregroundStyle(.white.opacity(0.5))
            }
            .overlay {
                if let url, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        }
                    }
                }
            }
            .clipped()
        .accessibilityHidden(true)
    }

    private static func colors(for title: String) -> [Color] {
        let hue = Double(abs(title.unicodeScalars.reduce(7) { ($0 &* 31) &+ Int($1.value) }) % 360) / 360
        return [Color(hue: hue, saturation: 0.55, brightness: 0.45), Color(hue: hue + 0.08, saturation: 0.65, brightness: 0.22)]
    }
}

struct EventRow: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore

    var event: Event
    var reason: String?
    var showsDate = false

    private var zone: TimeZone { store.city?.timeZone ?? .current }

    var body: some View {
        HStack(spacing: 12) {
            Poster(url: event.image, title: event.title, symbol: event.kind.symbol, tint: event.kind.color)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                    .strikethrough(event.cancelled)
                Text(detailLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let badge {
                    Text(badge.text)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(badge.color)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                taste.toggleSaved(event)
            } label: {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.body)
                    .foregroundStyle(isSaved ? Theme.accent : Color.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "Remove from saved" : "Save show")
        }
        .padding(10)
        .padding(.leading, 4)
        .background(Theme.card.overlay(event.kind.wash))
        .overlay(alignment: .leading) {
            Rectangle().fill(event.kind.color.opacity(0.55)).frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(event.kind.label): \(event.title)")
    }

    private var isSaved: Bool { taste.profile.savedEvents.contains(event.id) }

    private var detailLine: String {
        var parts: [String] = []
        if showsDate { parts.append(Format.monthDay(event.start, zone)) }
        parts.append(event.timeTBA == true ? "Time TBA" : Format.time(event.start, zone))
        parts.append(store.venue(for: event)?.name ?? "")
        return parts.joined(separator: " · ")
    }

    private var badge: (text: String, color: Color)? {
        if event.cancelled { return ("Cancelled", .red) }
        if event.soldOut { return ("Sold out", .orange) }
        if let reason { return (reason, Theme.accent) }
        if event.kind.hasMusicLinks, let genre = store.genres(for: event).first { return (genre, .secondary) }
        if event.kind != .music { return (event.kind.label, event.kind.color) }
        return nil
    }
}

struct EventLink: View {
    @EnvironmentObject private var taste: TasteStore

    var event: Event
    var reason: String?
    var showsDate = false

    var body: some View {
        NavigationLink(value: event) {
            EventRow(event: event, reason: reason, showsDate: showsDate)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let headliner = event.artists.first {
                Button(role: .destructive) {
                    taste.toggleDisliked(headliner)
                } label: {
                    Label("Hide shows by \(headliner)", systemImage: "hand.thumbsdown")
                }
            }
        }
    }
}

struct EventDetailView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore
    @Environment(\.openURL) private var openURL

    var event: Event

    private var zone: TimeZone { store.city?.timeZone ?? .current }
    private var venue: Venue? { store.venue(for: event) }
    private var isSaved: Bool { taste.profile.savedEvents.contains(event.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Poster(url: event.image, title: event.title, symbol: event.kind.symbol, tint: event.kind.color)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 6) {
                    CategoryTag(category: event.kind)
                    Text(event.title).font(.title2.weight(.bold))
                    if let tour = event.tour {
                        Text(tour).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(Format.fullDay(event.start, zone)).font(.headline).foregroundStyle(Theme.accent)
                    Text(timeLine).font(.subheadline).foregroundStyle(.secondary)
                }

                if let ticket = event.ticketUrl.flatMap(URL.init(string:)) {
                    Button {
                        openURL(ticket)
                    } label: {
                        Label(ticketLabel, systemImage: "ticket")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                }

                if !event.artists.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if event.kind.hasMusicLinks {
                            SectionHeader(title: "Lineup", subtitle: "Tap a service to hear them")
                            ForEach(event.artists, id: \.self) { ArtistCard(name: $0) }
                        } else {
                            SectionHeader(title: "Featuring", subtitle: event.kind == .comedy ? "Tap to find their podcast, specials and clips" : nil)
                            ForEach(event.artists, id: \.self) { PerformerRow(name: $0, isComedian: event.kind == .comedy) }
                        }
                    }
                }

                if let venue {
                    VenueSummary(venue: venue)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .inlineTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    taste.toggleSaved(event)
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                }
                .accessibilityLabel(isSaved ? "Remove from saved" : "Save show")
            }
        }
    }

    private var ticketLabel: String {
        if event.cancelled { return "Cancelled" }
        return event.soldOut ? "Sold out, check tickets" : "Get tickets"
    }

    private var timeLine: String {
        var parts: [String] = []
        if let doors = event.doors { parts.append("Doors \(Format.time(doors, zone))") }
        parts.append(event.timeTBA == true ? "Time TBA" : "Show \(Format.time(event.start, zone))")
        if let age = event.age { parts.append(age) }
        if let price = event.price { parts.append(price) }
        return parts.joined(separator: " · ")
    }
}

struct ArtistCard: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var taste: TasteStore
    @Environment(\.openURL) private var openURL

    var name: String

    private var info: ArtistInfo? { store.info(forArtist: name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Poster(url: info?.image, title: name)
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    ArtistNameButton(name: name, info: info, searchHint: "band")
                    if let genre = info?.genre {
                        Text(genre).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                ArtistOpinionButtons(name: name)
            }

            let pages = ArtistLink.available(info)
            if !pages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pages, id: \.0) { kind, url in
                            Button {
                                openURL(url)
                            } label: {
                                Label(kind.label, systemImage: kind.symbol)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 36)
                                    .background(Color.white.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(MusicService.allCases) { service in
                    Button {
                        if let url = service.url(for: name, info: info) { openURL(url) }
                    } label: {
                        Label(service.rawValue, systemImage: service.symbol)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// A comedian or other performer: their pages, plus podcast, Spotify and YouTube.
struct PerformerRow: View {
    @EnvironmentObject private var store: FeedStore
    @Environment(\.openURL) private var openURL

    var name: String
    var isComedian = true

    private var info: ArtistInfo? { store.info(forArtist: name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ArtistNameButton(name: name, info: info, searchHint: isComedian ? "comedian" : "")
                Spacer(minLength: 0)
                ArtistOpinionButtons(name: name)
            }

            let pages = ArtistLink.available(info)
            if !pages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pages, id: \.0) { kind, url in
                            Button {
                                openURL(url)
                            } label: {
                                Label(kind.label, systemImage: kind.symbol)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 36)
                                    .background(Color.white.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if isComedian { HStack(spacing: 8) {
                ForEach(ComedyService.allCases) { service in
                    Button {
                        if let url = service.url(for: name, info: info) { openURL(url) }
                    } label: {
                        Label(service.rawValue, systemImage: service.symbol)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(service.isDirect(info) ? "Opens their page" : "Searches for them")
                }
            } }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Follow (star) or never see again (thumbs down).
struct ArtistOpinionButtons: View {
    @EnvironmentObject private var taste: TasteStore

    var name: String

    var body: some View {
        HStack(spacing: 0) {
            Button {
                if taste.isDisliked(name) { taste.toggleDisliked(name) }
                taste.toggleFavorite(name)
            } label: {
                Image(systemName: taste.isFavorite(name) ? "star.fill" : "star")
                    .foregroundStyle(taste.isFavorite(name) ? Theme.accent : Color.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(taste.isFavorite(name) ? "Unfollow \(name)" : "Follow \(name)")

            Button {
                taste.toggleDisliked(name)
            } label: {
                Image(systemName: taste.isDisliked(name) ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .foregroundStyle(taste.isDisliked(name) ? Color.red.opacity(0.8) : Color.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(taste.isDisliked(name) ? "Show \(name) again" : "Hide shows by \(name)")
        }
    }
}

/// An artist's name that opens their website, Instagram or TikTok.
struct ArtistNameButton: View {
    @Environment(\.openURL) private var openURL

    var name: String
    var info: ArtistInfo?
    var searchHint: String

    private var knowsAPage: Bool { !ArtistLink.available(info).isEmpty }

    var body: some View {
        Button {
            if let url = ArtistLink.primary(for: name, info: info, searchHint: searchHint) { openURL(url) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(name).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                Image(systemName: knowsAPage ? "arrow.up.right" : "magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(knowsAPage ? "Opens their page" : "Searches the web for them")
    }
}

struct VenueSummary: View {
    var venue: Venue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Venue")
            NavigationLink(value: venue) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(venue.name).font(.headline)
                        if let address = venue.address {
                            Text(address).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }
}
