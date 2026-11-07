import BackgroundTasks
import SwiftUI
import UserNotifications

@main
struct MarqueeApp: App {
    @StateObject private var store = FeedStore()
    @StateObject private var taste = TasteStore()
    @StateObject private var suggestions = SuggestionService()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(taste)
                .environmentObject(suggestions)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .task {
                    store.loadLocal()
                    await suggestions.flush()
                    await refreshAndAlert()
                }
        }
        // iOS wakes the app now and then to look for newly announced shows.
        .backgroundTask(.appRefresh(Alerts.refreshTaskID)) {
            await MainActor.run { Self.scheduleRefresh() }
            await Self.backgroundCheck()
        }
    }

    @MainActor private func refreshAndAlert() async {
        if await store.refreshIfNeeded() {
            await Alerts.check(feed: store.feed, region: store.regionId, taste: taste.profile)
        }
    }

    @MainActor static func backgroundCheck() async {
        let taste = TasteStore()
        let store = FeedStore(region: taste.profile.alertRegion)
        store.loadLocal()
        if await store.refresh() {
            await Alerts.check(feed: store.feed, region: store.regionId, taste: taste.profile)
        }
    }

    @MainActor static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Alerts.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

struct RootView: View {
    @EnvironmentObject private var taste: TasteStore
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: FeedStore
    @ObservedObject private var router = AlertRouter.shared

    var body: some View {
        TabView {
            TonightView()
                .tabItem { Label("Tonight", systemImage: "sparkles") }
            BrowseView()
                .tabItem { Label("Browse", systemImage: "calendar") }
            VenuesView()
                .tabItem { Label("Venues", systemImage: "building.columns") }
            YouView()
                .tabItem { Label("You", systemImage: "person.crop.circle") }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    if await store.refreshIfNeeded() {
                        await Alerts.check(feed: store.feed, region: store.regionId, taste: taste.profile)
                    }
                }
            } else if phase == .background {
                MarqueeApp.scheduleRefresh()
            }
        }
        .sheet(isPresented: setupBinding) {
            SetupView()
        }
        .sheet(item: $router.opened) { opened in
            NewShowsView(eventIds: opened.eventIds)
        }
        .onChange(of: router.opened?.id) { _, _ in
            // Alerts are about your home area; show it so the new shows are there.
            if router.opened != nil, store.regionId != taste.profile.alertRegion {
                Task { await store.switchRegion(to: taste.profile.alertRegion) }
            }
        }
        .onChange(of: taste.profile.dislikedKeys, initial: true) { _, keys in
            store.hiddenArtistKeys = keys
        }
    }

    private var setupBinding: Binding<Bool> {
        Binding(
            get: { !taste.profile.finishedSetup && store.feed != nil },
            set: { if !$0 { taste.profile.finishedSetup = true } }
        )
    }
}

/// What a tapped alert opens: the shows it announced, then anything else alerts found lately.
struct NewShowsView: View {
    @EnvironmentObject private var store: FeedStore
    @Environment(\.dismiss) private var dismiss

    var eventIds: [String]

    private var announced: [Event] {
        let wanted = Set(eventIds)
        return store.events.filter { wanted.contains($0.id) }.sorted { $0.start < $1.start }
    }

    private var earlier: [Event] {
        let wanted = Set(eventIds)
        return AlertHistory.recentEvents(in: store.feed).filter { !wanted.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !announced.isEmpty {
                        SectionHeader(title: announced.count == 1 ? "Just announced" : "\(announced.count) just announced")
                        ForEach(announced) { EventLink(event: $0, showsDate: true) }
                    }
                    if !earlier.isEmpty {
                        SectionHeader(title: "Earlier alerts").padding(.top, announced.isEmpty ? 0 : 14)
                        ForEach(earlier) { EventLink(event: $0, showsDate: true) }
                    }
                    if announced.isEmpty && earlier.isEmpty {
                        Text(store.isRefreshing ? "Loading the latest listings…" : "These shows aren't in the listings anymore.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("New shows")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .marqueeDestinations()
        }
    }
}
