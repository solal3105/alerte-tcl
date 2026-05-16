package com.alertetcl.android.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

// ─── Fallback schemes for Android < 12 (no dynamic color) ────────────────────

private val LightColorScheme = lightColorScheme(
    primary             = TclBlue40,
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
    primary             = TclBlue80,
    onPrimary           = TclBlue20,
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

// ─── App theme ────────────────────────────────────────────────────────────────

/**
 * Material You theme for AlerteTCL / Lyon Pocket.
 *
 * On Android 12+ (API 31) uses dynamic color extracted from the system wallpaper,
 * giving the app a true Material You feel.
 * On older devices falls back to a hand-crafted TCL blue scheme.
 * Dark mode is handled automatically via [isSystemInDarkTheme].
 */
@Composable
fun AlerteTCLTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else      -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography  = AlerteTCLTypography,
        content     = content,
    )
}
