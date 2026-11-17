package com.alertetcl.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.dp
import com.alertetcl.android.ui.theme.Tokens

/**
 * Haut d'une carte de l'onglet « Autour de moi » : la capsule de retour, puis ce que la carte y ajoute
 * (la barre de filtres des Vélo'v), posés sur un dégradé qui part de [Tokens.mapChrome] sous la barre
 * d'état et s'efface vers le bas. Le même pour toutes les cartes de l'onglet. Le dégradé ne capte aucun
 * geste : la carte se manipule au travers.
 */
@Composable
fun MapTopBar(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val chrome = Tokens.mapChrome
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    0f to chrome,
                    0.55f to chrome.copy(alpha = 0.75f),
                    1f to chrome.copy(alpha = 0f)
                )
            )
            .statusBarsPadding()
            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        content = content
    )
}
