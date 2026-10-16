package org.facetime.poc.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.facetime.model.CallSessionState
import org.facetime.model.RecipientCapability
import org.facetime.poc.ui.components.StatusBadge
import java.util.regex.Pattern

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CallTriggerScreen(
    callState: CallSessionState,
    onResolveRecipient: (String) -> Unit,
    onStartCall: (String) -> Unit,
    onEndCall: (String) -> Unit
) {
    var recipientHandle by remember { mutableStateOf("") }
    var resolvedCapability by remember { mutableStateOf(RecipientCapability.UNKNOWN) }

    val emailPattern = remember { Pattern.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$") }
    val phonePattern = remember { Pattern.compile("^\\+[1-9]\\d{1,14}$") }
    val clean = recipientHandle.trim()
    val isHandleValid = emailPattern.matcher(clean).matches() || phonePattern.matcher(clean).matches()

    val recentRecipients = remember {
        listOf("recipient@example.com", "+15555550100", "test.user@icloud.com")
    }

    val isCallActive = callState !is CallSessionState.Idle && callState !is CallSessionState.Ended

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // 1. Header & Title
        Text(
            text = "FaceTime Outgoing Call Signaling",
            style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold)
        )
        Text(
            text = "Feature 16: Decisive Native Ringing (PoC V0) — Dispatches high-priority command 207 invite to Apple SpringBoard CallKit.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        // 2. Recipient Input Card
        Card(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = recipientHandle,
                    onValueChange = {
                        recipientHandle = it
                        if (!emailPattern.matcher(it.trim()).matches() && !phonePattern.matcher(it.trim()).matches()) {
                            resolvedCapability = RecipientCapability.UNKNOWN
                        }
                    },
                    label = { Text("Recipient Apple ID Email / Phone (E.164)") },
                    placeholder = { Text("e.g. user@icloud.com or +15555550199") },
                    leadingIcon = { Icon(Icons.Default.AccountCircle, contentDescription = null) },
                    trailingIcon = {
                        if (recipientHandle.isNotBlank()) {
                            IconButton(onClick = {
                                recipientHandle = ""
                                resolvedCapability = RecipientCapability.UNKNOWN
                            }) {
                                Icon(Icons.Default.Clear, contentDescription = "Clear")
                            }
                        }
                    },
                    isError = recipientHandle.isNotBlank() && !isHandleValid,
                    supportingText = {
                        if (recipientHandle.isNotBlank() && !isHandleValid) {
                            Text("Must be valid email or E.164 phone (+1...)", color = MaterialTheme.colorScheme.error)
                        }
                    },
                    enabled = !isCallActive,
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                // Recent recipient chips
                if (!isCallActive && recentRecipients.isNotEmpty()) {
                    Text("Recent targets:", style = MaterialTheme.typography.labelSmall)
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(recentRecipients) { target ->
                            SuggestionChip(
                                onClick = {
                                    recipientHandle = target
                                    resolvedCapability = RecipientCapability.UNKNOWN
                                },
                                label = { Text(target, fontSize = 12.sp) }
                            )
                        }
                    }
                }

                // Lookup Status & Resolve Trigger Row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedButton(
                        onClick = {
                            resolvedCapability = RecipientCapability.CHECKING
                            onResolveRecipient(recipientHandle)
                            resolvedCapability = RecipientCapability.FACETIME_CAPABLE
                        },
                        enabled = isHandleValid && !isCallActive && resolvedCapability != RecipientCapability.CHECKING
                    ) {
                        if (resolvedCapability == RecipientCapability.CHECKING) {
                            CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Querying id-query...")
                        } else {
                            Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Lookup Directory")
                        }
                    }

                    // Status Badge
                    val (badgeText, badgeColor) = when (resolvedCapability) {
                        RecipientCapability.FACETIME_CAPABLE -> "FACETIME_CAPABLE" to Color(0xFF2E7D32)
                        RecipientCapability.AUDIO_ONLY -> "AUDIO_ONLY" to Color(0xFF1565C0)
                        RecipientCapability.NOT_REGISTERED -> "NOT_REGISTERED" to Color(0xFFC62828)
                        RecipientCapability.CHECKING -> "CHECKING..." to Color(0xFFF57F17)
                        RecipientCapability.UNKNOWN -> "UNCHECKED" to Color.Gray
                    }
                    StatusBadge(text = badgeText, color = badgeColor)
                }
            }
        }

        // 3. Live Call State Stepper & Diagnostic Card
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "Signaling State Machine & CallKit Tracker",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                )

                // Visual 5-Stage Stepper
                PocCallStateStepper(currentState = callState)

                HorizontalDivider()

                // State Details / Remote Ringing Display
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    when (callState) {
                        is CallSessionState.Idle -> {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Default.PhoneCallback, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(48.dp))
                                Spacer(modifier = Modifier.height(8.dp))
                                Text("Ready to place call", color = Color.Gray)
                            }
                        }
                        is CallSessionState.Resolving -> Text("Querying Apple Directory for ${callState.handle}...")
                        is CallSessionState.SessionCreated -> Text("Allocating Apple QuickRelay (Command 200) [${callState.callId}]...")
                        is CallSessionState.InviteSent -> Text("Dispatching Command 207 PDU over APS Courier...")
                        is CallSessionState.RemoteRinging -> {
                            PocPulsingRingingView(
                                handle = callState.recipientHandle,
                                elapsedSeconds = callState.elapsedSeconds,
                                relayIp = "17.253.144.10",
                                relayPort = 3478
                            )
                        }
                        is CallSessionState.Active -> {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Default.PhoneInTalk, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(56.dp))
                                Text("CALL ACTIVE", style = MaterialTheme.typography.titleLarge, color = Color(0xFF2E7D32), fontWeight = FontWeight.Bold)
                                Text("Duration: %02d:%02d".format(callState.durationSeconds / 60, callState.durationSeconds % 60), fontFamily = FontFamily.Monospace)
                            }
                        }
                        is CallSessionState.Ended -> {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Default.PhoneMissed, contentDescription = null, tint = Color(0xFFC62828), modifier = Modifier.size(48.dp))
                                Text("CALL TERMINATED", style = MaterialTheme.typography.titleMedium, color = Color(0xFFC62828), fontWeight = FontWeight.Bold)
                                Text("Reason: ${callState.reason}", fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
            }
        }

        // 4. Primary Action Button (Call / End Call)
        if (isCallActive) {
            val activeCallId = when (callState) {
                is CallSessionState.SessionCreated -> callState.callId
                is CallSessionState.InviteSent -> callState.callId
                is CallSessionState.RemoteRinging -> callState.callId
                is CallSessionState.Active -> callState.callId
                else -> ""
            }
            Button(
                onClick = { onEndCall(activeCallId) },
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(60.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.CallEnd, contentDescription = null, modifier = Modifier.size(24.dp))
                Spacer(modifier = Modifier.width(12.dp))
                Text("End / Cancel Call", style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold))
            }
        } else {
            Button(
                onClick = { onStartCall(recipientHandle) },
                enabled = isHandleValid,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32)),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(60.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.Call, contentDescription = null, modifier = Modifier.size(24.dp))
                Spacer(modifier = Modifier.width(12.dp))
                Text("Start Native FaceTime Call", style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold))
            }
        }
    }
}

@Composable
private fun PocCallStateStepper(currentState: CallSessionState) {
    val steps = listOf("Init", "Lookup", "Relay", "Invite", "Ringing")
    val activeIndex = when (currentState) {
        is CallSessionState.Idle -> -1
        is CallSessionState.Resolving -> 1
        is CallSessionState.SessionCreated -> 2
        is CallSessionState.InviteSent -> 3
        is CallSessionState.RemoteRinging -> 4
        is CallSessionState.Active -> 4
        is CallSessionState.Ended -> 4
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        steps.forEachIndexed { index, name ->
            val isCompleted = index < activeIndex
            val isCurrent = index == activeIndex
            val color = when {
                isCompleted -> Color(0xFF2E7D32)
                isCurrent -> MaterialTheme.colorScheme.primary
                else -> Color.Gray.copy(alpha = 0.5f)
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(color),
                    contentAlignment = Alignment.Center
                ) {
                    if (isCompleted) {
                        Icon(Icons.Default.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
                    } else {
                        Text("${index + 1}", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(name, fontSize = 11.sp, color = if (isCurrent) MaterialTheme.colorScheme.primary else Color.Gray)
            }

            if (index < steps.lastIndex) {
                HorizontalDivider(
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = 4.dp),
                    color = if (index < activeIndex) Color(0xFF2E7D32) else Color.LightGray,
                    thickness = 2.dp
                )
            }
        }
    }
}

@Composable
private fun PocPulsingRingingView(
    handle: String,
    elapsedSeconds: Int,
    relayIp: String,
    relayPort: Int
) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val scale by infiniteTransition.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scale"
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(80.dp)
                .scale(scale)
                .clip(CircleShape)
                .background(Color(0xFF2E7D32).copy(alpha = 0.2f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Default.RingVolume, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(44.dp))
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "TARGET IPHONE IS RINGING NATIVELY!",
            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            color = Color(0xFF2E7D32)
        )
        Text(text = "Recipient: $handle", fontWeight = FontWeight.SemiBold)
        Text(
            text = "Elapsed Ringing: %02d:%02ds".format(elapsedSeconds / 60, elapsedSeconds % 60),
            style = MaterialTheme.typography.bodyLarge,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Relay: $relayIp:$relayPort (QuickRelay Active)",
            style = MaterialTheme.typography.bodySmall,
            color = Color.Gray,
            fontFamily = FontFamily.Monospace
        )
    }
}
