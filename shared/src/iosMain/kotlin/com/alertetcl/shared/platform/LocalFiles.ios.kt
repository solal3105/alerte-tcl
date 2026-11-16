package com.alertetcl.shared.platform

import kotlinx.cinterop.ExperimentalForeignApi
import platform.Foundation.NSCachesDirectory
import platform.Foundation.NSSearchPathForDirectoriesInDomains
import platform.Foundation.NSString
import platform.Foundation.NSUTF8StringEncoding
import platform.Foundation.NSUserDomainMask
import platform.Foundation.stringWithContentsOfFile
import platform.Foundation.writeToFile

private fun localFilePath(name: String): String? =
    (NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true).firstOrNull() as? String)?.let { "$it/$name" }

@OptIn(ExperimentalForeignApi::class)
internal actual fun readLocalFile(name: String): String? {
    val path = localFilePath(name) ?: return null
    return NSString.stringWithContentsOfFile(path, encoding = NSUTF8StringEncoding, error = null) as String?
}

// Une String Kotlin est une NSString à l'exécution : le compilateur ne le sait pas.
@Suppress("CAST_NEVER_SUCCEEDS")
@OptIn(ExperimentalForeignApi::class)
internal actual fun writeLocalFile(name: String, text: String): Boolean {
    val path = localFilePath(name) ?: return false
    return (text as NSString).writeToFile(path, atomically = true, encoding = NSUTF8StringEncoding, error = null)
}
