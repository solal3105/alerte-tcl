package com.alertetcl.android.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

object NotificationChannels {
    const val ALERTS_CHANNEL_ID = "tcl_alerts"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                ALERTS_CHANNEL_ID,
                "Alertes TCL",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alertes temps réel sur les lignes TCL favorites"
            }
            nm.createNotificationChannel(channel)
        }
    }
}
