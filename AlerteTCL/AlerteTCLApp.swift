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
        cleanCorruptedPreferences()
    }
    
    private func cleanCorruptedPreferences() {
        // Nettoyer les préférences corrompues si nécessaire
        if UserDefaults.standard.object(forKey: "hasCleanedPrefs") == nil {
            UserDefaults.standard.set(true, forKey: "hasCleanedPrefs")
            UserDefaults.standard.synchronize()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(selectedParkingId: $selectedParkingId)
                .environmentObject(viewModel)
                .onAppear {
                    if !hasShownLocationPrompt {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showLocationPrompt = true
                            hasShownLocationPrompt = true
                        }
                    } else if !hasShownNotificationPrompt {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showNotificationPrompt = true
                            hasShownNotificationPrompt = true
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
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showNotificationPrompt = true
                                    hasShownNotificationPrompt = true
                                }
                            }
                        }
                }
                .sheet(isPresented: $showNotificationPrompt) {
                    NotificationPermissionView()
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "alertetcl" else { return }
        
        let pathComponents = url.pathComponents
        
        if pathComponents.count >= 2 && pathComponents[1] == "parking" {
            if pathComponents.count >= 3 {
                selectedParkingId = pathComponents[2]
            }
        }
    }
    
    private func configureAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
