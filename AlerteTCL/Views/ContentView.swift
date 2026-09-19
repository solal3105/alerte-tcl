import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    @State private var selectedTab = 0
    @Binding var selectedParkingId: String?
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LiveMapView()
                .tabItem {
                    Label("Transport", systemImage: "tram.fill")
                }
                .tag(0)
                .environmentObject(viewModel)
            
            CityView(selectedParkingId: $selectedParkingId)
                .tabItem {
                    Label("Autour de moi", systemImage: "mappin.and.ellipse")
                }
                .tag(1)

            AboutView()
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
        }
        .onChange(of: selectedParkingId) { _, newParkingId in
            if newParkingId != nil {
                selectedTab = 1
            }
        }
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
}

#Preview {
    ContentView(selectedParkingId: .constant(nil))
        .environmentObject(AlertViewModel())
}
