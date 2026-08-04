package com.alertetcl.android.ui

import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Ouvre une URL dans le navigateur.
 * Les URL des jeux de données Grand Lyon arrivent parfois sans schéma : on préfixe en https.
 * L'échec (aucune application capable de gérer l'intent) est ignoré, jamais fatal.
 */
internal fun openUrl(context: Context, url: String) {
    val normalized = if ("://" in url) url else "https://$url"
    runCatching {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(normalized)))
    }
}
