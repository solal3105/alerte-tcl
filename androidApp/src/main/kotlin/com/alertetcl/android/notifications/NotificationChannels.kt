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
            nm.createNotificationChannel(
                NotificationChannel(ALERTS_CHANNEL_ID, "Alertes trafic", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Perturbations sur les lignes auxquelles vous êtes abonné"
                }
            )
        }
    }
}
