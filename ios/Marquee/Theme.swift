import SwiftUI

/// The app's color schemes. "amber" is the original; "red" is red and black with white type.
/// Debug builds can try one with the launch argument `-theme red`.
enum ThemeStyle: String {
    case amber, red

    static var current: ThemeStyle { ThemeStyle(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .amber }
}

enum Theme {
    static var style: ThemeStyle { ThemeStyle.current }

    static var accent: Color {
        style == .red ? Color(red: 0.86, green: 0.11, blue: 0.16) : Color(red: 1.0, green: 0.72, blue: 0.27)
    }
    /// Text and icons drawn on top of the accent color.
    static var onAccent: Color { style == .red ? .white : .black }
    static var background: Color {
        style == .red ? Color(red: 0.03, green: 0.02, blue: 0.02) : Color(red: 0.06, green: 0.06, blue: 0.08)
    }
    static var card: Color {
        style == .red ? Color(red: 0.13, green: 0.06, blue: 0.07) : Color(red: 0.12, green: 0.12, blue: 0.15)
    }
    static let separator = Color.white.opacity(0.08)
    /// The selected tab's icon; the others use `tabUnselected`.
    static var tabSelected: Color { style == .red ? Color(white: 0.95) : accent }
    static var tabUnselected: UIColor? { style == .red ? UIColor(red: 0.86, green: 0.11, blue: 0.16, alpha: 1) : nil }
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
            Text(title).font(.title3.weight(.bold))
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
        switch self {
        case .music: Color(red: 0.45, green: 0.58, blue: 0.80)
        case .comedy: Color(red: 0.78, green: 0.47, blue: 0.60)
        case .film: Color(red: 0.60, green: 0.52, blue: 0.80)
        case .theater: Color(red: 0.80, green: 0.52, blue: 0.44)
        case .party: Color(red: 0.42, green: 0.70, blue: 0.56)
        case .museum: Color(red: 0.70, green: 0.66, blue: 0.48)
        case .other: Color(white: 0.55)
        }
    }

    /// A dark, see-through wash of the color for card backgrounds. The red theme keeps
    /// cards red-black, so the category shows only in the stripe and label.
    var wash: Color { color.opacity(Theme.style == .red ? 0.04 : 0.14) }
}

/// The small colored tag that names an event's kind.
struct CategoryTag: View {
    var category: EventCategory

    var body: some View {
        Label(category.label, systemImage: category.symbol)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(category.color.opacity(0.16), in: Capsule())
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
