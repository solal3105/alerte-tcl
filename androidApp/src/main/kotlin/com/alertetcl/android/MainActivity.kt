package com.alertetcl.android

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.alertetcl.android.ui.AlerteTCLApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val initialRoute = intent?.getStringExtra(EXTRA_INITIAL_ROUTE)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    AlerteTCLApp(initialRoute = initialRoute)
                }
            }
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
    }
}
