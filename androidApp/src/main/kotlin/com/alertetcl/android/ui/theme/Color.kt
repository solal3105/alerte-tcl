package com.alertetcl.android.ui.theme

import androidx.compose.ui.graphics.Color
import com.alertetcl.android.ui.colorFromHex
import com.alertetcl.shared.design.AppColors

// ─── Accent : le bleu de l'application, défini une fois dans le module partagé ─────
val AccentLight = colorFromHex(AppColors.accent.light)
val AccentDark  = colorFromHex(AppColors.accent.dark)

// ─── Tons de marque pour les conteneurs Material (dérivés du même bleu) ────────────
val TclBlue10  = Color(0xFF001C3B)
val TclBlue20  = Color(0xFF00397B)
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
val Neutral90 = Color(0xFFE4E1E6)
val Neutral99 = Color(0xFFFEF7FF)

val NeutralVariant30 = Color(0xFF46464F)
val NeutralVariant50 = Color(0xFF767680)
val NeutralVariant60 = Color(0xFF909094)
val NeutralVariant80 = Color(0xFFC7C5D0)
val NeutralVariant90 = Color(0xFFE4E1EC)
