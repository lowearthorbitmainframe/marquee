import SwiftUI

enum Theme {
    static let accent = Color(red: 1.0, green: 0.72, blue: 0.27)
    static let background = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let card = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let separator = Color.white.opacity(0.08)
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

struct Chip: View {
    var title: String
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isOn ? Theme.accent : Theme.card, in: Capsule())
                .foregroundStyle(isOn ? Color.black : Color.primary)
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
