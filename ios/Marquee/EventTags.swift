import Foundation

/// Genres for film and comedy, read from the show's title. Music genres come
/// from each artist instead. Tags read "Film · Horror" so they never collide
/// with a music genre and can sit in the same list of liked genres.
enum EventTags {
    private static let film: [(String, String)] = [
        ("Horror", #"\b(horror|slasher|zombie|giallo|creature|haunt|evil dead|scream|exorcis|vampire)"#),
        ("35mm & 70mm", #"\b(35 ?mm|70 ?mm|16 ?mm|nitrate|on film|imax)\b"#),
        ("Documentary", #"\b(documentar|doc\b|docs\b)"#),
        ("Animation & anime", #"\b(anime|animat|ghibli|miyazaki|cartoon)"#),
        ("Cult & midnight", #"\b(cult|midnight|grindhouse|b-movie|exploitation|everything is terrible|camp classic)"#),
        ("Q&A & premieres", #"(q ?& ?a|q and a|in person|premiere|conversation|director|filmmaker|guest)"#),
        ("Classics & restorations", #"\b(classic|restor|4k|anniversary|noir|silent)"#),
        ("Double features & marathons", #"\b(double feature|triple feature|marathon|all-night)"#),
        ("Sing-alongs & parties", #"\b(sing-?along|quote-?along|party|interactive)"#),
        ("Festivals & series", #"\b(festival|fest\b|series|retrospective|program)"#),
    ]

    private static let comedy: [(String, String)] = [
        ("Improv", #"\b(improv|improvis|harold|groundlings|ucb)"#),
        ("Sketch", #"\bsketch"#),
        ("Storytelling", #"\b(story|stories|storytell)"#),
        ("Podcasts", #"\b(podcast|live taping|episode)"#),
        ("Open mics", #"\b(open mic|mic night)"#),
        ("Showcases & late night", #"\b(late night|showcase|best of|all[- ]stars?|headliners|the originals|presents)"#),
        ("Musical comedy", #"\b(musical|songs?\b|sing)"#),
        ("Drag & variety", #"\b(drag|variety|cabaret|burlesque|magic)"#),
    ]

    static let filmTags = film.map { "Film · \($0.0)" }
    static let comedyTags = comedy.map { "Comedy · \($0.0)" } + ["Comedy · Stand-up"]

    static func label(_ tag: String) -> String {
        tag.components(separatedBy: " · ").last ?? tag
    }

    static func tags(for event: Event) -> [String] {
        let title = event.title
        func matches(_ pattern: String) -> Bool {
            title.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        switch event.kind {
        case .film:
            return film.filter { matches($0.1) }.map { "Film · \($0.0)" }
        case .comedy:
            let found = comedy.filter { matches($0.1) }.map { "Comedy · \($0.0)" }
            // A show that isn't improv, sketch or the like is a stand-up set.
            return found.isEmpty ? ["Comedy · Stand-up"] : found
        default:
            return []
        }
    }
}
