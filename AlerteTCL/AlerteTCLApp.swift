import SwiftUI

@main
struct AlerteTCLApp: App {
    @StateObject private var viewModel = AlertViewModel()
    @AppStorage("hasShownNotificationPrompt") private var hasShownNotificationPrompt = false
    @AppStorage("hasShownLocationPrompt") private var hasShownLocationPrompt = false
    @State private var showNotificationPrompt = false
    @State private var showLocationPrompt = false
    @State private var selectedParkingId: String?
    
    init() {
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(selectedParkingId: $selectedParkingId)
                .environmentObject(viewModel)
                .onAppear {
                    if !hasShownLocationPrompt {
                        Task {
                            try? await Task.sleep(for: .seconds(1))
                            await MainActor.run {
                                showLocationPrompt = true
                                hasShownLocationPrompt = true
                            }
                        }
                    } else if !hasShownNotificationPrompt {
                        Task {
                            try? await Task.sleep(for: .seconds(1))
                            await MainActor.run {
                                showNotificationPrompt = true
                                hasShownNotificationPrompt = true
                            }
                        }
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .sheet(isPresented: $showLocationPrompt) {
                    LocationPermissionView()
                        .onDisappear {
                            if !hasShownNotificationPrompt {
                                Task {
                                    try? await Task.sleep(for: .milliseconds(500))
                                    await MainActor.run {
                                        showNotificationPrompt = true
                                        hasShownNotificationPrompt = true
                                    }
                                }
                            }
                        }
                }
                .sheet(isPresented: $showNotificationPrompt) {
                    NotificationPermissionView()
                }
        }
    }

    private static let parkingIdRegex = /^[A-Za-z0-9_-]{1,64}$/

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "alertetcl" else { return }

        let pathComponents = url.pathComponents

        if pathComponents.count >= 3, pathComponents[1] == "parking" {
            let id = pathComponents[2]
            guard (try? Self.parkingIdRegex.wholeMatch(in: id)) != nil else {
                AppLogger.error("Deep link parking id rejeté: \(id)", category: .app)
                return
            }
            selectedParkingId = id
        }
    }
    
    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor.systemBackground
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        // Sans configuration explicite, iOS 15+ bascule en mode transparent
        // quand du contenu passe derrière la tab bar (.ignoresSafeArea sur la carte).
        // Ça supprime le glassmorphisme ET peut casser les zones de tap des onglets.
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground() // force le fond flouté système
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
