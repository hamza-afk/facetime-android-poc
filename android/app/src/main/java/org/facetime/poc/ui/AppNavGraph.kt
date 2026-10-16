package org.facetime.poc.ui

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountTree
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.CloudSync
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.facetime.poc.ui.screens.*

enum class AppScreenTab(val title: String) {
    AUTH("Auth"),
    APS("APS"),
    IDS("IDS"),
    CALL("Call"),
    LOGS("Logs")
}

@Composable
fun AppNavGraph(viewModel: FaceTimeViewModel) {
    var currentTab by remember { mutableStateOf(AppScreenTab.AUTH) }

    val authState by viewModel.authState.collectAsStateWithLifecycle()
    val apsState by viewModel.apsState.collectAsStateWithLifecycle()
    val idsState by viewModel.idsState.collectAsStateWithLifecycle()
    val callState by viewModel.callState.collectAsStateWithLifecycle()
    val events by viewModel.events.collectAsStateWithLifecycle()
    val validationMode by viewModel.validationMode.collectAsStateWithLifecycle()

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = currentTab == AppScreenTab.AUTH,
                    onClick = { currentTab = AppScreenTab.AUTH },
                    icon = { Icon(Icons.Default.Lock, contentDescription = null) },
                    label = { Text("Auth") }
                )
                NavigationBarItem(
                    selected = currentTab == AppScreenTab.APS,
                    onClick = { currentTab = AppScreenTab.APS },
                    icon = { Icon(Icons.Default.CloudSync, contentDescription = null) },
                    label = { Text("APS") }
                )
                NavigationBarItem(
                    selected = currentTab == AppScreenTab.IDS,
                    onClick = { currentTab = AppScreenTab.IDS },
                    icon = { Icon(Icons.Default.AccountTree, contentDescription = null) },
                    label = { Text("IDS") }
                )
                NavigationBarItem(
                    selected = currentTab == AppScreenTab.CALL,
                    onClick = { currentTab = AppScreenTab.CALL },
                    icon = { Icon(Icons.Default.Call, contentDescription = null) },
                    label = { Text("Call") }
                )
                NavigationBarItem(
                    selected = currentTab == AppScreenTab.LOGS,
                    onClick = { currentTab = AppScreenTab.LOGS },
                    icon = { Icon(Icons.Default.Terminal, contentDescription = null) },
                    label = { Text("Logs") }
                )
            }
        }
    ) { innerPadding ->
        Surface(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            when (currentTab) {
                AppScreenTab.AUTH -> AuthScreen(
                    authState = authState,
                    validationMode = validationMode,
                    onValidationModeSelected = { viewModel.setValidationMode(it) },
                    onLoginSubmitted = { u, p -> viewModel.login(u, p) },
                    onTwoFactorSubmitted = { viewModel.submitTwoFactorCode(it) },
                    onLogoutClicked = { viewModel.logout() }
                )
                AppScreenTab.APS -> ApsScreen(
                    apsState = apsState,
                    onForceReconnect = { viewModel.connectAps() },
                    onSendPing = { /* send ping */ },
                    onSimulateInterfaceDrop = { /* simulate drop */ }
                )
                AppScreenTab.IDS -> IdsPipelineScreen(
                    idsState = idsState,
                    onStartRegistrationClicked = { viewModel.executeIdsRegistration() },
                    onResetClicked = { /* reset */ }
                )
                AppScreenTab.CALL -> CallTriggerScreen(
                    callState = callState,
                    onResolveRecipient = { viewModel.lookupRecipient(it) },
                    onStartCall = { viewModel.startCall(it) },
                    onEndCall = { viewModel.endCall(it) }
                )
                AppScreenTab.LOGS -> DiagnosticConsoleSheet(
                    events = events,
                    onClearClicked = { viewModel.clearEvents() },
                    onExportBundleClicked = { /* export bundle */ }
                )
            }
        }
    }
}
