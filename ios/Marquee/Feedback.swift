import SwiftUI
import UIKit

/// "Suggest a feature / report a problem". Feedback travels the same way as venue
/// suggestions (the VenueSuggestion record in CloudKit, with a "feedback-…" kind), so the
/// daily check on the owner's Mac picks it up without any new CloudKit setup.
enum FeedbackKind: String, CaseIterable, Identifiable {
    case problem = "feedback-problem"
    case idea = "feedback-idea"

    var id: String { rawValue }
    var label: String { self == .problem ? "Report a problem" : "Suggest a feature" }
    var symbol: String { self == .problem ? "exclamationmark.bubble" : "lightbulb" }
}

struct FeedbackSection: View {
    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Feedback", subtitle: "Something broken, or an idea for Scenester? Tell us.")
            Button {
                isPresented = true
            } label: {
                Label("Suggest a feature / report a problem", systemImage: "bubble.left.and.text.bubble.right")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $isPresented) { FeedbackView() }
    }
}

struct FeedbackView: View {
    @EnvironmentObject private var store: FeedStore
    @EnvironmentObject private var suggestions: SuggestionService
    @Environment(\.dismiss) private var dismiss

    @State private var kind: FeedbackKind = .problem
    @State private var summary = ""
    @State private var details = ""
    @State private var email = ""
    @State private var sent = false

    private var trimmedSummary: String { summary.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Label(kind == .problem ? "Thanks! We'll look into it." : "Thanks for the idea!",
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                        if !SuggestionService.cloudEnabled {
                            Text("Saved on your phone and sent once this feature goes live.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        Picker("Type", selection: $kind) {
                            ForEach(FeedbackKind.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    }
                    Section {
                        TextField(kind == .problem ? "What went wrong?" : "What's your idea?", text: $summary)
                        TextField(kind == .problem ? "Details: which screen, show or venue (optional)" : "More detail (optional)",
                                  text: $details, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    Section {
                        TextField("Your email, if you'd like a reply (optional)", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } footer: {
                        Text("We also send the app version and your iPhone's iOS version, to help track down problems.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(sent ? "Sent" : "Feedback")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
                if !sent {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send") { send() }
                            .disabled(trimmedSummary.count < 3)
                    }
                }
            }
        }
    }

    private func send() {
        let info = Bundle.main.infoDictionary
        let version = "Scenester \(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
        let device = "\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
        let feedback = VenueSuggestion(
            name: trimmedSummary,
            area: "\(version) · \(device)",
            website: email.trimmingCharacters(in: .whitespaces),
            kind: kind.rawValue,
            note: details.trimmingCharacters(in: .whitespacesAndNewlines),
            regionId: store.regionId)
        sent = true
        Task { await suggestions.submit(feedback) }
    }
}
