package org.facetime.poc.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import org.facetime.model.AuthState
import org.facetime.model.ValidationMode
import org.facetime.poc.ui.components.TwoFactorDialog

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AuthScreen(
    authState: AuthState,
    validationMode: ValidationMode,
    onValidationModeSelected: (ValidationMode) -> Unit,
    onLoginSubmitted: (String, CharArray) -> Unit,
    onTwoFactorSubmitted: (String) -> Unit,
    onLogoutClicked: () -> Unit
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isPasswordVisible by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("Apple Account Authentication", style = MaterialTheme.typography.headlineMedium)

        // Validation Mode Picker Card
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text("Device Validation Mode", style = MaterialTheme.typography.titleMedium)
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    ValidationMode.entries.forEach { mode ->
                        FilterChip(
                            selected = validationMode == mode,
                            onClick = { onValidationModeSelected(mode) },
                            label = { Text(mode.name) }
                        )
                    }
                }
            }
        }

        when (authState) {
            is AuthState.Authenticated -> {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Active Session", style = MaterialTheme.typography.titleLarge)
                        Text("Apple ID: ${authState.accountName}")
                        Text("DSID: ${authState.dsid}")
                        Text("Session Token: ${authState.authTokenMasked}")
                        Text("Hardware Keystore: AES-256-GCM Encrypted", color = MaterialTheme.colorScheme.primary)

                        Button(
                            onClick = onLogoutClicked,
                            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                        ) {
                            Text("Revoke Session & Purge Keystore")
                        }
                    }
                }
            }
            else -> {
                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("Apple Account Email") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Password") },
                    visualTransformation = if (isPasswordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                    trailingIcon = {
                        IconButton(onClick = { isPasswordVisible = !isPasswordVisible }) {
                            Icon(
                                if (isPasswordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                contentDescription = null
                            )
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                )

                Button(
                    onClick = {
                        val chars = password.toCharArray()
                        onLoginSubmitted(email, chars)
                        password = "" // wipe in composable state immediately
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = email.isNotBlank() && password.isNotBlank() && authState !is AuthState.Authenticating
                ) {
                    if (authState is AuthState.Authenticating) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(authState.progressMessage)
                    } else {
                        Text("Sign In via SRP-6a")
                    }
                }

                if (authState is AuthState.AuthFailed) {
                    Text(
                        text = "Authentication Failed: ${authState.errorMessage}",
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }

        if (authState is AuthState.TwoFactorRequired) {
            TwoFactorDialog(
                onDismiss = {},
                onSubmitCode = onTwoFactorSubmitted
            )
        }
    }
}
