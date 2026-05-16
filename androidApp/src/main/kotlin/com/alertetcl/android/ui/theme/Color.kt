package com.alertetcl.android.ui.theme

import androidx.compose.ui.graphics.Color

// ─── Brand seed — used as fallback on Android < 12 ───────────────────────────
// TCL Lyon blue (Sytral brand approximation)
val TclBlue10  = Color(0xFF001C3B)
val TclBlue20  = Color(0xFF00397B)
val TclBlue40  = Color(0xFF1565C0)
val TclBlue80  = Color(0xFF9ECAFF)
val TclBlue90  = Color(0xFFD5E3FF)

val TclSecondary40 = Color(0xFF545F71)
val TclSecondary80 = Color(0xFFBBC7DB)
val TclSecondary90 = Color(0xFFD7E3F7)

val TclTertiary40 = Color(0xFF6B538C)
val TclTertiary80 = Color(0xFFD3BAFC)
val TclTertiary90 = Color(0xFFECDCFF)

val TclError10  = Color(0xFF410002)
val TclError40  = Color(0xFFBA1A1A)
val TclError80  = Color(0xFFFFB4AB)
val TclError90  = Color(0xFFFFDAD6)

val Neutral10 = Color(0xFF1B1B1F)
val Neutral20 = Color(0xFF303034)
val Neutral90 = Color(0xFFE4E1E6)
val Neutral95 = Color(0xFFF3EFF4)
val Neutral99 = Color(0xFFFEF7FF)

val NeutralVariant30 = Color(0xFF46464F)
val NeutralVariant50 = Color(0xFF767680)
val NeutralVariant60 = Color(0xFF909094)
val NeutralVariant80 = Color(0xFFC7C5D0)
val NeutralVariant90 = Color(0xFFE4E1EC)

// ─── Semantic status colors (data-driven, not theme-driven) ──────────────────
// These represent real-world transport alert states and must stay legible
// across both light and dark themes regardless of wallpaper tint.
val StatusError   = Color(0xFFE53935)   // MAJOR alert / error
val StatusWarning = Color(0xFFFF9800)   // DISRUPTION alert / warning
val StatusSuccess = Color(0xFF43A047)   // Normal service / success

// ─── Transport mode colors (TCL official palette) ────────────────────────────
val ModeMetro     = Color(0xFFFF9500)
val ModeTramway   = Color(0xFF007AFF)
val ModeFunicular = Color(0xFF34C759)
val ModeBusC      = Color(0xFFAF52DE)
val ModeBus       = Color(0xFF5856D6)
val ModeNavette   = Color(0xFF32ADE6)
