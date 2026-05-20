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
            val alreadySeen = seenKeys()

            alerts
                .filter { it.isActive(now) && it.ligneCom in favorites }
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
        val intent = Intent(ctx, MainActivity::class.java).apply { putExtra("alertId", alert.id) }
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

    private fun seenKeys(): Set<String> =
        prefs().getStringSet(PREFS_KEY, emptySet()) ?: emptySet()

    private fun markSeen(key: String) {
        val current = (prefs().getStringSet(PREFS_KEY, emptySet()) ?: emptySet()).toMutableSet()
        current.add(key)
        val trimmed = if (current.size > 500) current.toList().takeLast(250).toSet() else current
        prefs().edit().putStringSet(PREFS_KEY, trimmed).apply()
    }

    private fun prefs() = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        private const val PREFS_NAME = "notif_dedup"
        private const val PREFS_KEY  = "seen_keys"
    }
}
