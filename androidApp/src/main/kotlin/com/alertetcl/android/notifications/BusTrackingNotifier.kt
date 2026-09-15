package com.alertetcl.android.notifications

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.alertetcl.android.MainActivity
import com.alertetcl.android.R
import com.alertetcl.shared.models.ApproachingVehicle
import com.alertetcl.shared.models.StopApproach

/**
 * Notification du bus suivi jusqu'à un arrêt (équivalent Android de l'activité en direct iOS).
 * Mise à jour à chaque réception de positions tant que l'application est ouverte ; le compte à
 * rebours jusqu'à l'arrivée estimée est rendu par le système. Rien n'est extrapolé hors de l'app.
 */
object BusTrackingNotifier {
    private const val NOTIFICATION_ID = 4211

    /** Met à jour la notification ; [endedText] renseigné quand le suivi se termine (la notification devient effaçable d'un geste). */
    fun show(context: Context, line: String, destination: String, stopName: String, approach: ApproachingVehicle?, endedText: String?) {
        val nowMs = System.currentTimeMillis()
        val text = when {
            endedText != null -> endedText
            approach == null -> "Position en attente"
            else -> buildString {
                append(approach.stopsText)
                approach.estimatedTime()?.let { append(" · arrivée estimée $it") }
                append(" · ").append(approach.positionText(nowMs))
            }
        }
        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = NotificationCompat.Builder(context, NotificationChannels.BUS_TRACKING_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("$line vers $destination")
            .setContentText(text)
            .setSubText("Arrêt $stopName")
            .setStyle(NotificationCompat.BigTextStyle().bigText(if (endedText != null) text else "$text\n${StopApproach.NOTE}"))
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setAutoCancel(true)
            .setContentIntent(open)
        val eta = approach?.estimatedArrivalEpoch
        if (endedText == null && eta != null && eta * 1000 > nowMs) {
            builder.setWhen(eta * 1000).setShowWhen(true).setUsesChronometer(true).setChronometerCountDown(true)
        }
        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
    }

    fun cancel(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }
}
