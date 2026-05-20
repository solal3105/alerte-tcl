import SwiftUI

/// Couleurs officielles TCL par ligne. Source unique pour toute l'app.
struct LineColorHelper {

    /// Couleur de fond du badge de ligne.
    static func backgroundColor(for ligne: String) -> Color {
        let upper = ligne.uppercased()

        // Métro
        if upper == "MA" || upper == "A" { return Color(hex: "EE3898") } // Rose/Fuchsia
        if upper == "MB" || upper == "B" { return Color(hex: "007DC5") } // Bleu
        if upper == "MC" || upper == "C" { return Color(hex: "F99D1D") } // Orange
        if upper == "MD" || upper == "D" { return Color(hex: "00AC4D") } // Vert

        // Rhônexpress
        if upper == "RX" || upper.contains("RHONEXPRESS") { return Color(hex: "C92B21") }

        // Tramway
        if upper.hasPrefix("T") && upper.count <= 3 { return Color(hex: "8C368C") }

        // Trolleybus
        if upper.hasPrefix("TB") { return Color(hex: "FFCC00") }

        // Funiculaire
        if upper.hasPrefix("F") && upper.count <= 3 { return Color(hex: "8BC752") }

        // Bus C – gris
        if upper.hasPrefix("C") && upper.count <= 4 { return Color(.systemGray) }

        // Bus JD – bleu foncé
        if upper.hasPrefix("JD") { return Color(hex: "2A2475") }

        // Bus régulier – fond blanc
        return .white
    }

    /// Couleur du texte du badge de ligne.
    static func textColor(for ligne: String) -> Color {
        let upper = ligne.uppercased()

        if upper.hasPrefix("JD") { return Color(hex: "EBCA2F") }
        if upper.hasPrefix("C") && upper.count <= 4 { return .white }
        if upper.hasPrefix("T") && upper.count <= 3 { return .white }

        // Bus classiques (non-métro, non-funiculaire, non-TB, non-RX)
        let isMiscBus = !upper.hasPrefix("M") &&
            !upper.hasPrefix("F") &&
            !upper.hasPrefix("TB") &&
            upper != "A" && upper != "B" && upper != "C" && upper != "D" &&
            upper != "RX" && !upper.contains("RHONEXPRESS")

        if isMiscBus {
            if upper.hasPrefix("N") { return Color(hex: "DC7921") }
            if upper.hasSuffix("E") { return Color(hex: "5E3A18") }
            return .red
        }

        return .white
    }

    /// Indique si une bordure est nécessaire (fonds blancs).
    static func needsBorder(for ligne: String) -> Bool {
        let upper = ligne.uppercased()
        return !upper.hasPrefix("M") &&
            !upper.hasPrefix("F") &&
            !upper.hasPrefix("C") &&
            !upper.hasPrefix("T") &&
            !upper.hasPrefix("TB") &&
            !upper.hasPrefix("JD") &&
            upper != "A" && upper != "B" && upper != "C" && upper != "D" &&
            upper != "RX" && !upper.contains("RHONEXPRESS")
    }
}
