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
            
            TravauxMapView()
                .tabItem {
                    Label("Travaux", systemImage: "hammer.fill")
                }
                .tag(1)
            
            ParkingMapView(selectedParkingId: $selectedParkingId)
                .tabItem {
                    Label("Parkings", systemImage: "car.fill")
                }
                .tag(2)

            AboutView()
                .tabItem {
                    Label("Info", systemImage: "info.circle.fill")
                }
                .tag(3)
        }
        .tint(.primary)
        .tabViewStyle(.automatic)
        .onChange(of: selectedParkingId) { _, newParkingId in
            if newParkingId != nil {
                selectedTab = 2
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationService.shared.clearBadge()
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
