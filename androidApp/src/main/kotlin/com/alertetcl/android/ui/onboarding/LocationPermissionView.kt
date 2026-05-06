package com.alertetcl.android.ui.onboarding

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MyLocation
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun LocationPermissionView(onDismiss: () -> Unit) {
    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
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
            Icon(Icons.Filled.MyLocation, null, tint = Color.White, modifier = Modifier.size(52.dp))
        }

        Spacer(Modifier.height(32.dp))

        Text("Trouvez-vous facilement", fontSize = 22.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(10.dp))
        Text(
            "Centrez automatiquement la carte sur votre position pour voir les transports autour de vous",
            fontSize = 14.sp, color = Color.Gray, textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(32.dp))

        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            PermissionFeatureRow(
                icon = Icons.Filled.MyLocation, color = Color(0xFF1976D2),
                title = "Centrage automatique",
                description = "La carte se centre sur votre position actuelle"
            )
            PermissionFeatureRow(
                icon = Icons.Filled.Map, color = Color(0xFF43A047),
                title = "Transports à proximité",
                description = "Visualisez les véhicules autour de vous en temps réel"
            )
            PermissionFeatureRow(
                icon = Icons.Filled.Lock, color = Color(0xFFFB8C00),
                title = "Confidentialité",
                description = "Votre position n'est jamais partagée ni stockée"
            )
        }

        Spacer(Modifier.height(32.dp))

        Button(
            onClick = {
                launcher.launch(arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ))
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1976D2))
        ) {
            Text("Activer la localisation", fontWeight = FontWeight.SemiBold, fontSize = 15.sp,
                modifier = Modifier.padding(vertical = 4.dp))
        }
        Spacer(Modifier.height(8.dp))
        TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) {
            Text("Plus tard", color = Color.Gray)
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
internal fun PermissionFeatureRow(icon: ImageVector, color: Color, title: String, description: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier.size(40.dp).clip(RoundedCornerShape(10.dp)).background(color.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) { Icon(icon, null, tint = color, modifier = Modifier.size(20.dp)) }
        Spacer(Modifier.width(14.dp))
        Column {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            Text(description, fontSize = 12.sp, color = Color.Gray)
        }
    }
}
