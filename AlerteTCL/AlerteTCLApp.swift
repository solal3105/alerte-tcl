import SwiftUI

@main
struct AlerteTCLApp: App {
    @StateObject private var viewModel = AlertViewModel()
    @AppStorage("hasShownNotificationPrompt") private var hasShownNotificationPrompt = false
    @State private var showNotificationPrompt = false
    
    init() {
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    if !hasShownNotificationPrompt {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showNotificationPrompt = true
                            hasShownNotificationPrompt = true
                        }
                    }
                }
                .sheet(isPresented: $showNotificationPrompt) {
                    NotificationPermissionView()
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
