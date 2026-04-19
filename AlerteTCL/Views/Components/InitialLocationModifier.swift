import SwiftUI
import MapKit
import CoreLocation

/// ViewModifier qui gère le positionnement initial de la carte sur la localisation de l'utilisateur.
/// Factorise le pattern répété dans LiveMapView, ParkingMapView et TravauxMapView.
struct InitialLocationModifier: ViewModifier {
    @ObservedObject private var locationService = LocationService.shared
    @Binding var mapCameraPosition: MapCameraPosition
    @Binding var hasSetInitialLocation: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                locationService.requestPermission()
                locationService.startUpdatingLocation()
                
                if !hasSetInitialLocation, let userLocation = locationService.currentLocation {
                    mapCameraPosition = .region(
                        MKCoordinateRegion(
                            center: userLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                    hasSetInitialLocation = true
                }
            }
            .onChange(of: locationService.currentLocation) { oldValue, newValue in
                if !hasSetInitialLocation, let newLocation = newValue {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        mapCameraPosition = .region(
                            MKCoordinateRegion(
                                center: newLocation.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    }
                    hasSetInitialLocation = true
                }
            }
    }
}

extension View {
    /// Gère automatiquement le positionnement initial de la carte sur la localisation de l'utilisateur
    func withInitialLocation(
        mapCameraPosition: Binding<MapCameraPosition>,
        hasSetInitialLocation: Binding<Bool>
    ) -> some View {
        modifier(InitialLocationModifier(
            mapCameraPosition: mapCameraPosition,
            hasSetInitialLocation: hasSetInitialLocation
        ))
    }
}
