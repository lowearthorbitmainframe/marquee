import SwiftUI

/// "Change/Remove Listing": a venue asks us to fix or take down its listing. The request goes to
/// heyscenester.app, which keeps a record and emails it to venues@heyscenester.app with the
/// venue's address as reply-to. Removals are promised within 48 hours.
enum ListingRequestKind: String, CaseIterable, Identifiable {
    case change, remove
    var id: String { rawValue }
    var label: String { self == .remove ? "Remove listing" : "Change listing" }
}

struct ListingRequestView: View {
    @EnvironmentObject private var store: FeedStore
    @Environment(\.dismiss) private var dismiss

    @State private var kind: ListingRequestKind = .change
    @State private var venueName = ""
    @State private var venue: Venue?
    @State private var name = ""
    @State private var role = ""
    @State private var email = ""
    @State private var details = ""
    @State private var sending = false
    @State private var sent = false
    @State private var error: String?

    private static let endpoint = URL(string: "https://heyscenester.app/api/listing-request")!

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Venues in the current city whose names start with, or contain, what's typed.
    private var matches: [Venue] {
        let key = ArtistKey.make(venueName)
        guard key.count >= 2, venue == nil else { return [] }
        let found = store.venues.filter { ArtistKey.make($0.name).contains(key) }
        return Array(found.sorted { ArtistKey.make($0.name).hasPrefix(key) && !ArtistKey.make($1.name).hasPrefix(key) }.prefix(5))
    }

    private var canSend: Bool {
        !trimmed(venueName).isEmpty && !trimmed(name).isEmpty && trimmed(email).contains("@")
            && (kind == .remove || !trimmed(details).isEmpty) && !sending
    }

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Label(kind == .remove
                              ? "Thanks. We'll remove \(trimmed(venueName)) within 48 hours and confirm by email."
                              : "Thanks. We'll look at \(trimmed(venueName))'s listing and reply by email.",
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                } else {
                    Section {
                        Picker("Request", selection: $kind) {
                            ForEach(ListingRequestKind.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    } footer: {
                        Text(kind == .remove
                             ? "For venue staff. We remove listings within 48 hours of a request."
                             : "For venue staff. Wrong times, a better calendar link, a different image, anything.")
                    }
                    Section("Venue") {
                        TextField("Venue name", text: $venueName)
                            .textInputAutocapitalization(.words)
                            .onChange(of: venueName) { if venue?.name != venueName { venue = nil } }
                        ForEach(matches) { match in
                            Button {
                                venue = match
                                venueName = match.name
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(match.name)
                                    if let place = match.neighborhood ?? match.address {
                                        Text(place).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    Section("You") {
                        TextField("Your name", text: $name)
                            .textContentType(.name)
                        TextField("Your role (optional), e.g. booker or owner", text: $role)
                        TextField("Your email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Section {
                        TextField(kind == .remove ? "Anything we should know? (optional)" : "What should change?",
                                  text: $details, axis: .vertical)
                            .lineLimit(3...8)
                    } footer: {
                        if let error {
                            Text(error).foregroundStyle(.red)
                        } else {
                            Text("We reply to the email above.")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(sent ? "Sent" : "Change/Remove Listing")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
                if !sent {
                    ToolbarItem(placement: .confirmationAction) {
                        if sending {
                            ProgressView()
                        } else {
                            Button("Send") { Task { await send() } }
                                .disabled(!canSend)
                        }
                    }
                }
            }
        }
    }

    private func send() async {
        sending = true
        error = nil
        defer { sending = false }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "X-Scenester-App")
        let body: [String: String] = [
            "kind": kind.rawValue,
            "venue": trimmed(venueName),
            "venueId": venue?.id ?? "",
            "region": venue == nil ? "" : store.regionId,
            "name": trimmed(name),
            "role": trimmed(role),
            "email": trimmed(email),
            "details": trimmed(details),
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let reply = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if reply?["ok"] as? Bool == true {
                sent = true
            } else {
                error = (reply?["error"] as? String) ?? "Something went wrong. Please try again, or email venues@heyscenester.app."
            }
        } catch {
            self.error = "We couldn't reach Scenester. Check your connection, or email venues@heyscenester.app."
        }
    }
}
