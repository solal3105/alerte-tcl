package com.alertetcl.shared.platform

import platform.Foundation.NSBundle
import platform.Foundation.NSString
import platform.Foundation.NSUTF8StringEncoding
import platform.Foundation.stringWithContentsOfFile

object IosBundleSetup {
    @OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)
    fun install() {
        BundledResources.loader = { name ->
            val path = NSBundle.mainBundle.pathForResource(name, ofType = "json")
            if (path == null) null
            else NSString.stringWithContentsOfFile(path, encoding = NSUTF8StringEncoding, error = null) as String?
        }
    }
}
