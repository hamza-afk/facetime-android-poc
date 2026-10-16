package org.facetime.poc.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import org.facetime.model.ApsConnectionStatus
import org.facetime.model.ApsState
import org.facetime.poc.ui.components.StatusBadge

@Composable
fun ApsScreen(
    apsState: ApsState,
    onForceReconnect: () -> Unit,
    onSendPing: () -> Unit,
    onSimulateInterfaceDrop: () -> Unit
) {
    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("Apple Push Service (APS) Status", style = MaterialTheme.typography.headlineMedium)

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Courier Status", style = MaterialTheme.typography.titleMedium)
                    val (badgeText, badgeColor) = when (apsState.status) {
                        ApsConnectionStatus.CONNECTED -> "CONNECTED" to Color(0xFF2E7D32)
                        ApsConnectionStatus.CONNECTING -> "CONNECTING" to Color(0xFFF57F17)
                        ApsConnectionStatus.RECONNECTING -> "RECONNECTING" to Color(0xFFE65100)
                        ApsConnectionStatus.DISCONNECTED -> "DISCONNECTED" to Color(0xFFC62828)
                    }
                    StatusBadge(text = badgeText, color = badgeColor)
                }

                HorizontalDivider()

                Text("Courier Endpoint: ${apsState.courierHost}")
                Text("Local Interface: ${apsState.activeInterface}")
                Text("TLS ALPN: apns-pack-v1 (TLS 1.3)")
                Text("Ping Round-Trip Latency: ${apsState.pingLatencyMs?.let { "${it}ms" } ?: "N/A"}")

                HorizontalDivider()

                Text("Push Token (32 bytes):", style = MaterialTheme.typography.labelLarge)
                val tokenDisplay = apsState.pushTokenHex ?: "Not yet acquired"
                Text(
                    text = tokenDisplay,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                if (apsState.pushTokenHex != null) {
                    Button(
                        onClick = {
                            val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            cm.setPrimaryClip(ClipData.newPlainText("APS Push Token", apsState.pushTokenHex))
                        },
                        modifier = Modifier.align(Alignment.End)
                    ) {
                        Text("Copy Token")
                    }
                }
            }
        }

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Registered Topics", style = MaterialTheme.typography.titleMedium)
                apsState.registeredTopics.forEach { topic ->
                    Text("• $topic", style = MaterialTheme.typography.bodyMedium)
                }
            }
        }

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = onForceReconnect, modifier = Modifier.weight(1f)) {
                Text("Reconnect")
            }
            Button(onClick = onSendPing, modifier = Modifier.weight(1f)) {
                Text("Ping (0x0C)")
            }
        }

        OutlinedButton(
            onClick = onSimulateInterfaceDrop,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Simulate Wi-Fi ↔ Cellular Drop")
        }
    }
}
