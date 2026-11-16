package com.alertetcl.android.ui.components

import androidx.compose.material3.Badge
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.alertetcl.android.ui.theme.Tokens
import com.alertetcl.shared.models.NewBadges

/**
 * Pastille « Nouveau » ([NewBadges]) à l'accent : la même sur la tuile de l'accueil « Autour de moi » et
 * sur l'onglet qui la porte, allumées et éteintes ensemble.
 */
@Composable
fun NewBadge(modifier: Modifier = Modifier) {
    Badge(modifier = modifier, containerColor = Tokens.accent, contentColor = Color.White) {
        Text(NewBadges.LABEL)
    }
}
