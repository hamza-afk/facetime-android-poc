package org.facetime.poc.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.CallEnd
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import org.facetime.model.CallSessionState
import org.facetime.model.RecipientCapability
import org.facetime.poc.ui.components.StatusBadge

@Composable
fun CallTriggerScreen(
    callState: CallSessionState,
    onResolveRecipient: (String) -> Unit,
    onStartCall: (String) -> Unit,
    onEndCall: (String) -> Unit
) {
    var recipientHandle by remember { mutableStateOf("") }
    var resolvedCapability by remember { mutableStateOf(RecipientCapability.UNKNOWN) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("FaceTime Outgoing Call Signaling", style = MaterialTheme.typography.headlineMedium)

        OutlinedTextField(
            value = recipientHandle,
            onValueChange = { recipientHandle = it },
            label = { Text("Recipient Apple ID Email / Phone (E.164)") },
            modifier = Modifier.fillMaxWidth()
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Button(onClick = {
                resolvedCapability = RecipientCapability.CHECKING
                onResolveRecipient(recipientHandle)
                resolvedCapability = RecipientCapability.FACETIME_CAPABLE
            }) {
                Text("Resolve Capabilities")
            }

            val (badgeText, badgeColor) = when (resolvedCapability) {
                RecipientCapability.FACETIME_CAPABLE -> "FACETIME_CAPABLE" to Color(0xFF2E7D32)
                RecipientCapability.AUDIO_ONLY -> "AUDIO_ONLY" to Color(0xFF1565C0)
                RecipientCapability.NOT_REGISTERED -> "NOT_REGISTERED" to Color(0xFFC62828)
                RecipientCapability.CHECKING -> "CHECKING..." to Color(0xFFF57F17)
                RecipientCapability.UNKNOWN -> "UNCHECKED" to Color.Gray
            }
            StatusBadge(text = badgeText, color = badgeColor)
        }

        Card(modifier = Modifier.fillMaxWidth().weight(1f)) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Call Session State Machine", style = MaterialTheme.typography.titleMedium)

                when (callState) {
                    is CallSessionState.Idle -> Text("Status: IDLE (No active outgoing invite)")
                    is CallSessionState.Resolving -> Text("Status: Resolving Apple Directory for ${callState.handle}")
                    is CallSessionState.SessionCreated -> Text("Status: Session Created [${callState.callId}]")
                    is CallSessionState.InviteSent -> Text("Status: Invite Sent (Command 207 PDU dispatched)")
                    is CallSessionState.RemoteRinging -> {
                        Text(
                            "STATUS: REMOTE RINGING",
                            style = MaterialTheme.typography.titleLarge,
                            color = Color(0xFF2E7D32)
                        )
                        Text("Target iPhone is ringing! Elapsed: ${callState.elapsedSeconds}s")
                    }
                    is CallSessionState.Active -> Text("Status: Call Active (${callState.durationSeconds}s)")
                    is CallSessionState.Ended -> Text("Status: Call Ended [Reason: ${callState.reason}]")
                }
            }
        }

        if (callState is CallSessionState.RemoteRinging || callState is CallSessionState.Active) {
            val activeCallId = if (callState is CallSessionState.RemoteRinging) callState.callId else (callState as CallSessionState.Active).callId
            Button(
                onClick = { onEndCall(activeCallId) },
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                modifier = Modifier.fillMaxWidth().height(56.dp)
            ) {
                Icon(Icons.Default.CallEnd, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("End / Cancel Call")
            }
        } else {
            Button(
                onClick = { onStartCall(recipientHandle) },
                modifier = Modifier.fillMaxWidth().height(56.dp),
                enabled = recipientHandle.isNotBlank()
            ) {
                Icon(Icons.Default.Call, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Start FaceTime Call")
            }
        }
    }
}
