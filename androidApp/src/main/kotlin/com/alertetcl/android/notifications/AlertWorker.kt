package com.alertetcl.android.notifications

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.alertetcl.android.MainActivity
import com.alertetcl.android.R
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.shared.models.AlertNotifications
import com.alertetcl.shared.services.TclApiService
import com.alertetcl.shared.util.AppLogger
import kotlinx.coroutines.flow.first

/**
 * Vérifie périodiquement les alertes trafic et notifie celles qui concernent une ligne abonnée,
 * selon la règle commune [AlertNotifications] (mêmes phases, même anti-doublon que sur iOS).
 */
class AlertWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        return try {
            val subscriptions = FavoritesStore(applicationContext).lineSubscriptions.first()
            if (subscriptions.isEmpty()) return Result.success()

            val alerts = TclApiService.shared.fetchAlerts()

            // Premier lancement : tout ce qui existe déjà est marqué vu, sans notification.
            if (!baselineDone()) {
                val baseline = AlertNotifications.baselineKeys(alerts, subscriptions)
                saveSeen(AlertNotifications.remember(seenKeys(), baseline))
                prefs().edit().putBoolean(BASELINE_DONE_KEY, true).apply()
                AppLogger.debug("AlertWorker: baseline (${baseline.size / 2} alertes silencieuses)")
                return Result.success()
            }

            val now = System.currentTimeMillis() / 1000L
            val pending = AlertNotifications.pending(alerts, subscriptions, seenKeys().toSet(), now)
            pending.forEach { post(it) }
            if (pending.isNotEmpty()) saveSeen(AlertNotifications.remember(seenKeys(), pending.map { it.key }))

            Result.success()
        } catch (e: Throwable) {
            AppLogger.error("AlertWorker", e)
            Result.retry()
        }
    }

    private fun post(pending: AlertNotifications.Pending) {
        val ctx = applicationContext
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return

        val alert = pending.alert
        val intent = Intent(ctx, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            ctx, pending.key.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(ctx, NotificationChannels.ALERTS_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(AlertNotifications.title(alert, pending.phase))
            .setContentText(AlertNotifications.subtitle(alert, pending.phase))
            .setStyle(NotificationCompat.BigTextStyle().bigText(alert.message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setGroup(GROUP_PREFIX + alert.ligneCom)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        NotificationManagerCompat.from(ctx).notify(pending.key.hashCode(), notif)
    }

    /** Clés déjà notifiées, de la plus ancienne à la plus récente : l'ordre pilote la purge. */
    private fun seenKeys(): List<String> {
        prefs().getString(SEEN_KEYS_KEY, null)?.let { stored ->
            return stored.split(SEPARATOR).filter { it.isNotEmpty() }
        }
        // Reprise de l'ancien ensemble non ordonné.
        return (prefs().getStringSet(LEGACY_SEEN_KEYS_KEY, emptySet()) ?: emptySet()).toList()
    }

    private fun saveSeen(keys: List<String>) {
        prefs().edit()
            .putString(SEEN_KEYS_KEY, keys.joinToString(SEPARATOR))
            .remove(LEGACY_SEEN_KEYS_KEY)
            .apply()
    }

    /** Le premier passage a déjà eu lieu (nouvelle clé, ou ancien fichier de préférences). */
    private fun baselineDone(): Boolean =
        prefs().getBoolean(BASELINE_DONE_KEY, false) ||
            applicationContext.getSharedPreferences(LEGACY_BASELINE_PREFS, Context.MODE_PRIVATE).getBoolean("done", false)

    private fun prefs() = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        private const val PREFS_NAME           = "notif_dedup"
        private const val SEEN_KEYS_KEY        = "seen_keys_ordered"
        private const val LEGACY_SEEN_KEYS_KEY = "seen_keys"
        private const val SEPARATOR            = "\n"
        private const val BASELINE_DONE_KEY    = "baseline_done"
        private const val LEGACY_BASELINE_PREFS = "notif_baseline"
        private const val GROUP_PREFIX         = "tcl-alerts-"
    }
}
