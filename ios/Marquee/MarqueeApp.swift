import SwiftUI

@main
struct MarqueeApp: App {
    @StateObject private var store = FeedStore()
    @StateObject private var taste = TasteStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(taste)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .task {
                    store.loadLocal()
                    await store.refreshIfNeeded()
                }
        }
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
                Task { await store.refreshIfNeeded() }
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
