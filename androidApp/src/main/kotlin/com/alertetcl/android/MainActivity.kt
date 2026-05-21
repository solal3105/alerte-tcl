package com.alertetcl.android

import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.alertetcl.android.ui.AlerteTCLApp
import com.alertetcl.android.ui.theme.AlerteTCLTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val initialRoute = intent?.getStringExtra(EXTRA_INITIAL_ROUTE)
        setContent {
            AlerteTCLTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    AlerteTCLApp(initialRoute = initialRoute)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // N-02: clear badge TCL uniquement (parité iOS setBadgeCount(0))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val nm = getSystemService(NotificationManager::class.java)
            nm?.activeNotifications
                ?.filter { it.notification.channelId == com.alertetcl.android.notifications.NotificationChannels.ALERTS_CHANNEL_ID }
                ?.forEach { nm.cancel(it.tag, it.id) }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(EXTRA_INITIAL_ROUTE)?.let {
            setIntent(intent)
            recreate()
        }
    }

    companion object {
        const val EXTRA_INITIAL_ROUTE = "initial_route"
        const val EXTRA_PARKING_ID = "parking_id"
    }
}
