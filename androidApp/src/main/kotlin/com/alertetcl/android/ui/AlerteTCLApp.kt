package com.alertetcl.android.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.alertetcl.android.ui.about.AboutScreen
import com.alertetcl.android.ui.live.LiveMapScreen
import com.alertetcl.android.ui.parking.ParkingScreen
import com.alertetcl.android.ui.travaux.TravauxScreen

private data class TabItem(val route: String, val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)

private val tabs = listOf(
    TabItem("live",     "Transport", Icons.Filled.Tram),
    TabItem("travaux",  "Travaux",   Icons.Filled.Build),
    TabItem("parking",  "Parkings",  Icons.Filled.DirectionsCar),
    TabItem("about",    "Info",      Icons.Filled.Info),
)

@Composable
fun AlerteTCLApp() {
    val nav = rememberNavController()
    val backStackEntry = nav.currentBackStackEntryAsState().value
    val currentRoute = backStackEntry?.destination?.route

    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEach { tab ->
                    NavigationBarItem(
                        selected = currentRoute == tab.route ||
                                   backStackEntry?.destination?.hierarchy?.any { it.route == tab.route } == true,
                        onClick = {
                            nav.navigate(tab.route) {
                                launchSingleTop = true
                                restoreState = true
                                popUpTo(nav.graph.startDestinationId) { saveState = true }
                            }
                        },
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) }
                    )
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = nav,
            startDestination = "live",
            modifier = Modifier.padding(padding)
        ) {
            composable("live")    { LiveMapScreen() }
            composable("travaux") { TravauxScreen() }
            composable("parking") { ParkingScreen() }
            composable("about")   { AboutScreen() }
        }
    }
}
