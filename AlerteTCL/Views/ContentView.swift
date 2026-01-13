import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    @State private var selectedTab = 0
    @State private var showSplash = true
    @State private var uiReady = false
    @State private var loadedTabs: Set<Int> = [0]
    
    var body: some View {
        ZStack {
            // Contenu principal avec lazy loading
            TabView(selection: $selectedTab) {
                LiveMapView()
                    .tabItem {
                        Label("Transport", systemImage: "tram.fill")
                    }
                    .tag(0)
                    .environmentObject(viewModel)
                
                Group {
                    if loadedTabs.contains(1) {
                        TravauxMapView()
                    } else {
                        Color.clear
                            .onAppear {
                                loadedTabs.insert(1)
                            }
                    }
                }
                .tabItem {
                    Label("Travaux", systemImage: "cone.fill")
                }
                .tag(1)
                
                Group {
                    if loadedTabs.contains(2) {
                        ParkingMapView()
                    } else {
                        Color.clear
                            .onAppear {
                                loadedTabs.insert(2)
                            }
                    }
                }
                .tabItem {
                    Label("Parkings", systemImage: "car.fill")
                }
                .tag(2)
                
                Group {
                    if loadedTabs.contains(3) {
                        SettingsView()
                    } else {
                        Color.clear
                            .onAppear {
                                loadedTabs.insert(3)
                            }
                    }
                }
                .tabItem {
                    Label("Paramètres", systemImage: "gearshape.fill")
                }
                .tag(3)
            }
            .tint(.primary)
            .onChange(of: selectedTab) { _, newTab in
                loadedTabs.insert(newTab)
            }
            
            // Splash screen
            if showSplash {
                AmazingSplashView(isActive: $showSplash, uiReady: $uiReady)
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Signaler immédiatement que l'UI est prête
            DispatchQueue.main.async {
                uiReady = true
            }
            
            // Charger les alertes en arrière-plan sans bloquer l'UI
            Task(priority: .userInitiated) {
                await viewModel.loadAlerts()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AlertViewModel())
}
