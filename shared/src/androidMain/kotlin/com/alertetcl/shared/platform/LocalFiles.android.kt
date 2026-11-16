package com.alertetcl.shared.platform

import java.io.File
import java.io.IOException
import kotlin.concurrent.Volatile

/** Dossier de cache de l'application, donné au démarrage par [AndroidBundleSetup.install]. */
internal object LocalFilesDirectory {
    @Volatile var directory: File? = null
        private set

    fun use(directory: File) {
        this.directory = directory
    }
}

internal actual fun readLocalFile(name: String): String? = try {
    LocalFilesDirectory.directory?.resolve(name)?.takeIf { it.isFile }?.readText()
} catch (e: IOException) {
    null
}

internal actual fun writeLocalFile(name: String, text: String): Boolean {
    val directory = LocalFilesDirectory.directory ?: return false
    return try {
        val draft = directory.resolve("$name.tmp")
        draft.writeText(text)
        draft.renameTo(directory.resolve(name))
    } catch (e: IOException) {
        false
    }
}
