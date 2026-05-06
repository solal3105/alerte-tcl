package com.alertetcl.android.ui.onboarding

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun NotificationPermissionView(onDismiss: () -> Unit) {
    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { onDismiss() }

    Column(
        modifier = Modifier.padding(horizontal = 32.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(16.dp))

        // Icon hero
        Box(
            modifier = Modifier
                .size(120.dp)
                .shadow(12.dp, CircleShape)
                .clip(CircleShape)
                .background(Brush.radialGradient(listOf(Color(0xFF42A5F5), Color(0xFF1565C0)))),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Filled.Notifications, null, tint = Color.White, modifier = Modifier.size(52.dp))
        }

        Spacer(Modifier.height(32.dp))

        Text("Restez informé", fontSize = 22.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(10.dp))
        Text(
            "Recevez des notifications en temps réel pour les perturbations sur vos lignes préférées",
            fontSize = 14.sp, color = Color.Gray, textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(32.dp))

        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            PermissionFeatureRow(
                icon = Icons.Filled.Warning, color = Color(0xFFFB8C00),
                title = "Alertes en temps réel",
                description = "Soyez prévenu dès qu'une perturbation affecte vos lignes"
            )
            PermissionFeatureRow(
                icon = Icons.Filled.Tune, color = Color(0xFF1976D2),
                title = "Personnalisable",
                description = "Choisissez les types d'alertes qui vous intéressent"
            )
            PermissionFeatureRow(
                icon = Icons.Filled.Lock, color = Color(0xFF43A047),
                title = "Confidentialité",
                description = "Vos données restent sur votre appareil"
            )
        }

        Spacer(Modifier.height(32.dp))

        Button(
            onClick = {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    onDismiss()
                }
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1976D2))
        ) {
            Text("Activer les notifications", fontWeight = FontWeight.SemiBold, fontSize = 15.sp,
                modifier = Modifier.padding(vertical = 4.dp))
        }
        Spacer(Modifier.height(8.dp))
        TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) {
            Text("Plus tard", color = Color.Gray)
        }
        Spacer(Modifier.height(16.dp))
    }
}
