package com.alertetcl.android

import android.app.Application
import android.content.Context
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.network.okhttp.OkHttpNetworkFetcherFactory
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.android.notifications.AlertWorkerScheduler
import com.alertetcl.android.notifications.NotificationChannels
import com.alertetcl.shared.models.LinePalette
import com.alertetcl.shared.platform.AndroidBundleSetup
import com.alertetcl.shared.platform.BundledResources
import com.alertetcl.shared.services.SiriLiteService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.maplibre.android.MapLibre

class AlerteTCLApplication : Application(), SingletonImageLoader.Factory {

    override fun newImageLoader(context: Context): ImageLoader =
        ImageLoader.Builder(context)
            .components { add(OkHttpNetworkFetcherFactory()) }
            .build()

    override fun onCreate() {
        super.onCreate()
        MapLibre.getInstance(this)
        AndroidBundleSetup.install(this)

        // Le JSON des arrêts pèse plusieurs centaines de Ko : jamais parsé sur le main thread.
        // `lazy` (SYNCHRONIZED) garantit une construction unique même si un lookup arrive
        // avant la fin du préchauffage.
        val stopNames = lazy { buildStopNamesMap() }
        SiriLiteService.shared.stopNameLookup = { stopNames.value[it] }
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        scope.launch { stopNames.value }

        // Couleurs officielles des lignes : rechargées avant tout accès réseau, puis
        // conservées à chaque mise à jour de l'index des fiches horaires.
        val store = FavoritesStore(this)
        scope.launch { LinePalette.restore(store.linePalette.first()) }
        LinePalette.onChange = { encoded -> scope.launch { store.setLinePalette(encoded) } }

        NotificationChannels.ensureChannels(this)
        AlertWorkerScheduler.schedule(this)
    }

    private fun buildStopNamesMap(): Map<String, String> {
        val json = BundledResources.loadJsonString("tcl_stops") ?: return emptyMap()
        return try {
            val arr = JSONArray(json)
            buildMap {
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    put(obj.getString("id"), obj.getString("name"))
                }
            }
        } catch (_: Throwable) { emptyMap() }
    }
}
