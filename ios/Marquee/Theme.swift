import SwiftUI

/// The app's color schemes. "amber" is the original; "red" is red and black with white type;
/// "goth" is black, oxblood and bone with serif type; "synth" is synthwave: an indigo night,
/// sunset gradients and neon; "hipster" is early-2000s indie: cream paper, ink, thrift-store
/// colors and zine type; "blade" is Blade Runner 2049: orange haze over blue-black, cyan and
/// hologram pink, thin wide capitals and monospaced readouts. Debug builds can try one with
/// `-theme red`, `goth`, `synth`, `hipster` or `blade`.
enum ThemeStyle: String {
    case amber, red, goth, synth, hipster, blade

    static var current: ThemeStyle { ThemeStyle(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .amber }

    /// The one light theme.
    var isLight: Bool { self == .hipster }

    /// Themes that draw their own centered titles and colored tab icons.
    var isCustom: Bool { self != .amber }
}

enum Theme {
    static var style: ThemeStyle { ThemeStyle.current }

    private static let cherry = Color(red: 0.86, green: 0.11, blue: 0.16)
    private static let oxblood = Color(red: 0.55, green: 0.04, blue: 0.09)
    // Synthwave: sunset orange, hot pink, violet and neon blue on an indigo night.
    static let sunsetOrange = Color(red: 1.00, green: 0.55, blue: 0.24)
    static let sunsetPink = Color(red: 1.00, green: 0.30, blue: 0.62)
    static let sunsetViolet = Color(red: 0.62, green: 0.36, blue: 1.00)
    static let neonBlue = Color(red: 0.30, green: 0.80, blue: 1.00)
    // Blade Runner 2049: irradiated orange haze, blue-black night, cyan and hologram pink.
    static let haze = Color(red: 0.88, green: 0.47, blue: 0.16)
    static let replicantCyan = Color(red: 0.25, green: 0.78, blue: 0.82)
    static let hologramPink = Color(red: 0.95, green: 0.33, blue: 0.60)
    static let ash = Color(red: 0.91, green: 0.89, blue: 0.85)
    // Early-2000s indie: cream paper, near-black ink, mustard and brick.
    static let paper = Color(red: 0.95, green: 0.92, blue: 0.86)
    static let hipsterInk = Color(red: 0.14, green: 0.12, blue: 0.11)
    static let mustard = Color(red: 0.85, green: 0.63, blue: 0.11)
    static let brick = Color(red: 0.71, green: 0.27, blue: 0.18)
    /// Warm bone white, the goth theme's ink.
    private static let bone = Color(red: 0.91, green: 0.87, blue: 0.80)

    static var accent: Color {
        switch style {
        case .amber: Color(red: 1.0, green: 0.72, blue: 0.27)
        case .red: cherry
        case .goth: oxblood
        case .synth: sunsetOrange
        case .hipster: mustard
        case .blade: haze
        }
    }
    /// Text and icons drawn on top of the accent color.
    static var onAccent: Color {
        switch style {
        case .amber: .black
        case .red: .white
        case .goth: bone
        case .synth: .white
        case .hipster: hipsterInk
        case .blade: .black
        }
    }
    /// The default color of text.
    static var ink: Color { style == .goth ? bone : style == .synth ? .white : style == .hipster ? hipsterInk : style == .blade ? ash : .primary }
    static var background: Color {
        switch style {
        case .amber: Color(red: 0.06, green: 0.06, blue: 0.08)
        case .red: Color(red: 0.03, green: 0.02, blue: 0.02)
        case .goth: .black
        case .synth: Color(red: 0.04, green: 0.02, blue: 0.10)
        case .hipster: paper
        case .blade: Color(red: 0.04, green: 0.05, blue: 0.06)
        }
    }
    static var card: Color {
        switch style {
        case .amber: Color(red: 0.12, green: 0.12, blue: 0.15)
        case .red: Color(red: 0.13, green: 0.06, blue: 0.07)
        case .goth: Color(red: 0.05, green: 0.04, blue: 0.045)
        case .synth: Color(red: 0.11, green: 0.06, blue: 0.22).opacity(0.85)
        case .hipster: Color(red: 0.99, green: 0.97, blue: 0.93)
        case .blade: Color(red: 0.08, green: 0.09, blue: 0.10).opacity(0.85)
        }
    }
    /// A hairline drawn around cards; the goth theme outlines rather than fills.
    static var cardBorder: Color? {
        switch style {
        case .goth: Color(red: 0.38, green: 0.05, blue: 0.09)
        case .synth: sunsetViolet.opacity(0.55)
        case .hipster: hipsterInk.opacity(0.22)
        case .blade: replicantCyan.opacity(0.28)
        default: nil
        }
    }
    /// The neon-tube glow on a selected day or filter (synthwave only).
    static var chipGlow: Color { style == .synth ? sunsetOrange.opacity(0.9) : .clear }
    /// A soft neon glow around outlined cards (synthwave only).
    static var cardGlow: Color { style == .synth ? sunsetViolet.opacity(0.35) : .clear }

    /// The sunset gradient used on synthwave titles and the retro sun.
    static let sunset = LinearGradient(colors: [Color(red: 1.0, green: 0.78, blue: 0.30), sunsetOrange, sunsetPink, sunsetViolet],
                                       startPoint: .top, endPoint: .bottom)
    static var separator: Color { style.isLight ? hipsterInk.opacity(0.12) : Color.white.opacity(0.08) }
    /// The selected tab's icon; the others use `tabUnselected`.
    static var tabSelected: Color {
        switch style {
        case .amber: accent
        case .red: Color(white: 0.95)
        case .goth: bone
        case .synth: .white
        case .hipster: hipsterInk
        case .blade: ash
        }
    }
    /// Screen titles; nil keeps the system's white.
    static var titleColor: UIColor? {
        switch style {
        case .amber: nil
        case .red: UIColor(cherry)
        case .goth: UIColor(red: 0.72, green: 0.07, blue: 0.12, alpha: 1)
        case .synth: UIColor(red: 1.00, green: 0.55, blue: 0.24, alpha: 1)
        case .hipster: UIColor(red: 0.14, green: 0.12, blue: 0.11, alpha: 1)
        case .blade: UIColor(red: 0.91, green: 0.89, blue: 0.85, alpha: 1)
        }
    }
    static var tabUnselected: UIColor? {
        switch style {
        case .amber: nil
        case .red: UIColor(cherry)
        case .goth: UIColor(red: 0.62, green: 0.06, blue: 0.11, alpha: 1)
        case .synth: UIColor(red: 0.68, green: 0.55, blue: 1.00, alpha: 1)
        case .hipster: UIColor(red: 0.55, green: 0.50, blue: 0.45, alpha: 1)
        case .blade: UIColor(red: 0.88, green: 0.47, blue: 0.16, alpha: 1)
        }
    }

    // MARK: Type

    /// The big screen title: a high-contrast serif in the goth theme.
    static var titleFont: Font {
        switch style {
        case .goth: .custom("Bodoni 72", size: 36, relativeTo: .largeTitle).weight(.bold)
        case .synth: .custom("Futura-Bold", size: 38, relativeTo: .largeTitle)
        case .hipster: .custom("HelveticaNeue-CondensedBlack", size: 46, relativeTo: .largeTitle)
        case .blade: .custom("AvenirNext-UltraLight", size: 34, relativeTo: .largeTitle)
        default: .largeTitle.weight(.bold)
        }
    }
    /// Section headers like "All shows": small capitals in the goth theme.
    static var headerFont: Font {
        switch style {
        case .goth: .custom("Bodoni 72 Smallcaps", size: 24, relativeTo: .title3)
        case .synth: .system(size: 14, weight: .heavy, design: .rounded)
        case .hipster: .custom("AmericanTypewriter-Semibold", size: 20, relativeTo: .title3)
        case .blade: .custom("Menlo-Regular", size: 13, relativeTo: .footnote)
        default: .title3.weight(.bold)
        }
    }
    /// Event names on listings.
    static var eventTitleFont: Font {
        switch style {
        case .goth: .custom("Bodoni 72", size: 20, relativeTo: .headline).weight(.bold)
        case .hipster: .custom("HelveticaNeue-Bold", size: 17, relativeTo: .headline)
        case .blade: .custom("AvenirNext-DemiBold", size: 17, relativeTo: .headline)
        default: .headline
        }
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

    @ViewBuilder func screenBackground() -> some View {
        if Theme.style == .blade {
            // Las Vegas haze at the top, settling into the blue-black of the city at night.
            background(LinearGradient(stops: [
                .init(color: Color(red: 0.42, green: 0.18, blue: 0.06), location: 0),
                .init(color: Color(red: 0.16, green: 0.08, blue: 0.05), location: 0.22),
                .init(color: Theme.background, location: 0.5),
                .init(color: Color(red: 0.02, green: 0.04, blue: 0.07), location: 1),
            ], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        } else if Theme.style == .synth {
            // An indigo night: violet at the top fading to deep blue-black.
            background(LinearGradient(colors: [Color(red: 0.16, green: 0.06, blue: 0.32), Theme.background, Color(red: 0.02, green: 0.03, blue: 0.10)],
                                      startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        } else {
            background(Theme.background.ignoresSafeArea())
        }
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if Theme.style == .blade {
                Text("// " + title.uppercased())
                    .font(Theme.headerFont)
                    .tracking(3)
                    .foregroundStyle(Theme.replicantCyan)
            } else if Theme.style == .hipster {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.lowercased()).font(Theme.headerFont)
                    Rectangle().fill(Theme.brick).frame(width: 28, height: 3)
                }
            } else if Theme.style == .synth {
                // Neon capitals, spaced wide, with a faint glow.
                Text(title.uppercased())
                    .font(Theme.headerFont)
                    .tracking(3)
                    .foregroundStyle(Theme.neonBlue)
                    .shadow(color: Theme.neonBlue.opacity(0.7), radius: 6)
            } else if Theme.style == .goth {
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
        if Theme.style == .synth { return neonColor }
        if Theme.style == .hipster { return thriftColor }
        if Theme.style == .blade { return cityColor }
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

    /// Neon for synthwave: electric blue, hot pink, sunset orange, violet, cyan and peach.
    private var neonColor: Color {
        switch self {
        case .music: Color(red: 0.35, green: 0.62, blue: 1.00)
        case .comedy: Color(red: 1.00, green: 0.36, blue: 0.68)
        case .film: Color(red: 1.00, green: 0.60, blue: 0.26)
        case .theater: Color(red: 0.72, green: 0.45, blue: 1.00)
        case .party: Color(red: 0.25, green: 0.90, blue: 1.00)
        case .museum: Color(red: 1.00, green: 0.78, blue: 0.56)
        case .other: Color(white: 0.75)
        }
    }

    /// Thrift-store colors for the hipster theme: mustard, teal, brick, olive, dusty blue, plum.
    private var thriftColor: Color {
        switch self {
        case .music: Color(red: 0.80, green: 0.58, blue: 0.10)
        case .comedy: Color(red: 0.71, green: 0.27, blue: 0.18)
        case .film: Color(red: 0.18, green: 0.48, blue: 0.47)
        case .theater: Color(red: 0.47, green: 0.27, blue: 0.42)
        case .party: Color(red: 0.36, green: 0.48, blue: 0.62)
        case .museum: Color(red: 0.46, green: 0.47, blue: 0.22)
        case .other: Color(white: 0.45)
        }
    }

    /// Blade Runner 2049 colors: haze amber, hologram pink, cyan, sodium blue, acid yellow, dust.
    private var cityColor: Color {
        switch self {
        case .music: Color(red: 0.91, green: 0.57, blue: 0.23)
        case .comedy: Color(red: 0.94, green: 0.33, blue: 0.60)
        case .film: Color(red: 0.21, green: 0.77, blue: 0.81)
        case .theater: Color(red: 0.49, green: 0.55, blue: 0.94)
        case .party: Color(red: 0.85, green: 0.82, blue: 0.29)
        case .museum: Color(red: 0.66, green: 0.63, blue: 0.59)
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
        .scrollClipDisabled()
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
            .shadow(color: isOn ? Theme.chipGlow : .clear, radius: 8)
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
            titleText
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
                // The big title fades as it rises, while the bar's small one fades in, both tied
                // to how far it has scrolled rather than switching at one point.
                .opacity(1 - Double(scrollState.progress))
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                    scroll?.update(frame: frame)
                }
                .onAppear { scroll?.settle() }
                // Lazy lists drop rows that scroll far off screen, so disappearing counts as scrolled away.
                .onDisappear { scroll?.progress = 1 }
        }
    }

    @ViewBuilder private var titleText: some View {
        if Theme.style == .synth {
            SynthTitle(text: text)
        } else if Theme.style == .hipster {
            ZineTitle(text: text)
        } else if Theme.style == .blade {
            CityTitle(text: text)
        } else {
            Text(text)
                .font(Theme.titleFont)
                .foregroundStyle(Color(uiColor: Theme.titleColor ?? .white))
        }
    }

    @EnvironmentObject private var scrollState: TitleScrollState
    private var scroll: TitleScrollState? { scrollState }
}

/// How far the big title has scrolled up under the bar, from 0 (resting) to 1 (gone), shared by
/// the title and the bar.
final class TitleScrollState: ObservableObject {
    @Published var progress: CGFloat = 0
    private var latest: CGRect?
    private var restingTop: CGFloat?

    /// Remembers where the title sits once the screen has finished laying out. Pulling down to
    /// refresh moves it lower than that, which simply counts as no scroll.
    func settle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.restingTop == nil, let latest = self.latest else { return }
            self.restingTop = latest.minY
        }
    }

    /// The swap happens while the title's last line (about 40 points) slides under the bar, so
    /// the small title takes over right where the big one's last line disappears.
    func update(frame: CGRect) {
        latest = frame
        guard let rest = restingTop, frame.height > 0 else { return }
        let window: CGFloat = 40
        let clamped = min(max((rest + window - frame.maxY) / window, 0), 1)
        if abs(clamped - progress) > 0.005 || clamped == 0 || clamped == 1 { progress = clamped }
    }
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
                    barTitle
                        .lineLimit(1)
                        // Grows into place as the big title leaves, in step with the scroll.
                        .opacity(Double(scroll.progress))
                        // Starts a little larger and settles to size, so it reads as the big line shrinking into place.
                        .scaleEffect(1.25 - 0.25 * scroll.progress)
                }
            }
            .environmentObject(scroll)
    }

    /// The bar's small title. Blade Runner keeps just the lead word ("TONIGHT") in the big
    /// title's thin, wide capitals.
    @ViewBuilder private var barTitle: some View {
        switch Theme.style {
        case .blade:
            Text(CityTitle.split(text).lead.uppercased())
                .font(.custom("AvenirNext-UltraLight", size: 18, relativeTo: .headline))
                .tracking(7)
                .foregroundStyle(Theme.ash)
        case .goth:
            Text(text).font(.custom("Bodoni 72", size: 18, relativeTo: .headline).weight(.bold))
                .foregroundStyle(Color(uiColor: Theme.titleColor ?? .white))
        default:
            Text(text).font(.headline)
                .foregroundStyle(Color(uiColor: Theme.titleColor ?? .white))
        }
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


/// The synthwave screen title: upright and clean. A neon blue overline ("TONIGHT IN") above
/// the place or screen name in bold Futura filled with the sunset gradient, and a short glowing
/// rule underneath that runs through the palette.
struct SynthTitle: View {
    var text: String

    private var parts: (overline: String?, main: String) {
        if let range = text.range(of: " in ") {
            return (String(text[..<range.upperBound]).trimmingCharacters(in: .whitespaces), String(text[range.upperBound...]))
        }
        return (nil, text)
    }

    private static let rule = LinearGradient(colors: [Theme.sunsetOrange, Theme.sunsetPink, Theme.sunsetViolet, Theme.neonBlue],
                                             startPoint: .leading, endPoint: .trailing)

    var body: some View {
        VStack(spacing: 6) {
            if let overline = parts.overline {
                Text(overline.uppercased())
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(Theme.neonBlue)
                    .shadow(color: Theme.neonBlue.opacity(0.8), radius: 6)
            }
            Text(parts.main)
                .font(Theme.titleFont)
                .foregroundStyle(Theme.sunset)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .shadow(color: Theme.sunsetPink.opacity(0.55), radius: 14)
            Capsule()
                .fill(Self.rule)
                .frame(width: 120, height: 3)
                .shadow(color: Theme.sunsetPink.opacity(0.9), radius: 6)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}


/// The hipster screen title, like an early-2000s show flyer: a typewritten lead-in over the
/// name in lowercase condensed black Helvetica, finished with a period and a strip of mustard tape.
struct ZineTitle: View {
    var text: String

    private var parts: (overline: String?, main: String) {
        if let range = text.range(of: " in ") {
            return (String(text[..<range.upperBound]).trimmingCharacters(in: .whitespaces), String(text[range.upperBound...]))
        }
        return (nil, text)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let overline = parts.overline {
                Text(overline.lowercased())
                    .font(.custom("AmericanTypewriter", size: 17, relativeTo: .headline))
                    .foregroundStyle(Theme.hipsterInk.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.mustard.opacity(0.85))
                    .rotationEffect(.degrees(-2))
                    .padding(.bottom, 4)
            }
            (Text(parts.main.lowercased()) + Text(".").foregroundColor(Theme.brick))
                .font(Theme.titleFont)
                .foregroundStyle(Theme.hipsterInk)
                .tracking(-1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}


extension View {
    /// Listing art: rounded corners, or in the hipster theme a white Polaroid frame with a
    /// thicker bottom edge and a slight shadow.
    @ViewBuilder func polaroid() -> some View {
        if Theme.style == .hipster {
            padding(4).padding(.bottom, 8)
                .background(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                .rotationEffect(.degrees(-1.5))
        } else {
            clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}


/// The Blade Runner 2049 screen title: the city in thin, widely spaced capitals with a faint
/// orange glow, and the lead word ("TONIGHT") under it in the same type, smaller.
struct CityTitle: View {
    var text: String

    /// "Tonight in Los Angeles" becomes lead "Tonight" and place "Los Angeles"; other titles are all place.
    static func split(_ text: String) -> (lead: String, place: String?) {
        if let range = text.range(of: " in ") {
            return (String(text[..<range.lowerBound]), String(text[range.upperBound...]))
        }
        return (text, nil)
    }

    var body: some View {
        let parts = Self.split(text)
        VStack(spacing: 10) {
            Text((parts.place ?? parts.lead).uppercased())
                .font(Theme.titleFont)
                .tracking(9)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: Theme.haze.opacity(0.7), radius: 12)
            if parts.place != nil {
                Text(parts.lead.uppercased())
                    .font(.custom("AvenirNext-UltraLight", size: 20, relativeTo: .title3))
                    .tracking(8)
                    .shadow(color: Theme.haze.opacity(0.5), radius: 8)
            }
        }
        .foregroundStyle(Theme.ash)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
