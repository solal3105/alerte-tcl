import SwiftUI
import MapKit
import Combine

// MARK: - LiveMapRepresentable
//
// Remplace `Map { Annotation(coordinate:) { View } }` par un `MKMapView` UIKit.
//
// Motivation : chaque `Annotation` SwiftUI crée un `UIHostingView` + son sous-graphe
// `AttributeGraph`. Avec 300+ véhicules, `beginTransaction` doit traverser tous
// ces sous-graphes à chaque tick d'horloge (~27 % du CPU, O(N) par tick).
// Un `MKAnnotationView` avec `image: UIImage` n'a ni graphe ni transaction.
//
// Responsabilités :
//   1. Diff minimal des annotations à chaque `updateUIView` (pas de retrait global).
//   2. Animation : s'abonne à `AnimationClock.time` et met à jour seulement
//      `VehicleAnnotation.coordinate` + `transform` de la flèche (≈ 10 Hz).
//   3. Bridge bidirectionnel de la région caméra (avec garde anti-boucle).
//   4. Rendu des polylignes via `MKPolylineRenderer` (1 overlay par ligne).

struct LiveMapRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: LiveVehiclesViewModel
    @ObservedObject var locationService: LocationService

    @Binding var region: MKCoordinateRegion
    @Binding var selectedVehicle: Vehicle?
    @Binding var selectedMergedStop: MergedStop?
    @Binding var isSatellite: Bool

    // MARK: - Lifecycle

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.pointOfInterestFilter = .excludingAll

        // Ne pas laisser UIKit ajuster les insets de la MKMapView en fonction
        // de la safe area du UIHostingController parent (tab bar, status bar).
        // Sans ça, la map peut apparaître réduite ou décalée sur les iPhones.
        mapView.insetsLayoutMarginsFromSafeArea = false

        mapView.register(VehicleAnnotationView.self,   forAnnotationViewWithReuseIdentifier: VehicleAnnotationView.identifier)
        mapView.register(ClusterAnnotationView.self,   forAnnotationViewWithReuseIdentifier: ClusterAnnotationView.identifier)
        mapView.register(MergedStopAnnotationView.self, forAnnotationViewWithReuseIdentifier: MergedStopAnnotationView.identifier)

        applyMapStyle(to: mapView, satellite: isSatellite)

        context.coordinator.mapView = mapView
        context.coordinator.setInitialRegion(region)
        context.coordinator.startClockSubscription()

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coord = context.coordinator

        // Style (plan / satellite)
        if coord.lastAppliedSatellite != isSatellite {
            applyMapStyle(to: mapView, satellite: isSatellite)
            coord.lastAppliedSatellite = isSatellite
        }

        // Région caméra (sens SwiftUI → MapKit).
        //
        // On ne pousse vers MapKit QUE si la valeur du binding a vraiment changé
        // depuis la dernière fois qu'on l'a poussée nous-mêmes (ex: bouton localisation).
        // Sinon `updateUIView` déclenché par un changement ViewModel écrase le pan
        // en cours de l'utilisateur → rebond visuel.
        if let last = coord.lastSetRegion {
            if !region.isApproximatelyEqual(to: last) {
                coord.lastSetRegion = region
                coord.isProgrammaticUpdate = true
                mapView.setRegion(region, animated: true)
            }
        } else {
            // Première updateUIView après makeUIView : setInitialRegion a déjà été
            // appelé, on enregistre juste la valeur courante.
            coord.lastSetRegion = region
        }

        // Diff des annotations et overlays
        coord.syncVehicleAnnotations(viewModel.displayVehicles, animated: viewModel.animatedVehicles)
        coord.syncClusterAnnotations(viewModel.displayClusters)
        coord.syncMergedStopAnnotations(viewModel.visibleMergedStops)
        coord.syncPolylineOverlays(
            busLines:     viewModel.showBusLines     ? viewModel.busLines     : [],
            transitLines: viewModel.showTransitLines ? viewModel.transitLines : []
        )

        // Les tooltips de ponctualité sont gérés dans `regionDidChangeAnimated`
        // (quand le zoom change vraiment), pas ici — évite de réintroduire une
        // dépendance sur `currentZoomLevel` qui publie à haute fréquence.
    }

    /// Force `UIViewRepresentable` à utiliser toute la taille proposée par SwiftUI,
    /// exactement comme SwiftUI `Map`. Sans ça, `MKMapView.intrinsicContentSize`
    /// peut prendre le dessus et produire une hauteur incorrecte dans un ZStack.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MKMapView, context: Context) -> CGSize? {
        CGSize(
            width:  proposal.width  ?? UIScreen.main.bounds.width,
            height: proposal.height ?? UIScreen.main.bounds.height
        )
    }

    static func dismantleUIView(_ uiView: MKMapView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator { Coordinator(owner: self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let owner: LiveMapRepresentable
        weak var mapView: MKMapView?

        // Diff state
        private var vehicleAnnotations:   [String: VehicleAnnotation]    = [:]
        private var clusterAnnotations:   [String: ClusterAnnotation]    = [:]
        private var stopAnnotations:      [String: MergedStopAnnotation] = [:]
        private var busOverlaysById:      [String: MKPolyline]           = [:]
        private var transitOverlaysById:  [String: MKPolyline]           = [:]
        private var overlayColors:        [ObjectIdentifier: (UIColor, CGFloat)] = [:]

        // Animation (horloge partagée avec le ViewModel)
        private let clock = AnimationClock()
        private var clockCancellable: AnyCancellable?
        private var currentZoomLevel: Double = 0.15

        // Bridge région
        /// Dernière région que SwiftUI nous a demandé de pousser vers MapKit
        /// (via setInitialRegion ou un changement explicite du binding, ex. bouton localisation).
        /// Sert à distinguer "le binding a vraiment changé depuis SwiftUI" de
        /// "updateUIView s'est re-déclenché sur un changement ViewModel alors que
        /// la carte était au milieu d'un pan utilisateur" — cas qui causait un rebond.
        var lastSetRegion: MKCoordinateRegion? = nil
        var isProgrammaticUpdate = false
        var lastAppliedSatellite: Bool = false
        private var regionDebounce: DispatchWorkItem?

        init(owner: LiveMapRepresentable) { self.owner = owner }

        // MARK: Horloge d'animation

        func startClockSubscription() {
            clock.start()
            // `AnimationClock.time` est @Published ; on évite le bouncing SwiftUI
            // en travaillant impérativement ici.
            clockCancellable = clock.$time
                .receive(on: DispatchQueue.main)
                .sink { [weak self] time in
                    self?.applyAnimationTick(time)
                }
        }

        func tearDown() {
            clockCancellable?.cancel()
            clockCancellable = nil
            clock.stop()
            regionDebounce?.cancel()
        }

        /// Applique la position/cap interpolé à chaque VehicleAnnotation actif.
        /// Appelé ~10 fois/s. Boucle unique, O(N), sans allocation.
        private func applyAnimationTick(_ time: CFTimeInterval) {
            guard let mapView else { return }
            let animated = owner.viewModel.animatedVehicles

            for (id, annotation) in vehicleAnnotations {
                guard let anim = animated[id] else { continue }
                let newCoord = anim.coordinateAt(time)
                let newBearing = anim.bearingAt(time)

                // Met à jour la coordonnée seulement si visible (optimisation
                // MapKit : un hors-écran ne crée pas de repositioning).
                annotation.coordinate = newCoord
                annotation.bearing = newBearing

                // Rotation de la flèche (le corps reste fixe).
                if let view = mapView.view(for: annotation) as? VehicleAnnotationView {
                    view.apply(vehicle: annotation.vehicle, bearing: newBearing,
                               showTooltip: currentZoomLevel <= Self.punctualityZoomThreshold)
                }
            }
        }

        // MARK: Diff annotations

        func syncVehicleAnnotations(_ vehicles: [Vehicle], animated: [String: AnimatedVehicle]) {
            guard let mapView else { return }

            let incomingIDs = Set(vehicles.map(\.id))
            let currentIDs  = Set(vehicleAnnotations.keys)

            // Suppressions
            let toRemoveIDs = currentIDs.subtracting(incomingIDs)
            if !toRemoveIDs.isEmpty {
                let toRemove = toRemoveIDs.compactMap { vehicleAnnotations.removeValue(forKey: $0) }
                mapView.removeAnnotations(toRemove)
            }

            // Ajouts et mises à jour
            var toAdd: [VehicleAnnotation] = []
            for vehicle in vehicles {
                let bearing = animated[vehicle.id]?.bearingAt(clock.time) ?? vehicle.bearing
                let coord   = animated[vehicle.id]?.coordinateAt(clock.time) ?? vehicle.coordinate

                if let existing = vehicleAnnotations[vehicle.id] {
                    existing.vehicle = vehicle
                    existing.coordinate = coord
                    existing.bearing = bearing
                    if let view = mapView.view(for: existing) as? VehicleAnnotationView {
                        view.apply(vehicle: vehicle, bearing: bearing,
                                   showTooltip: currentZoomLevel <= Self.punctualityZoomThreshold)
                    }
                } else {
                    let annotation = VehicleAnnotation(vehicle: vehicle, coordinate: coord, bearing: bearing)
                    vehicleAnnotations[vehicle.id] = annotation
                    toAdd.append(annotation)
                }
            }
            if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }
        }

        func syncClusterAnnotations(_ clusters: [MapCluster<Vehicle>]) {
            guard let mapView else { return }

            let incomingIDs = Set(clusters.map(\.id))
            let currentIDs  = Set(clusterAnnotations.keys)

            let toRemoveIDs = currentIDs.subtracting(incomingIDs)
            if !toRemoveIDs.isEmpty {
                let toRemove = toRemoveIDs.compactMap { clusterAnnotations.removeValue(forKey: $0) }
                mapView.removeAnnotations(toRemove)
            }

            var toAdd: [ClusterAnnotation] = []
            for cluster in clusters {
                if let existing = clusterAnnotations[cluster.id] {
                    existing.cluster = cluster
                    existing.coordinate = cluster.coordinate
                    if let view = mapView.view(for: existing) as? ClusterAnnotationView {
                        view.apply(cluster: cluster)
                    }
                } else {
                    let annotation = ClusterAnnotation(cluster: cluster)
                    clusterAnnotations[cluster.id] = annotation
                    toAdd.append(annotation)
                }
            }
            if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }
        }

        func syncMergedStopAnnotations(_ stops: [MergedStop]) {
            guard let mapView else { return }

            let incomingIDs = Set(stops.map(\.id))
            let currentIDs  = Set(stopAnnotations.keys)

            let toRemoveIDs = currentIDs.subtracting(incomingIDs)
            if !toRemoveIDs.isEmpty {
                let toRemove = toRemoveIDs.compactMap { stopAnnotations.removeValue(forKey: $0) }
                mapView.removeAnnotations(toRemove)
            }

            var toAdd: [MergedStopAnnotation] = []
            for stop in stops {
                if stopAnnotations[stop.id] == nil {
                    let annotation = MergedStopAnnotation(stop: stop)
                    stopAnnotations[stop.id] = annotation
                    toAdd.append(annotation)
                }
            }
            if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }
        }

        // MARK: Diff overlays (polylignes)

        func syncPolylineOverlays(busLines: [BusLine], transitLines: [TransitLine]) {
            guard let mapView else { return }

            syncOverlayGroup(
                incoming:  busLines,
                idKey:     { $0.id },
                coordsKey: { $0.clLocationCoordinates },
                colorKey:  { (UIColor($0.lineColor), $0.lineWidth) },
                cache:     &busOverlaysById,
                mapView:   mapView
            )
            syncOverlayGroup(
                incoming:  transitLines,
                idKey:     { $0.id },
                coordsKey: { $0.clLocationCoordinates },
                colorKey:  { (UIColor($0.lineColor), $0.lineWidth) },
                cache:     &transitOverlaysById,
                mapView:   mapView
            )
        }

        private func syncOverlayGroup<Line>(
            incoming: [Line],
            idKey: (Line) -> String,
            coordsKey: (Line) -> [CLLocationCoordinate2D],
            colorKey: (Line) -> (UIColor, CGFloat),
            cache: inout [String: MKPolyline],
            mapView: MKMapView
        ) {
            let incomingIDs = Set(incoming.map(idKey))
            let currentIDs  = Set(cache.keys)

            // Retraits
            let toRemoveIDs = currentIDs.subtracting(incomingIDs)
            for id in toRemoveIDs {
                if let poly = cache.removeValue(forKey: id) {
                    overlayColors.removeValue(forKey: ObjectIdentifier(poly))
                    mapView.removeOverlay(poly)
                }
            }

            // Ajouts (les lignes ne changent que lors d'un refetch rare → pas d'update en place)
            var toAdd: [MKPolyline] = []
            for line in incoming {
                let id = idKey(line)
                if cache[id] != nil { continue }
                var coords = coordsKey(line)
                guard coords.count >= 2 else { continue }
                let poly = MKPolyline(coordinates: &coords, count: coords.count)
                cache[id] = poly
                overlayColors[ObjectIdentifier(poly)] = colorKey(line)
                toAdd.append(poly)
            }
            if !toAdd.isEmpty {
                // Les polylignes doivent être sous les annotations : MapKit les
                // empile dans l'ordre d'ajout, donc ajouter .belowLabels.
                mapView.addOverlays(toAdd, level: .aboveRoads)
            }
        }

        // MARK: Re-apply tooltips après changement de zoom

        func refreshVehicleViews(for zoom: Double) {
            let prevZoom = currentZoomLevel
            currentZoomLevel = zoom
            guard let mapView else { return }

            // Tooltips de ponctualité sur les véhicules.
            let prevPunctuality = prevZoom <= Self.punctualityZoomThreshold
            let nextPunctuality = zoom     <= Self.punctualityZoomThreshold
            if prevPunctuality != nextPunctuality {
                for annotation in vehicleAnnotations.values {
                    if let view = mapView.view(for: annotation) as? VehicleAnnotationView {
                        view.apply(vehicle: annotation.vehicle, bearing: annotation.bearing, showTooltip: nextPunctuality)
                    }
                }
            }

            // Badges de ligne sur les arrêts.
            let prevBadges = prevZoom <= Self.stopBadgeZoomThreshold
            let nextBadges = zoom     <= Self.stopBadgeZoomThreshold
            if prevBadges != nextBadges {
                for annotation in stopAnnotations.values {
                    if let view = mapView.view(for: annotation) as? MergedStopAnnotationView {
                        view.apply(stop: annotation.stop, showBadges: nextBadges)
                    }
                }
            }
        }

        // MARK: Région initiale

        func setInitialRegion(_ region: MKCoordinateRegion) {
            lastSetRegion = region
            isProgrammaticUpdate = true
            mapView?.setRegion(region, animated: false)
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            switch annotation {
            case let vehicle as VehicleAnnotation:
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: VehicleAnnotationView.identifier,
                    for: vehicle
                ) as? VehicleAnnotationView ?? VehicleAnnotationView(annotation: vehicle, reuseIdentifier: VehicleAnnotationView.identifier)
                view.annotation = vehicle
                view.apply(vehicle: vehicle.vehicle, bearing: vehicle.bearing,
                           showTooltip: currentZoomLevel <= Self.punctualityZoomThreshold)
                return view

            case let cluster as ClusterAnnotation:
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: ClusterAnnotationView.identifier,
                    for: cluster
                ) as? ClusterAnnotationView ?? ClusterAnnotationView(annotation: cluster, reuseIdentifier: ClusterAnnotationView.identifier)
                view.annotation = cluster
                view.apply(cluster: cluster.cluster)
                return view

            case let stop as MergedStopAnnotation:
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: MergedStopAnnotationView.identifier,
                    for: stop
                ) as? MergedStopAnnotationView ?? MergedStopAnnotationView(annotation: stop, reuseIdentifier: MergedStopAnnotationView.identifier)
                view.annotation = stop
                view.apply(stop: stop.stop, showBadges: currentZoomLevel <= Self.stopBadgeZoomThreshold)
                return view

            default:
                return nil
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: poly)
            if let (color, width) = overlayColors[ObjectIdentifier(poly)] {
                renderer.strokeColor = color
                renderer.lineWidth = width
            } else {
                renderer.strokeColor = .systemGray
                renderer.lineWidth = 3
            }
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            switch annotation {
            case let v as VehicleAnnotation:
                owner.selectedVehicle = v.vehicle
            case let s as MergedStopAnnotation:
                owner.selectedMergedStop = s.stop
            case let c as ClusterAnnotation:
                // Zoom sur le cluster (comportement "drill-down" classique)
                let zoomSpan = MKCoordinateSpan(
                    latitudeDelta:  mapView.region.span.latitudeDelta  / 2.5,
                    longitudeDelta: mapView.region.span.longitudeDelta / 2.5
                )
                mapView.setRegion(MKCoordinateRegion(center: c.coordinate, span: zoomSpan), animated: true)
            default:
                break
            }
            mapView.deselectAnnotation(annotation, animated: false)
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // Marqué comme programmatique si on vient de pousser setRegion.
            // Pas besoin de tracker isUserInteracting — on utilise lastSetRegion.
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            isProgrammaticUpdate = false

            // Remonte la région au ViewModel (clustering + viewport filter).
            owner.viewModel.updateZoomLevel(mapView.region.span)
            owner.viewModel.updateVisibleRegion(mapView.region)
            refreshVehicleViews(for: mapView.region.span.latitudeDelta)

            // Remonte vers le binding SwiftUI uniquement si le mouvement vient
            // de l'utilisateur (pas de notre setRegion programmatique).
            // On met à jour `lastSetRegion` EN PREMIER pour que le prochain
            // updateUIView (déclenché par `owner.region =`) ne refasse pas setRegion.
            regionDebounce?.cancel()
            let item = DispatchWorkItem { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                let current = mapView.region
                self.lastSetRegion = current   // garde AVANT la mise à jour du binding
                self.owner.region  = current
            }
            regionDebounce = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
        }

        // MARK: Constants

        private static let punctualityZoomThreshold: Double = 0.005
        /// En-dessous de ce latitudeDelta, les badges de ligne s'affichent sur les arrêts.
        private static let stopBadgeZoomThreshold:    Double = 0.008
    }

    // MARK: - Style

    private func applyMapStyle(to mapView: MKMapView, satellite: Bool) {
        if satellite {
            mapView.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
        } else {
            let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
            config.pointOfInterestFilter = .excludingAll
            mapView.preferredConfiguration = config
        }
    }
}

// MARK: - MKCoordinateRegion comparaison tolérante

private extension MKCoordinateRegion {
    func isApproximatelyEqual(to other: MKCoordinateRegion, tolerance: Double = 1e-6) -> Bool {
        abs(center.latitude  - other.center.latitude)   < tolerance &&
        abs(center.longitude - other.center.longitude)  < tolerance &&
        abs(span.latitudeDelta  - other.span.latitudeDelta)  < tolerance &&
        abs(span.longitudeDelta - other.span.longitudeDelta) < tolerance
    }
}
