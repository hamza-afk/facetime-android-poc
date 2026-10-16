package org.facetime.poc.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.facetime.model.IdsState

@Composable
fun HardGoNoGoBanner(blocker: IdsState.HardHardwareBlocker) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Default.Warning, contentDescription = null, tint = MaterialTheme.colorScheme.error)
                Text(
                    "HARD GO/NO-GO GATE TRIGGERED",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.error
                )
            }
            Text(
                "Apple services rejected standalone clean-room device validation during stage: ${blocker.stage}.",
                style = MaterialTheme.typography.bodyMedium
            )
            Text("HTTP Status: ${blocker.httpStatus} | Apple Status: ${blocker.appleStatusCode}")
            Text("Hardware Barrier: ${blocker.barrierType.name}", style = MaterialTheme.typography.labelLarge)
            Text("Server Payload: ${blocker.serverError}")
            HorizontalDivider()
            Text(
                "Per Rule R2, development is halted. See: ${blocker.reportPath}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onErrorContainer
            )
        }
    }
}
