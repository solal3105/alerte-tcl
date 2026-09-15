package com.alertetcl.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColorScheme = lightColorScheme(
    primary             = AccentLight,
    onPrimary           = Neutral99,
    primaryContainer    = TclBlue90,
    onPrimaryContainer  = TclBlue10,
    secondary           = TclSecondary40,
    onSecondary         = Neutral99,
    secondaryContainer  = TclSecondary90,
    onSecondaryContainer = Neutral10,
    tertiary            = TclTertiary40,
    onTertiary          = Neutral99,
    tertiaryContainer   = TclTertiary90,
    onTertiaryContainer = Neutral10,
    error               = TclError40,
    onError             = Neutral99,
    errorContainer      = TclError90,
    onErrorContainer    = TclError10,
    background          = Neutral99,
    onBackground        = Neutral10,
    surface             = Neutral99,
    onSurface           = Neutral10,
    surfaceVariant      = NeutralVariant90,
    onSurfaceVariant    = NeutralVariant30,
    outline             = NeutralVariant50,
    outlineVariant      = NeutralVariant80,
)

private val DarkColorScheme = darkColorScheme(
    primary             = AccentDark,
    onPrimary           = Neutral99,
    primaryContainer    = TclBlue20,
    onPrimaryContainer  = TclBlue90,
    secondary           = TclSecondary80,
    onSecondary         = Neutral10,
    secondaryContainer  = TclSecondary40,
    onSecondaryContainer = TclSecondary90,
    tertiary            = TclTertiary80,
    onTertiary          = Neutral10,
    tertiaryContainer   = TclTertiary40,
    onTertiaryContainer = TclTertiary90,
    error               = TclError80,
    onError             = TclError10,
    errorContainer      = TclError40,
    onErrorContainer    = TclError90,
    background          = Neutral10,
    onBackground        = Neutral90,
    surface             = Neutral10,
    onSurface           = Neutral90,
    surfaceVariant      = NeutralVariant30,
    onSurfaceVariant    = NeutralVariant80,
    outline             = NeutralVariant60,
    outlineVariant      = NeutralVariant30,
)

/**
 * Thème de Lyon Pocket : l'accent est le bleu de l'application sur tous les appareils, sans
 * couleur dynamique tirée du fond d'écran, pour que l'interface soit la même que sur iOS.
 * Le mode sombre suit le réglage du téléphone.
 */
@Composable
fun AlerteTCLTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme,
        typography  = AlerteTCLTypography,
        content     = content,
    )
}
