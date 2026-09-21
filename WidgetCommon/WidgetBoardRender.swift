#if DEBUG
import SwiftUI
import UIKit
import WidgetKit

/// Planche de contrôle des widgets : chaque widget est rendu dans toutes ses tailles, en clair et en
/// sombre, et enregistré en PNG dans le conteneur de l'application. Sert à juger la mise en page sans
/// poser les widgets à la main ; lancée par l'argument `-render-widgets`.
@MainActor
enum WidgetBoardRender {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-render-widgets")
    }

    private static func size(_ family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: CGSize(width: 170, height: 170)
        case .systemLarge: CGSize(width: 364, height: 382)
        default: CGSize(width: 364, height: 170)
        }
    }

    private static func families(_ kind: WidgetKind) -> [WidgetFamily] {
        kind.families.filter { [.systemSmall, .systemMedium, .systemLarge].contains($0) }
    }

    /// Les chantiers de démonstration avec une vraie carte, comme dans le widget.
    private static var works = WidgetSamples.works

    private static func prepareWorksMap() async {
        let sample = WidgetSamples.works
        let light = await WorksMapSnapshot.render(center: WorksMapSnapshot.lyonCenter, radiusMeters: 1000, shapes: WidgetSamples.worksShapes, size: CGSize(width: 364, height: 200), scale: 2, dark: false, showUser: true)
        let dark = await WorksMapSnapshot.render(center: WorksMapSnapshot.lyonCenter, radiusMeters: 1000, shapes: WidgetSamples.worksShapes, size: CGSize(width: 364, height: 200), scale: 2, dark: true, showUser: true)
        works = WorksEntry(
            date: sample.date, status: .ready, works: sample.works, radiusMeters: sample.radiusMeters,
            hasLocation: true, mapLight: light, mapDark: dark, fetchedAt: sample.fetchedAt
        )
    }

    /// Une planche par mode d'affichage, en colonnes : un widget par ligne, ses tailles côte à côte.
    static func renderAll() async {
        await prepareWorksMap()
        for scheme in [ColorScheme.light, .dark] {
            let board = VStack(alignment: .leading, spacing: 22) {
                ForEach(WidgetKind.allCases, id: \.rawValue) { kind in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(kind.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(scheme == .dark ? .white : .black)
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(families(kind), id: \.rawValue) { family in
                                card(kind: kind, family: family)
                            }
                        }
                    }
                }
            }
            .padding(24)
            .background(scheme == .dark ? Color.black : Color(white: 0.92))
            .environment(\.colorScheme, scheme)

            let renderer = ImageRenderer(content: board)
            renderer.scale = 2
            guard let image = renderer.uiImage, let data = image.pngData() else { continue }
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(scheme == .dark ? "widgets-sombre.png" : "widgets-clair.png")
            try? data.write(to: url)
            print("PLANCHE \(url.path)")
        }
    }

    @ViewBuilder
    private static func card(kind: WidgetKind, family: WidgetFamily) -> some View {
        let dimension = size(family)
        content(kind: kind, family: family)
            .frame(width: dimension.width, height: dimension.height)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private static func content(kind: WidgetKind, family: WidgetFamily) -> some View {
        switch kind {
        case .departures: DeparturesWidgetView(entry: WidgetSamples.departures, family: family).padding(16)
        case .board: BoardWidgetView(entry: WidgetSamples.board, family: family).padding(16)
        case .parking: ParkingWidgetView(entry: WidgetSamples.parking, family: family).padding(16)
        case .velov: VelovWidgetView(entry: WidgetSamples.velov, family: family).padding(16)
        case .works: WorksWidgetView(entry: works, family: family)
        case .traffic: TrafficWidgetView(entry: WidgetSamples.traffic, family: family).padding(16)
        }
    }

}
#endif
