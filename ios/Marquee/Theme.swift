import SwiftUI

/// The app's color schemes. "amber" is the original; "red" is red and black with white type;
/// "goth" is black, oxblood and bone with serif type. Debug builds can try one with the
/// launch argument `-theme red` or `-theme goth`.
enum ThemeStyle: String {
    case amber, red, goth

    static var current: ThemeStyle { ThemeStyle(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .amber }

    /// Themes that draw their own centered titles and colored tab icons.
    var isCustom: Bool { self != .amber }
}

enum Theme {
    static var style: ThemeStyle { ThemeStyle.current }

    private static let cherry = Color(red: 0.86, green: 0.11, blue: 0.16)
    private static let oxblood = Color(red: 0.55, green: 0.04, blue: 0.09)
    /// Warm bone white, the goth theme's ink.
    private static let bone = Color(red: 0.91, green: 0.87, blue: 0.80)

    static var accent: Color {
        switch style {
        case .amber: Color(red: 1.0, green: 0.72, blue: 0.27)
        case .red: cherry
        case .goth: oxblood
        }
    }
    /// Text and icons drawn on top of the accent color.
    static var onAccent: Color {
        switch style {
        case .amber: .black
        case .red: .white
        case .goth: bone
        }
    }
    /// The default color of text.
    static var ink: Color { style == .goth ? bone : .primary }
    static var background: Color {
        switch style {
        case .amber: Color(red: 0.06, green: 0.06, blue: 0.08)
        case .red: Color(red: 0.03, green: 0.02, blue: 0.02)
        case .goth: .black
        }
    }
    static var card: Color {
        switch style {
        case .amber: Color(red: 0.12, green: 0.12, blue: 0.15)
        case .red: Color(red: 0.13, green: 0.06, blue: 0.07)
        case .goth: Color(red: 0.05, green: 0.04, blue: 0.045)
        }
    }
    /// A hairline drawn around cards; the goth theme outlines rather than fills.
    static var cardBorder: Color? { style == .goth ? Color(red: 0.38, green: 0.05, blue: 0.09) : nil }
    static let separator = Color.white.opacity(0.08)
    /// The selected tab's icon; the others use `tabUnselected`.
    static var tabSelected: Color {
        switch style {
        case .amber: accent
        case .red: Color(white: 0.95)
        case .goth: bone
        }
    }
    /// Screen titles; nil keeps the system's white.
    static var titleColor: UIColor? {
        switch style {
        case .amber: nil
        case .red: UIColor(cherry)
        case .goth: UIColor(red: 0.72, green: 0.07, blue: 0.12, alpha: 1)
        }
    }
    static var tabUnselected: UIColor? {
        switch style {
        case .amber: nil
        case .red: UIColor(cherry)
        case .goth: UIColor(red: 0.62, green: 0.06, blue: 0.11, alpha: 1)
        }
    }

    // MARK: Type

    /// The big screen title: a high-contrast serif in the goth theme.
    static var titleFont: Font {
        style == .goth ? .custom("Bodoni 72", size: 36, relativeTo: .largeTitle).weight(.bold) : .largeTitle.weight(.bold)
    }
    /// Section headers like "All shows": small capitals in the goth theme.
    static var headerFont: Font {
        style == .goth ? .custom("Bodoni 72 Smallcaps", size: 24, relativeTo: .title3) : .title3.weight(.bold)
    }
    /// Event names on listings.
    static var eventTitleFont: Font {
        style == .goth ? .custom("Bodoni 72", size: 20, relativeTo: .headline).weight(.bold) : .headline
    }
}

enum Format {
    private static func formatter(_ template: String, _ zone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = zone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    static func time(_ date: Date, _ zone: TimeZone) -> String { formatter("h:mm a", zone).string(from: date) }
    static func weekday(_ date: Date, _ zone: TimeZone) -> String { formatter("EEE", zone).string(from: date).uppercased() }
    static func dayNumber(_ date: Date, _ zone: TimeZone) -> String { formatter("d", zone).string(from: date) }
    static func monthDay(_ date: Date, _ zone: TimeZone) -> String { formatter("MMM d", zone).string(from: date) }
    static func fullDay(_ date: Date, _ zone: TimeZone) -> String { formatter("EEEE, MMMM d", zone).string(from: date) }
    static func month(_ date: Date, _ zone: TimeZone) -> String { formatter("MMMM yyyy", zone).string(from: date) }
    static func year(_ date: Date, _ zone: TimeZone) -> String { formatter("yyyy", zone).string(from: date) }
}

extension View {
    /// Compact navigation title on iPhone. The macOS branch exists so the shared
    /// views can be compile-checked and previewed on a Mac without Xcode.
    @ViewBuilder func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if Theme.style == .goth {
                // A small dagger and the title in small capitals, ruled underneath.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("†").font(Theme.headerFont).foregroundStyle(Color(uiColor: Theme.titleColor ?? .white))
                    Text(title).font(Theme.headerFont).tracking(1.5)
                }
            } else {
                Text(title).font(Theme.headerFont)
            }
            if let subtitle {
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

extension EventCategory {
    /// Each kind of event keeps one muted color everywhere. Amber stays reserved
    /// for your own selections and "For you" reasons, so none of these use it.
    var color: Color {
        if Theme.style == .red { return nightColor }
        if Theme.style == .goth { return mourningColor }
        return switch self {
        case .music: Color(red: 0.45, green: 0.58, blue: 0.80)
        case .comedy: Color(red: 0.78, green: 0.47, blue: 0.60)
        case .film: Color(red: 0.60, green: 0.52, blue: 0.80)
        case .theater: Color(red: 0.80, green: 0.52, blue: 0.44)
        case .party: Color(red: 0.42, green: 0.70, blue: 0.56)
        case .museum: Color(red: 0.70, green: 0.66, blue: 0.48)
        case .other: Color(white: 0.55)
        }
    }

    /// Muted, dusty tones that sit quietly beside the red accent and still tell the kinds
    /// apart: ochre, dusty rose, slate teal, faded lavender, sage and stone. None is red.
    private var nightColor: Color {
        switch self {
        case .music: Color(red: 0.80, green: 0.67, blue: 0.42)
        case .comedy: Color(red: 0.80, green: 0.55, blue: 0.63)
        case .film: Color(red: 0.49, green: 0.66, blue: 0.73)
        case .theater: Color(red: 0.63, green: 0.57, blue: 0.78)
        case .party: Color(red: 0.55, green: 0.71, blue: 0.59)
        case .museum: Color(red: 0.75, green: 0.70, blue: 0.62)
        case .other: Color(white: 0.65)
        }
    }

    /// Mourning colors for the goth theme: tarnished silver, dried rose, pewter, amethyst,
    /// absinthe and bone.
    private var mourningColor: Color {
        switch self {
        case .music: Color(red: 0.68, green: 0.68, blue: 0.72)
        case .comedy: Color(red: 0.66, green: 0.38, blue: 0.44)
        case .film: Color(red: 0.47, green: 0.53, blue: 0.63)
        case .theater: Color(red: 0.54, green: 0.40, blue: 0.66)
        case .party: Color(red: 0.52, green: 0.63, blue: 0.43)
        case .museum: Color(red: 0.78, green: 0.73, blue: 0.62)
        case .other: Color(white: 0.5)
        }
    }

    /// How strongly the stripe on each listing shows the color.
    var stripeOpacity: Double { Theme.style == .amber ? 0.55 : 0.8 }

    /// A dark, see-through wash of the color for card backgrounds. The red theme keeps
    /// cards red-black, so the category shows only in the stripe and label.
    var wash: Color { color.opacity(Theme.style == .amber ? 0.14 : Theme.style == .red ? 0.05 : 0) }
}

/// The small colored tag that names an event's kind.
struct CategoryTag: View {
    var category: EventCategory

    var body: some View {
        Label(category.label, systemImage: category.symbol)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(category.color.opacity(Theme.style == .amber ? 0.16 : 0.2), in: Capsule())
            .foregroundStyle(category.color)
    }
}

/// A scrolling row of category chips, with "All" first.
struct CategoryChips: View {
    @Binding var selection: EventCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "All", isOn: selection == nil) { selection = nil }
                ForEach(EventCategory.filters) { category in
                    Chip(title: category.label, isOn: selection == category, dot: category.color) {
                        selection = selection == category ? nil : category
                    }
                }
            }
        }
    }
}

struct Chip: View {
    var title: String
    var isOn: Bool
    /// A category's color, shown as a dot so the chips double as a legend.
    var dot: Color?
    var action: () -> Void

    init(title: String, isOn: Bool, dot: Color? = nil, action: @escaping () -> Void) {
        self.title = title
        self.isOn = isOn
        self.dot = dot
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 8, height: 8)
                }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isOn ? (dot.map { $0.opacity(0.38) } ?? Theme.accent) : Theme.card, in: Capsule())
            .overlay { if isOn, let dot { Capsule().strokeBorder(dot.opacity(0.6), lineWidth: 1) } }
            .foregroundStyle(isOn && dot == nil ? Theme.onAccent : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(width: proposal.width ?? 320, subviews: subviews)
        return CGSize(width: proposal.width ?? result.size.width, height: result.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (subview, origin) in zip(subviews, result.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxWidth = max(maxWidth, x)
            rowHeight = max(rowHeight, size.height)
        }
        return (origins, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

/// The red theme's screen title: large, red and centered. iOS can't center its own large
/// titles, so the red theme draws this at the top of the content and hides the system one.
struct CenteredScreenTitle: View {
    var text: String

    var body: some View {
        if Theme.style.isCustom {
            Text(text)
                .font(Theme.titleFont)
                .foregroundStyle(Color(uiColor: Theme.titleColor ?? .white))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
                // Tells the bar to show a small title once this one is behind it. Lazy lists drop
                // rows that scroll far off screen, so disappearing counts as scrolled away too.
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { bottom in
                    scroll?.showSmall = bottom < 110
                }
                .onDisappear { scroll?.showSmall = true }
        }
    }

    @EnvironmentObject private var scrollState: TitleScrollState
    private var scroll: TitleScrollState? { scrollState }
}

/// Whether the red theme's big title has scrolled away, shared by the title and the bar.
final class TitleScrollState: ObservableObject {
    @Published var showSmall = false
}

/// The red theme's top bar: empty while the big title shows, then a small red title once it
/// has scrolled up under the bar.
private struct SmallTitleOnScroll: ViewModifier {
    var text: String
    @StateObject private var scroll = TitleScrollState()

    func body(content: Content) -> some View {
        content
            .navigationTitle(text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(text)
                        .font(Theme.style == .goth ? .custom("Bodoni 72", size: 18, relativeTo: .headline).weight(.bold) : .headline)
                        .foregroundStyle(Color(uiColor: Theme.titleColor ?? .white))
                        .lineLimit(1)
                        .opacity(scroll.showSmall ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: scroll.showSmall)
                }
            }
            .environmentObject(scroll)
    }
}

extension View {
    /// A main screen's title: the system large title, or in the red theme a centered one
    /// drawn by `CenteredScreenTitle` with the system title kept small and out of sight.
    @ViewBuilder func screenTitle(_ text: String) -> some View {
        if Theme.style.isCustom {
            modifier(SmallTitleOnScroll(text: text))
        } else {
            navigationTitle(text)
        }
    }
}
