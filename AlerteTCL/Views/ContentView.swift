import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    @State private var selectedTab = 0
    /// Lien profond reçu par l'application (widgets, notifications) ; routé vers l'onglet concerné puis effacé.
    @Binding var deepLink: WidgetLink?
    @State private var stopLink: Int?
    @State private var trafficLink = false
    @State private var cityLink: WidgetLink?
    @State private var showWidgets = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LiveMapView(stopLink: $stopLink, trafficLink: $trafficLink)
                .tabItem {
                    Label("Transport", systemImage: "tram.fill")
                }
                .tag(0)
                .environmentObject(viewModel)
            
            CityView(link: $cityLink)
                .tabItem {
                    Label("Autour de moi", systemImage: "mappin.and.ellipse")
                }
                .tag(1)

            AboutView(showWidgets: $showWidgets)
                .tabItem {
                    Label("Info", systemImage: "info.circle.fill")
                }
                .tag(2)
        }
        .tint(Color.appAccent)
        .tabViewStyle(.automatic)
        .onAppear {
            #if DEBUG
            // Mode démo : « velov… » ou « ville » ouvrent « Autour de moi », « info » ouvre l'onglet Info.
            if let demo = DemoShowcase.current {
                if demo.hasPrefix("velov") || demo == "ville" { selectedTab = 1 }
                if demo == "info" { selectedTab = 2 }
            }
            #endif
            route(deepLink)
        }
        .onChange(of: deepLink) { _, link in route(link) }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                NotificationService.shared.clearBadge()
                LocationService.shared.startUpdatingLocation()
                // Retour au premier plan : recharger les alertes immédiatement
                // (les véhicules sont relancés par LiveMapView, les parkings par leur ViewModel).
                Task { await viewModel.loadAlerts() }
            case .background:
                // Le GPS tourne en continu dès l'autorisation accordée : le couper
                // en arrière-plan évite de vider la batterie pour rien.
                LocationService.shared.stopUpdatingLocation()
            default:
                break
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("OpenAlertDetail"))
                .receive(on: RunLoop.main)
        ) { _ in
            selectedTab = 0
        }
    }

    /// Chaque lien ouvre son onglet et laisse la vue concernée finir le travail quand ses données sont là.
    private func route(_ link: WidgetLink?) {
        guard let link else { return }
        switch link {
        case .stop(let id):
            selectedTab = 0
            stopLink = id
        case .traffic:
            selectedTab = 0
            trafficLink = true
        case .parking, .velov, .works:
            selectedTab = 1
            cityLink = link
        case .widgets:
            selectedTab = 2
            showWidgets = true
        }
        deepLink = nil
    }
}

#Preview {
    ContentView(deepLink: .constant(nil))
        .environmentObject(AlertViewModel())
}
