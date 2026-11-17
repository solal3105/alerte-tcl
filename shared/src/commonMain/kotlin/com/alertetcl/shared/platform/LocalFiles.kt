package com.alertetcl.shared.platform

/**
 * Fichiers texte gardés d'un lancement à l'autre dans le dossier de cache de l'application : des
 * copies de données que le relais sait redonner, que le système peut donc effacer s'il manque de place.
 */

/** Contenu du fichier [name], ou null s'il n'existe pas ou ne se lit pas. */
internal expect fun readLocalFile(name: String): String?

/** Remplace d'un seul coup le fichier [name] (jamais de fichier à moitié écrit) ; false si l'écriture a échoué. */
internal expect fun writeLocalFile(name: String, text: String): Boolean
