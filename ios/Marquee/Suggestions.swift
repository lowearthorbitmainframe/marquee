import CloudKit
import SwiftUI

/// A venue someone wants added. It goes to the app's CloudKit public database, where a
/// job on the owner's Mac checks the place is real, finds its listings and a contact email,
/// and starts the research for adding it.
struct VenueSuggestion: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var area: String
    var website: String
    var kind: String
    var note: String
    var regionId: String
    var created = Date()
}

@MainActor
final class SuggestionService: ObservableObject {
    static let recordType = "VenueSuggestion"

    /// Suggestions waiting to be sent, kept on the phone until CloudKit takes them.
    @Published private(set) var outbox: [VenueSuggestion] = []
    @Published private(set) var sentCount = 0

    private let defaults = UserDefaults.standard

    /// CloudKit needs an entitlement that only a paid developer team can sign. Until the app
    /// is built with it (Info.plist SuggestionsUseCloudKit), suggestions wait in the outbox.
    static var cloudEnabled: Bool { Bundle.main.object(forInfoDictionaryKey: "SuggestionsUseCloudKit") as? Bool == true }

    init() {
        if let data = defaults.data(forKey: "suggestions.outbox"),
           let saved = try? JSONDecoder().decode([VenueSuggestion].self, from: data) {
            outbox = saved
        }
        sentCount = defaults.integer(forKey: "suggestions.sent")
    }

    func submit(_ suggestion: VenueSuggestion) async {
        outbox.append(suggestion)
        save()
        await flush()
    }

    /// Sends anything in the outbox. Called after each suggestion and when the app opens.
    func flush() async {
        guard Self.cloudEnabled, !outbox.isEmpty else { return }
        let database = CKContainer.default().publicCloudDatabase
        for suggestion in outbox {
            let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: suggestion.id.uuidString))
            record["name"] = suggestion.name
            record["area"] = suggestion.area
            record["website"] = suggestion.website
            record["kind"] = suggestion.kind
            record["note"] = suggestion.note
            record["regionId"] = suggestion.regionId
            record["status"] = "new"
            do {
                _ = try await database.save(record)
                outbox.removeAll { $0.id == suggestion.id }
                sentCount += 1
            } catch let error as CKError where error.code == .serverRecordChanged {
                // Already sent on an earlier try.
                outbox.removeAll { $0.id == suggestion.id }
            } catch {
                // Not signed in to iCloud, offline and so on: keep it for next time.
                break
            }
        }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(outbox), forKey: "suggestions.outbox")
        defaults.set(sentCount, forKey: "suggestions.sent")
    }
}

struct SuggestVenueSection: View {
    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Missing a venue?", subtitle: "Tell us about a room, theater, club or museum that isn't listed")
            Button {
                isPresented = true
            } label: {
                Label("Suggest a venue", systemImage: "plus.bubble")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $isPresented) { SuggestVenueView() }
    }
}

struct SuggestVenueView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var suggestions: SuggestionService
    @Environment(\.dismiss) private var dismiss

    var initialName = ""

    @State private var name = ""
    @State private var area = ""
    @State private var website = ""
    @State private var kind: EventCategory = .music
    @State private var note = ""
    @State private var sent = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// A venue that's already in the feed under a similar name.
    private var alreadyListed: Venue? {
        let key = ArtistKey.make(trimmedName)
        guard key.count >= 3 else { return nil }
        return store.venues.first { ArtistKey.make($0.name) == key }
    }

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Label("Thanks! We'll check out \(trimmedName) and add it if its shows can be listed.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                        if !SuggestionService.cloudEnabled {
                            Text("Suggestions are saved on your phone and will be sent once this feature goes live.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        TextField("Venue name", text: $name)
                            .textInputAutocapitalization(.words)
                        TextField("Neighborhood or city", text: $area)
                            .textInputAutocapitalization(.words)
                        TextField("Website or Instagram (optional)", text: $website)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } footer: {
                        if let venue = alreadyListed {
                            Text("\(venue.name) is already listed. Search for it in Browse or Venues.")
                                .foregroundStyle(.orange)
                        }
                    }
                    Section("What happens there") {
                        Picker("Mostly", selection: $kind) {
                            ForEach(EventCategory.filters) { Text($0.label).tag($0) }
                        }
                        TextField("Anything else? (optional)", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(sent ? "Suggestion sent" : "Suggest a venue")
            .onAppear { if name.isEmpty { name = initialName.trimmingCharacters(in: .whitespaces) } }
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
                if !sent {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send") {
                            let suggestion = VenueSuggestion(
                                name: trimmedName, area: area.trimmingCharacters(in: .whitespaces),
                                website: website.trimmingCharacters(in: .whitespaces), kind: kind.rawValue,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines), regionId: store.regionId)
                            sent = true
                            Task { await suggestions.submit(suggestion) }
                        }
                        .disabled(trimmedName.count < 2 || alreadyListed != nil)
                    }
                }
            }
        }
    }
}
