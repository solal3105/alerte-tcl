package com.alertetcl.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.graphics.Color
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.design.AppColors
import com.alertetcl.shared.design.ThemedColor
import com.alertetcl.shared.models.AlertSeverity
import com.alertetcl.shared.models.AvailabilityColor
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.models.TransportMode
import com.alertetcl.shared.models.TravauxImportance
import com.alertetcl.shared.models.VehicleType
import com.alertetcl.shared.models.VelovChanceLevel

/** Variante de la couleur adaptée au thème courant. */
@Composable
@ReadOnlyComposable
fun ThemedColor.compose(): Color = colorFromHex(hex(isSystemInDarkTheme()))

/**
 * Accès Compose aux jetons de couleur partagés ([AppColors]) : les vues ne définissent aucune
 * couleur sémantique elles-mêmes.
 */
object Tokens {
    val accent: Color @Composable @ReadOnlyComposable get() = AppColors.accent.compose()
    val success: Color @Composable @ReadOnlyComposable get() = AppColors.success.compose()
    val warning: Color @Composable @ReadOnlyComposable get() = AppColors.warning.compose()
    val error: Color @Composable @ReadOnlyComposable get() = AppColors.error.compose()
    val favorite: Color @Composable @ReadOnlyComposable get() = AppColors.favorite.compose()
    /** Haut des cartes « Autour de moi », d'où part le dégradé sous le titre et les filtres. */
    val mapChrome: Color @Composable @ReadOnlyComposable get() = AppColors.mapChrome.compose()
    /** Texte sur fond clair (badge de sévérité ou de mode à fond vif). */
    val onLight: Color get() = colorFromHex(AppColors.onLight)

    @Composable @ReadOnlyComposable
    fun severity(severity: AlertSeverity): Color = AppColors.alertSeverity(severity).compose()

    /** Couleur d'un mode dans les filtres ; les lignes elles-mêmes utilisent la palette officielle. */
    fun mode(mode: TransportMode): Color = colorFromHex(AppColors.mode(mode))

    fun vehicleType(type: VehicleType): Color = colorFromHex(AppColors.vehicleType(type))

    @Composable @ReadOnlyComposable
    fun parkingAvailability(color: AvailabilityColor): Color = AppColors.parkingAvailability(color).compose()

    @Composable @ReadOnlyComposable
    fun parkingType(type: ParkingType): Color = AppColors.parkingType(type).compose()

    /** Chance de trouver un vélo ou une place à une station Vélo'v, en texte. */
    @Composable @ReadOnlyComposable
    fun velovChance(level: VelovChanceLevel): Color = AppColors.velovChance(level).compose()

    /** La même chance sur la piste du curseur de prévision, où « probable » prend le vert atténué. */
    @Composable @ReadOnlyComposable
    fun velovChanceTrack(level: VelovChanceLevel): Color = AppColors.velovChanceTrack(level).compose()

    @Composable @ReadOnlyComposable
    fun travauxImportance(importance: TravauxImportance): Color =
        AppColors.travauxImportance(importance)?.compose() ?: MaterialTheme.colorScheme.onSurfaceVariant
}
