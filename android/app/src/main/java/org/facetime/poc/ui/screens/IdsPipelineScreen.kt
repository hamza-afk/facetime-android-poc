package org.facetime.poc.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import org.facetime.model.IdsState
import org.facetime.poc.ui.components.HardGoNoGoBanner

@Composable
fun IdsPipelineScreen(
    idsState: IdsState,
    onStartRegistrationClicked: () -> Unit,
    onResetClicked: () -> Unit
) {
    val stageNames = listOf(
        "1. IDS_AUTH_CONTEXT_READY (GrandSlam & DSID)",
        "2. IDS_BAG_LOADED (init.ess.apple.com VCInit)",
        "3. IDS_PUSH_TOKEN_ACQUIRED (APS Courier Bound)",
        "4. IDS_IDENTITIES_GENERATED (RSA 1280 & EC P-256)",
        "5. IDS_SERVICE_REGISTERED (id-register Dispatched)",
        "6. IDS_REGISTERED (Apple Signed Certificate)",
        "7. IDS_FACETIME_SERVICE_BOUND (Ready for Calls)"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("7-Stage IDS Registration Stepper", style = MaterialTheme.typography.headlineMedium)

        // Hard Go/No-Go Gate Banner
        if (idsState is IdsState.HardHardwareBlocker) {
            HardGoNoGoBanner(blocker = idsState)
        }

        Card(modifier = Modifier.fillMaxWidth().weight(1f)) {
            LazyColumn(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                itemsIndexed(stageNames) { idx, name ->
                    val (icon, color) = when {
                        idsState is IdsState.Registered -> Icons.Default.CheckCircle to Color(0xFF2E7D32)
                        idsState is IdsState.InProgress && idsState.currentStageIndex > idx -> Icons.Default.CheckCircle to Color(0xFF2E7D32)
                        idsState is IdsState.InProgress && idsState.currentStageIndex == idx -> Icons.Default.PlayArrow to Color(0xFFF57F17)
                        idsState is IdsState.HardHardwareBlocker && idx >= 4 -> Icons.Default.Error to Color(0xFFC62828)
                        else -> Icons.Default.HourglassEmpty to Color.Gray
                    }

                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon(icon, contentDescription = null, tint = color)
                        Text(name, style = MaterialTheme.typography.bodyLarge)
                    }
                }
            }
        }

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = onStartRegistrationClicked,
                modifier = Modifier.weight(1f),
                enabled = idsState !is IdsState.InProgress
            ) {
                Text("Execute IDS Registration")
            }
            OutlinedButton(onClick = onResetClicked, modifier = Modifier.weight(1f)) {
                Text("Reset")
            }
        }
    }
}
