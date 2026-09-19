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
import com.alertetcl.shared.models.CityTile
import com.alertetcl.shared.models.ParkingType
import com.alertetcl.shared.models.TransportMode
import com.alertetcl.shared.models.TravauxImportance
import com.alertetcl.shared.models.VehicleType

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

    @Composable @ReadOnlyComposable
    fun cityTile(tile: CityTile): Color = AppColors.cityTile(tile).compose()

    @Composable @ReadOnlyComposable
    fun travauxImportance(importance: TravauxImportance): Color =
        AppColors.travauxImportance(importance)?.compose() ?: MaterialTheme.colorScheme.onSurfaceVariant
}
