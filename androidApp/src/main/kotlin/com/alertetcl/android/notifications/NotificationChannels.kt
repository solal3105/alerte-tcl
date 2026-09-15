package com.alertetcl.android.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

object NotificationChannels {
    const val ALERTS_CHANNEL_ID = "tcl_alerts"
    const val BUS_TRACKING_CHANNEL_ID = "bus_tracking"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(ALERTS_CHANNEL_ID, "Alertes trafic", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Perturbations sur les lignes auxquelles vous êtes abonné"
                }
            )
            nm.createNotificationChannel(
                NotificationChannel(BUS_TRACKING_CHANNEL_ID, "Suivi d'un bus", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Où en est le bus que vous attendez à un arrêt, mis à jour tant que l'application est ouverte"
                }
            )
        }
    }
}
