package org.facetime.poc.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import org.facetime.model.*
import org.facetime.rust.FaceTimeEngineContract
import org.facetime.security.KeystoreManager
import org.facetime.security.PasswordZeroizer

class FaceTimeViewModel(
    private val engine: FaceTimeEngineContract,
    private val keystore: KeystoreManager
) : ViewModel() {

    val authState: StateFlow<AuthState> = engine.authState
    val apsState: StateFlow<ApsState> = engine.apsState
    val idsState: StateFlow<IdsState> = engine.idsState
    val callState: StateFlow<CallSessionState> = engine.callState

    private val _events = MutableStateFlow<List<DiagnosticEvent>>(emptyList())
    val events: StateFlow<List<DiagnosticEvent>> = _events.asStateFlow()

    private val _validationMode = MutableStateFlow(ValidationMode.ANDROID_EXPERIMENTAL)
    val validationMode: StateFlow<ValidationMode> = _validationMode.asStateFlow()

    init {
        // Load stored session if present in Keystore
        keystore.getTokens()?.let { _ ->
            // Restored from Keystore
        }

        viewModelScope.launch {
            engine.diagnosticEvents.collect { evt ->
                _events.update { current -> (current + evt).takeLast(2048) }
            }
        }
    }

    fun setValidationMode(mode: ValidationMode) {
        _validationMode.value = mode
        engine.initialize(mode)
    }

    fun login(username: String, passwordChars: CharArray) {
        viewModelScope.launch {
            PasswordZeroizer.useAndWipe(passwordChars) { safeChars ->
                engine.authenticateAppleAccount(username, safeChars)
            }
        }
    }

    fun submitTwoFactorCode(code: String) {
        viewModelScope.launch {
            engine.submitTwoFactorCode(code)
        }
    }

    fun logout() {
        keystore.clearTokens()
    }

    fun connectAps() {
        viewModelScope.launch { engine.startApsConnection() }
    }

    fun executeIdsRegistration() {
        viewModelScope.launch { engine.executeIdsRegistration() }
    }

    fun lookupRecipient(handle: String) {
        viewModelScope.launch { engine.lookupRecipient(handle) }
    }

    fun startCall(handle: String) {
        viewModelScope.launch { engine.startFaceTimeCall(handle) }
    }

    fun endCall(callId: String) {
        viewModelScope.launch { engine.endFaceTimeCall(callId) }
    }

    fun clearEvents() {
        _events.value = emptyList()
    }
}
