import SwiftUI
import WidgetKit

/// Les six widgets de Lyon Pocket, dans l'ordre de la galerie d'iOS.
@main
struct AlerteTCLWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeparturesWidget()
        BoardWidget()
        TrafficWidget()
        ParkingWidget()
        VelovWidget()
        WorksWidget()
    }
}
