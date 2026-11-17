import SwiftUI
#if os(iOS)
import EventKit
import EventKitUI

/// "Add to Calendar" on a show page. It opens the system's new-event sheet, already filled in,
/// so people pick the calendar and can change anything before saving. Since iOS 17 that sheet
/// needs no calendar permission: the app never sees the person's calendars.
struct AddToCalendarButton: View {
    var event: Event
    var venue: Venue?
    var zone: TimeZone

    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Label("Add to Calendar", systemImage: "calendar.badge.plus")
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.card, in: Circle())
                .overlay {
                    if let border = Theme.cardBorder { Circle().strokeBorder(border.opacity(0.6), lineWidth: 1) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add to Calendar")
        .sheet(isPresented: $showing) {
            CalendarEventSheet(event: event, venue: venue, zone: zone)
                .ignoresSafeArea()
        }
    }
}

private struct CalendarEventSheet: UIViewControllerRepresentable {
    var event: Event
    var venue: Venue?
    var zone: TimeZone
    @Environment(\.dismiss) private var dismiss

    private static let store = EKEventStore()

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = Self.store
        controller.event = makeEvent()
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }

    private func makeEvent() -> EKEvent {
        let item = EKEvent(eventStore: Self.store)
        item.title = event.title
        item.timeZone = zone
        if event.isExhibition {
            // An exhibition becomes an all-day reminder for today (or its opening day).
            let day = max(event.start, Date())
            item.isAllDay = true
            item.startDate = day
            item.endDate = day
        } else if event.timeTBA == true {
            item.isAllDay = true
            item.startDate = event.start
            item.endDate = event.start
        } else {
            // Doors are when people need to be there; shows without an end get three hours.
            item.startDate = event.doors ?? event.start
            item.endDate = event.end.flatMap { $0 > event.start ? $0 : nil } ?? event.start.addingTimeInterval(3 * 3600)
        }
        if let venue {
            item.location = [venue.name, venue.address].compactMap { $0 }.joined(separator: ", ")
        }
        let link = (event.ticketUrl ?? event.url).flatMap(URL.init(string:))
        item.url = link
        var notes: [String] = []
        if let doors = event.doors, event.timeTBA != true {
            notes.append("Doors \(Format.time(doors, zone)) · Show \(Format.time(event.start, zone))")
        }
        if !event.artists.isEmpty, event.artists != [event.title] { notes.append(event.artists.joined(separator: ", ")) }
        if let link { notes.append("Tickets: \(link.absoluteString)") }
        notes.append("Found on Scenester")
        item.notes = notes.joined(separator: "\n")
        return item
    }
}
#else
/// The Mac test harness has no calendar sheet.
struct AddToCalendarButton: View {
    var event: Event
    var venue: Venue?
    var zone: TimeZone
    var body: some View { Image(systemName: "calendar.badge.plus").frame(width: 44, height: 44) }
}
#endif
