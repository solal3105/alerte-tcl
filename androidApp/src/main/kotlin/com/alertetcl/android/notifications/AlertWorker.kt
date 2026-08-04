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
import com.alertetcl.shared.models.AlertNotificationPhase
import com.alertetcl.shared.models.AlertSeverity
import com.alertetcl.shared.models.TCLAlert
import com.alertetcl.shared.services.TclApiService
import com.alertetcl.shared.util.AppLogger
import kotlinx.coroutines.flow.first

class AlertWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        return try {
            val store = FavoritesStore(applicationContext)
            val favorites = store.favoriteLines.first()
            if (favorites.isEmpty()) return Result.success()

            val severityPrefs = store.lineSeverityPreferences.first()
            val alerts = TclApiService.shared.fetchAlerts()
            val now = System.currentTimeMillis() / 1000L

            // Premier lancement : marquer tout comme vu silencieusement (anti-flood)
            val baselinePrefs = applicationContext.getSharedPreferences(BASELINE_PREFS_NAME, android.content.Context.MODE_PRIVATE)
            if (!baselinePrefs.getBoolean(BASELINE_DONE_KEY, false)) {
                val allKeys = alerts
                    .filter { it.isFavorite(favorites) }
                    .flatMap { alert ->
                        listOf(
                            alert.notificationKey(AlertNotificationPhase.ANNOUNCED),
                            alert.notificationKey(AlertNotificationPhase.ACTIVE)
                        )
                    }.toSet()
                val current = seenKeys().toMutableList()
                allKeys.forEach { if (it !in current) current += it }
                saveSeen(current)
                baselinePrefs.edit().putBoolean(BASELINE_DONE_KEY, true).apply()
                AppLogger.debug("AlertWorker: baseline (${allKeys.size / 2} alertes silencieuses)")
                return Result.success()
            }

            val alreadySeen = seenKeys().toSet()
            alerts
                .filter { it.isActive(now) && it.isFavorite(favorites) }
                .forEach { alert ->
                    val prefs = severityPrefs[alert.ligneCom]
                        ?: setOf(AlertSeverity.MAJOR, AlertSeverity.DISRUPTION, AlertSeverity.INFO)
                    if (alert.severity !in prefs) return@forEach

                    if (alert.isUpcoming(now)) {
                        val key = alert.notificationKey(AlertNotificationPhase.ANNOUNCED)
                        if (key !in alreadySeen) { post(alert, AlertNotificationPhase.ANNOUNCED); markSeen(key) }
                    }
                    if (alert.isOngoing(now)) {
                        val key = alert.notificationKey(AlertNotificationPhase.ACTIVE)
                        if (key !in alreadySeen) { post(alert, AlertNotificationPhase.ACTIVE); markSeen(key) }
                    }
                }

            Result.success()
        } catch (e: Throwable) {
            AppLogger.error("AlertWorker", e)
            Result.retry()
        }
    }

    private fun post(alert: TCLAlert, phase: AlertNotificationPhase) {
        val ctx = applicationContext
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return

        val title = when (phase) {
            AlertNotificationPhase.ANNOUNCED -> "📅 ${alert.ligneCom} — À venir"
            AlertNotificationPhase.ACTIVE    -> "⚠️ ${alert.ligneCom} — En cours"
        }
        val key = alert.notificationKey(phase)
        val intent = Intent(ctx, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            ctx, key.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(ctx, NotificationChannels.ALERTS_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(alert.titre)
            .setStyle(NotificationCompat.BigTextStyle().bigText(alert.message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        NotificationManagerCompat.from(ctx).notify(key.hashCode(), notif)
    }

    /** Une alerte concerne l'utilisateur si l'un de ses deux libellés de ligne est en favori (parité iOS). */
    private fun TCLAlert.isFavorite(favorites: Set<String>): Boolean =
        ligneCom in favorites || ligneCli in favorites

    /** Clés déjà notifiées, de la plus ancienne à la plus récente : l'ordre pilote la purge. */
    private fun seenKeys(): List<String> {
        prefs().getString(SEEN_KEYS_KEY, null)?.let { stored ->
            return stored.split(SEPARATOR).filter { it.isNotEmpty() }
        }
        // Migration depuis l'ancien Set non ordonné (purge aléatoire ⇒ notifications en double)
        return (prefs().getStringSet(LEGACY_SEEN_KEYS_KEY, emptySet()) ?: emptySet()).toList()
    }

    private fun saveSeen(keys: List<String>) {
        val trimmed = if (keys.size > MAX_SEEN_KEYS) keys.takeLast(MAX_SEEN_KEYS / 2) else keys
        prefs().edit()
            .putString(SEEN_KEYS_KEY, trimmed.joinToString(SEPARATOR))
            .remove(LEGACY_SEEN_KEYS_KEY)
            .apply()
    }

    private fun markSeen(key: String) {
        val current = seenKeys().toMutableList()
        if (key !in current) current += key
        saveSeen(current)
    }

    private fun prefs() = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        private const val PREFS_NAME            = "notif_dedup"
        private const val SEEN_KEYS_KEY         = "seen_keys_ordered"
        private const val LEGACY_SEEN_KEYS_KEY  = "seen_keys"
        private const val SEPARATOR             = "\n"
        private const val MAX_SEEN_KEYS         = 500
        private const val BASELINE_PREFS_NAME   = "notif_baseline"
        private const val BASELINE_DONE_KEY     = "done"
    }
}
