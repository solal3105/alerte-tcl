import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    @State private var selectedTab = 0
    @State private var showSplash = true
    @State private var apiHasResponded = false
    
    var body: some View {
        ZStack {
            // Contenu principal (toujours rendu pour précharger)
            TabView(selection: $selectedTab) {
                LiveMapView()
                    .tabItem {
                        Label("Live", systemImage: "location.fill")
                    }
                    .tag(0)
                
                ParkingMapView()
                    .tabItem {
                        Label("Parkings", systemImage: "car.fill")
                    }
                    .tag(1)
                
                NewAlertsView()
                    .tabItem {
                        Label("Alertes", systemImage: "bell.fill")
                    }
                    .tag(2)
                    .badge(viewModel.subscribedAlerts.count > 0 ? viewModel.subscribedAlerts.count : 0)
                
                SettingsView()
                    .tabItem {
                        Label("Paramètres", systemImage: "gearshape.fill")
                    }
                    .tag(3)
            }
            .tint(.primary)
            .overlay {
                // Overlay pour masquer le contenu pendant le splash
                if showSplash {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            
            // Splash screen
            if showSplash {
                AmazingSplashView(isActive: $showSplash, apiReady: $apiHasResponded)
                    .transition(.opacity)
            }
        }
        .task {
            await viewModel.loadAlerts()
            // Signaler que l'API a répondu
            apiHasResponded = true
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AlertViewModel())
}
