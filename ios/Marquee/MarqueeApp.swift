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
        if let unselected = Theme.tabUnselected {
            // iOS 26's glass tab bar only honors colors set through a full appearance.
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
                item.normal.iconColor = unselected
                item.normal.titleTextAttributes = [.foregroundColor: unselected]
            }
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().unselectedItemTintColor = unselected
        }
        if let titleColor = Theme.titleColor {
            // Red, centered screen titles. The paragraph style centers the large title too.
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            let bar = UINavigationBarAppearance()
            bar.configureWithTransparentBackground()
            bar.largeTitleTextAttributes = [.foregroundColor: titleColor, .paragraphStyle: centered]
            bar.titleTextAttributes = [.foregroundColor: titleColor]
            let scrolled = UINavigationBarAppearance()
            scrolled.configureWithDefaultBackground()
            scrolled.titleTextAttributes = [.foregroundColor: titleColor]
            scrolled.largeTitleTextAttributes = bar.largeTitleTextAttributes
            UINavigationBar.appearance().scrollEdgeAppearance = bar
            UINavigationBar.appearance().standardAppearance = scrolled
            UINavigationBar.appearance().compactAppearance = scrolled
        }
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
    @State private var tab = 0

    /// iOS colors tab icons itself unless an icon brings its own color, so themes with a
    /// separate unselected color draw each icon pre-colored.
    @ViewBuilder private func tabLabel(_ title: String, _ symbol: String, _ index: Int) -> some View {
        if let unselected = Theme.tabUnselected, let image = UIImage(systemName: symbol) {
            let color = index == tab ? UIColor(Theme.tabSelected) : unselected
            Label { Text(title) } icon: { Image(uiImage: image.withTintColor(color, renderingMode: .alwaysOriginal)) }
        } else {
            Label(title, systemImage: symbol)
        }
    }

    var body: some View {
        // The tab bar takes its selected color from this tint; each screen gets the accent back.
        TabView(selection: $tab) {
            TonightView()
                .tint(Theme.accent)
                .tabItem { tabLabel("Tonight", "sparkles", 0) }
                .tag(0)
            BrowseView()
                .tint(Theme.accent)
                .tabItem { tabLabel("Browse", "calendar", 1) }
                .tag(1)
            VenuesView()
                .tint(Theme.accent)
                .tabItem { tabLabel("Venues", "building.columns", 2) }
                .tag(2)
            YouView()
                .tint(Theme.accent)
                .tabItem { tabLabel("You", "person.crop.circle", 3) }
                .tag(3)
        }
        .tint(Theme.tabSelected)
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
