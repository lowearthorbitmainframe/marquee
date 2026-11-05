import BackgroundTasks
import SwiftUI
import UserNotifications

@main
struct MarqueeApp: App {
    @StateObject private var store = FeedStore()
    @StateObject private var taste = TasteStore()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(taste)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .task {
                    store.loadLocal()
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
    }

    private var setupBinding: Binding<Bool> {
        Binding(
            get: { !taste.profile.finishedSetup && store.feed != nil },
            set: { if !$0 { taste.profile.finishedSetup = true } }
        )
    }
}
