import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AlertViewModel
    @State private var selectedTab = 0
    @State private var loadedTabs: Set<Int> = [0]
    @Binding var selectedParkingId: String?
    
    var body: some View {
        // UI directe sans splash - les données se chargent en arrière-plan
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
                        .onAppear { loadedTabs.insert(1) }
                }
            }
            .tabItem {
                Label("Travaux", systemImage: "hammer.fill")
            }
            .tag(1)
            
            Group {
                if loadedTabs.contains(2) {
                    ParkingMapView(selectedParkingId: $selectedParkingId)
                } else {
                    Color.clear
                        .onAppear { loadedTabs.insert(2) }
                }
            }
            .tabItem {
                Label("Parkings", systemImage: "car.fill")
            }
            .tag(2)
        }
        .tint(.primary)
        .onChange(of: selectedTab) { _, newTab in
            loadedTabs.insert(newTab)
        }
        .onChange(of: selectedParkingId) { _, newParkingId in
            if newParkingId != nil {
                loadedTabs.insert(2)
                selectedTab = 2
            }
        }
    }
}

#Preview {
    ContentView(selectedParkingId: .constant(nil))
        .environmentObject(AlertViewModel())
}
