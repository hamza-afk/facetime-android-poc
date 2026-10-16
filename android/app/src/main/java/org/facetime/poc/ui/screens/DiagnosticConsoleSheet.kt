package org.facetime.poc.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import org.facetime.model.DiagnosticEvent
import org.facetime.model.DiagnosticSeverity
import org.facetime.model.DiagnosticSubsystem
import org.facetime.poc.ui.components.StatusBadge

@Composable
fun DiagnosticConsoleSheet(
    events: List<DiagnosticEvent>,
    onClearClicked: () -> Unit,
    onExportBundleClicked: () -> Unit
) {
    var searchQuery by remember { mutableStateOf("") }
    var selectedSubsystem by remember { mutableStateOf<DiagnosticSubsystem?>(null) }
    var isAutoScrollLocked by remember { mutableStateOf(true) }
    val listState = rememberLazyListState()

    val filteredEvents = remember(events, searchQuery, selectedSubsystem) {
        events.filter { evt ->
            (selectedSubsystem == null || evt.subsystem == selectedSubsystem) &&
                    (searchQuery.isBlank() || (evt.message?.contains(searchQuery, ignoreCase = true) == true) || evt.eventName.contains(searchQuery, ignoreCase = true))
        }
    }

    LaunchedEffect(filteredEvents.size, isAutoScrollLocked) {
        if (isAutoScrollLocked && filteredEvents.isNotEmpty()) {
            listState.animateScrollToItem(filteredEvents.lastIndex)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Diagnostic Event Log (${events.size}/2048)", style = MaterialTheme.typography.titleLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                IconButton(onClick = onClearClicked) {
                    Icon(Icons.Default.Delete, contentDescription = "Clear")
                }
                IconButton(onClick = onExportBundleClicked) {
                    Icon(Icons.Default.Share, contentDescription = "Export Bundle")
                }
            }
        }

        OutlinedTextField(
            value = searchQuery,
            onValueChange = { searchQuery = it },
            placeholder = { Text("Filter logs or regex...") },
            modifier = Modifier.fillMaxWidth()
        )

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            FilterChip(
                selected = selectedSubsystem == null,
                onClick = { selectedSubsystem = null },
                label = { Text("ALL") }
            )
            DiagnosticSubsystem.entries.take(4).forEach { sub ->
                FilterChip(
                    selected = selectedSubsystem == sub,
                    onClick = { selectedSubsystem = sub },
                    label = { Text(sub.name) }
                )
            }
        }

        Card(modifier = Modifier.fillMaxWidth().weight(1f)) {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize().padding(8.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                items(filteredEvents) { evt ->
                    val color = when (evt.severity) {
                        DiagnosticSeverity.ERROR -> Color(0xFFC62828)
                        DiagnosticSeverity.WARN -> Color(0xFFF57F17)
                        DiagnosticSeverity.INFO -> Color(0xFF1565C0)
                        DiagnosticSeverity.DEBUG, DiagnosticSeverity.VERBOSE -> Color.Gray
                    }
                    Column(modifier = Modifier.fillMaxWidth().padding(4.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(evt.timestamp.takeLast(12), style = MaterialTheme.typography.labelSmall)
                            StatusBadge(text = evt.subsystem.name, color = color)
                            Text(evt.eventName, style = MaterialTheme.typography.labelMedium)
                        }
                        Text(evt.message ?: "", style = MaterialTheme.typography.bodySmall)
                    }
                    HorizontalDivider(color = MaterialTheme.colorScheme.surfaceVariant)
                }
            }
        }
    }
}
