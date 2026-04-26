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
import com.alertetcl.android.data.FavoritesStore
import com.alertetcl.shared.models.TCLAlert
import com.alertetcl.shared.services.TclApiService
import com.alertetcl.shared.util.AppLogger
import kotlinx.coroutines.flow.first

/**
 * Worker en arrière-plan : récupère les alertes et notifie celles concernant
 * une ligne favorite et non encore notifiées.
 */
class AlertWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        return try {
            val store = FavoritesStore(applicationContext)
            val favorites = store.favoriteLines.first()
            if (favorites.isEmpty()) return Result.success()

            val alerts = TclApiService.shared.fetchAlerts()
            val now = System.currentTimeMillis() / 1000L
            val matching = alerts.filter { it.isActive(now) && it.ligneCom in favorites }

            matching.forEach { notify(it) }
            Result.success()
        } catch (e: Throwable) {
            AppLogger.error("AlertWorker", e)
            Result.retry()
        }
    }

    private fun notify(alert: TCLAlert) {
        val ctx = applicationContext
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return

        val intent = Intent(ctx, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            ctx, alert.id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(ctx, NotificationChannels.ALERTS_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Ligne ${alert.ligneCom} : ${alert.titre}")
            .setContentText(alert.message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(alert.message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        NotificationManagerCompat.from(ctx).notify(alert.id.hashCode(), notif)
    }
}
