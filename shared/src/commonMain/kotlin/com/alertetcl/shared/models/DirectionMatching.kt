package com.alertetcl.shared.models

/**
 * Rapprochement des noms de destination entre sources Grand Lyon (flux passages, terminus
 * GeoServer, fiches GTFS), dont les graphies diffèrent légèrement (accents, ponctuation,
 * abréviations en fin de nom).
 */
object DirectionMatching {
    private const val PREFIX_LENGTH = 8

    private val accentFree = mapOf(
        'à' to 'a', 'â' to 'a', 'ä' to 'a', 'á' to 'a', 'ç' to 'c', 'é' to 'e', 'è' to 'e', 'ê' to 'e',
        'ë' to 'e', 'î' to 'i', 'ï' to 'i', 'í' to 'i', 'ô' to 'o', 'ö' to 'o', 'ó' to 'o', 'ù' to 'u',
        'û' to 'u', 'ü' to 'u', 'ú' to 'u', 'ÿ' to 'y', 'ñ' to 'n', 'œ' to 'o', 'æ' to 'a'
    )

    /** Minuscules, sans accents, lettres et chiffres uniquement. */
    fun normalize(name: String): String = tokens(name).joinToString("")

    /** Mots du nom, en minuscules sans accents (« Hôp. Feyzin » → ["hop", "feyzin"]). */
    private fun tokens(name: String): List<String> {
        val result = ArrayList<String>()
        val current = StringBuilder()
        for (c in name.lowercase()) {
            val base = accentFree[c] ?: c
            if (base in 'a'..'z' || base in '0'..'9') {
                current.append(base)
            } else if (current.isNotEmpty()) {
                result.add(current.toString())
                current.setLength(0)
            }
        }
        if (current.isNotEmpty()) result.add(current.toString())
        return result
    }

    /** Un mot en abrège un autre s'il en est le début (« hop » / « hopital »). */
    private fun abbreviates(x: String, y: String): Boolean =
        x == y || (minOf(x.length, y.length) >= 2 && (x.startsWith(y) || y.startsWith(x)))

    /**
     * Vrai si les deux noms désignent le même lieu : identiques une fois normalisés, ou chaque
     * mot de l'un abrège le mot correspondant de l'autre (« Hôp. Feyzin » / « Hôpital Feyzin »),
     * ou l'un commence comme l'autre.
     */
    fun namesMatch(a: String, b: String): Boolean {
        val ta = tokens(a)
        val tb = tokens(b)
        if (ta.isEmpty() || tb.isEmpty()) return false
        if (ta == tb) return true
        if (ta.size == tb.size && ta.indices.all { abbreviates(ta[it], tb[it]) }) return true
        val na = ta.joinToString("")
        val nb = tb.joinToString("")
        if (na.length < PREFIX_LENGTH || nb.length < PREFIX_LENGTH) return false
        return na.startsWith(nb.take(PREFIX_LENGTH)) || nb.startsWith(na.take(PREFIX_LENGTH))
    }

    /**
     * Sens ("A" aller / "R" retour) d'une destination affichée, à partir des terminus
     * GeoServer ("C3|A" → nom du terminus). Null si ambigu ou inconnu.
     */
    fun resolveDirection(line: String, destination: String, termini: Map<String, String>): String? {
        val toA = termini["$line|A"]?.let { namesMatch(it, destination) } ?: false
        val toR = termini["$line|R"]?.let { namesMatch(it, destination) } ?: false
        return when {
            toA && !toR -> "A"
            toR && !toA -> "R"
            else -> null
        }
    }

    /** Code de sens du flux SIRI SYTRAL (`outbound` = aller, `inbound` = retour). */
    fun siriDirectionCode(raw: String?): String = when (raw?.trim()?.lowercase()) {
        "outbound" -> "A"
        "inbound" -> "R"
        else -> ""
    }
}
