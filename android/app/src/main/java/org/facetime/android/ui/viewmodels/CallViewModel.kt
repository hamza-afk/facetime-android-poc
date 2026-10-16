package org.facetime.android.ui.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import org.facetime.model.*
import org.facetime.rust.FaceTimeEngineContract
import java.util.regex.Pattern

class CallViewModel(
    private val engine: FaceTimeEngineContract
) : ViewModel() {

    // Regex for Apple ID Email and E.164 International Phone Numbers
    private val emailPattern = Pattern.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
    private val phonePattern = Pattern.compile("^\\+[1-9]\\d{1,14}$")

    private val _recipientHandle = MutableStateFlow("")
    val recipientHandle: StateFlow<String> = _recipientHandle.asStateFlow()

    private val _isHandleValid = MutableStateFlow(false)
    val isHandleValid: StateFlow<Boolean> = _isHandleValid.asStateFlow()

    private val _lookupState = MutableStateFlow(RecipientCapability.UNKNOWN)
    val lookupState: StateFlow<RecipientCapability> = _lookupState.asStateFlow()

    private val _callState = MutableStateFlow<GranularCallState>(GranularCallState.Idle)
    val callState: StateFlow<GranularCallState> = _callState.asStateFlow()

    private val _recentRecipients = MutableStateFlow<List<String>>(
        listOf("recipient@example.com", "+15555550100", "test.user@icloud.com")
    )
    val recentRecipients: StateFlow<List<String>> = _recentRecipients.asStateFlow()

    private var ringingJob: Job? = null
    private var callDurationJob: Job? = null

    init {
        // Collect engine state transitions
        viewModelScope.launch {
            engine.callState.collect { coreState ->
                when (coreState) {
                    is CallSessionState.Idle -> {
                        stopTimers()
                        _callState.value = GranularCallState.Idle
                    }
                    is CallSessionState.Resolving -> {
                        _callState.value = GranularCallState.LookingUp(coreState.handle)
                    }
                    is CallSessionState.SessionCreated -> {
                        _callState.value = GranularCallState.AllocatingRelay(coreState.callId, coreState.recipientHandle)
                    }
                    is CallSessionState.InviteSent -> {
                        _callState.value = GranularCallState.DispatchingInvite(coreState.callId, coreState.recipientHandle)
                    }
                    is CallSessionState.RemoteRinging -> {
                        startRingingTimer(coreState.callId, coreState.recipientHandle)
                    }
                    is CallSessionState.Active -> {
                        startActiveDurationTimer(coreState.callId, _recipientHandle.value)
                    }
                    is CallSessionState.Ended -> {
                        stopTimers()
                        _callState.value = GranularCallState.Terminated(
                            callId = coreState.callId,
                            handle = _recipientHandle.value,
                            reason = CallTerminationReason.USER_CANCELLED,
                            detailMessage = coreState.reason
                        )
                    }
                }
            }
        }
    }

    fun onHandleChanged(newHandle: String) {
        val clean = newHandle.trim()
        _recipientHandle.value = clean
        val valid = emailPattern.matcher(clean).matches() || phonePattern.matcher(clean).matches()
        _isHandleValid.value = valid
        if (!valid) {
            _lookupState.value = RecipientCapability.UNKNOWN
        }
    }

    fun resolveRecipient() {
        val handle = _recipientHandle.value
        if (!_isHandleValid.value || handle.isBlank()) return

        viewModelScope.launch {
            _lookupState.value = RecipientCapability.CHECKING
            val result = engine.lookupRecipient(handle)
            result.onSuccess { cap ->
                _lookupState.value = cap
            }.onFailure {
                _lookupState.value = RecipientCapability.NOT_REGISTERED
            }
        }
    }

    fun startCall() {
        val handle = _recipientHandle.value
        if (!_isHandleValid.value) return

        viewModelScope.launch {
            // Auto-resolve if unchecked
            if (_lookupState.value == RecipientCapability.UNKNOWN) {
                _lookupState.value = RecipientCapability.CHECKING
                val lookup = engine.lookupRecipient(handle).getOrNull()
                _lookupState.value = lookup ?: RecipientCapability.NOT_REGISTERED
                if (lookup != RecipientCapability.FACETIME_CAPABLE) {
                    _callState.value = GranularCallState.Terminated(
                        callId = "",
                        handle = handle,
                        reason = CallTerminationReason.RECIPIENT_NOT_CAPABLE,
                        detailMessage = "Recipient is not registered for FaceTime"
                    )
                    return@launch
                }
            }

            _callState.value = GranularCallState.Initiating(handle)
            delay(150) // Allow UI transition to render

            val res = engine.startFaceTimeCall(handle)
            res.onFailure { err ->
                _callState.value = GranularCallState.Terminated(
                    callId = "",
                    handle = handle,
                    reason = CallTerminationReason.NETWORK_ERROR,
                    detailMessage = err.message ?: "Signaling invite failed"
                )
            }
        }
    }

    fun endCall() {
        val current = _callState.value
        stopTimers()
        viewModelScope.launch {
            when (current) {
                is GranularCallState.RemoteRinging -> engine.endFaceTimeCall(current.callId)
                is GranularCallState.Connected -> engine.endFaceTimeCall(current.callId)
                is GranularCallState.Initiating,
                is GranularCallState.LookingUp,
                is GranularCallState.AllocatingRelay,
                is GranularCallState.DispatchingInvite -> {
                    _callState.value = GranularCallState.Idle
                }
                else -> {}
            }
            _callState.value = GranularCallState.Idle
        }
    }

    private fun startRingingTimer(callId: String, handle: String) {
        stopTimers()
        ringingJob = viewModelScope.launch {
            var elapsed = 0
            while (true) {
                _callState.value = GranularCallState.RemoteRinging(
                    callId = callId,
                    handle = handle,
                    elapsedSeconds = elapsed,
                    relayIp = "17.253.144.10",
                    relayPort = 3478
                )
                delay(1000)
                elapsed++
                if (elapsed >= 35) { // 35s timeout
                    _callState.value = GranularCallState.Terminated(
                        callId = callId,
                        handle = handle,
                        reason = CallTerminationReason.RINGING_TIMEOUT,
                        detailMessage = "Recipient did not answer within 35 seconds"
                    )
                    engine.endFaceTimeCall(callId)
                    break
                }
            }
        }
    }

    private fun startActiveDurationTimer(callId: String, handle: String) {
        stopTimers()
        callDurationJob = viewModelScope.launch {
            var duration = 0
            while (true) {
                _callState.value = GranularCallState.Connected(callId, handle, duration)
                delay(1000)
                duration++
            }
        }
    }

    private fun stopTimers() {
        ringingJob?.cancel()
        ringingJob = null
        callDurationJob?.cancel()
        callDurationJob = null
    }

    override fun onCleared() {
        super.onCleared()
        stopTimers()
    }
}
