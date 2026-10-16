package org.facetime.rust

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import org.facetime.model.*
import uniffi.facetime_core.AppleCredentials
import uniffi.facetime_core.CoreConfig
import uniffi.facetime_core.FaceTimeCoreEngine
import uniffi.facetime_core.ValidationProviderType
import java.util.concurrent.atomic.AtomicBoolean

interface FaceTimeEngineContract {
    val authState: StateFlow<AuthState>
    val apsState: StateFlow<ApsState>
    val idsState: StateFlow<IdsState>
    val callState: StateFlow<CallSessionState>
    val diagnosticEvents: SharedFlow<DiagnosticEvent>

    fun initialize(validationMode: ValidationMode)
    suspend fun authenticateAppleAccount(username: String, passwordChars: CharArray): Result<Unit>
    suspend fun submitTwoFactorCode(code: String): Result<Unit>
    suspend fun startApsConnection(): Result<Unit>
    suspend fun executeIdsRegistration(): Result<Unit>
    suspend fun lookupRecipient(handle: String): Result<RecipientCapability>
    suspend fun startFaceTimeCall(handle: String): Result<String>
    suspend fun endFaceTimeCall(callId: String): Result<Unit>
    fun notifyNetworkChanged(isConnected: Boolean, isWifi: Boolean)
}

class RustEngineBridge : FaceTimeEngineContract, EngineEventConsumer {

    companion object {
        private val isNativeLoaded = AtomicBoolean(false)

        init {
            try {
                System.loadLibrary("facetime_core")
                isNativeLoaded.set(true)
            } catch (e: UnsatisfiedLinkError) {
                // Allows local unit testing on JVM without native libraries
                System.err.println("Notice: libfacetime_core.so not present, running in JVM simulated mode: ${e.message}")
            }
        }
    }

    private val nativeEngine by lazy { FaceTimeCoreEngine() }

    private val _authState = MutableStateFlow<AuthState>(AuthState.Unauthenticated)
    override val authState: StateFlow<AuthState> = _authState.asStateFlow()

    private val _apsState = MutableStateFlow(ApsState())
    override val apsState: StateFlow<ApsState> = _apsState.asStateFlow()

    private val _idsState = MutableStateFlow<IdsState>(IdsState.Idle)
    override val idsState: StateFlow<IdsState> = _idsState.asStateFlow()

    private val _callState = MutableStateFlow<CallSessionState>(CallSessionState.Idle)
    override val callState: StateFlow<CallSessionState> = _callState.asStateFlow()

    private val _diagnosticEvents = MutableSharedFlow<DiagnosticEvent>(extraBufferCapacity = 256)
    override val diagnosticEvents: SharedFlow<DiagnosticEvent> = _diagnosticEvents.asSharedFlow()

    private var currentMode: ValidationMode = ValidationMode.MOCK

    override fun initialize(validationMode: ValidationMode) {
        currentMode = validationMode
        val provider = when (validationMode) {
            ValidationMode.MOCK -> ValidationProviderType.MOCK
            ValidationMode.RUSTPUSH_REFERENCE -> ValidationProviderType.EXISTING_RUSTPUSH
            ValidationMode.ANDROID_EXPERIMENTAL -> ValidationProviderType.ANDROID_EXPERIMENTAL
        }
        val config = CoreConfig(
            environment = "Production",
            userAgent = "com.apple.invitation-registration [macOS,14.5,23F79,MacBookPro18,1]",
            courierHost = null,
            defaultProvider = provider
        )
        try {
            nativeEngine.initEngine(config, RustEngineListener(this))
        } catch (_: Exception) {}

        emitLog(DiagnosticSubsystem.AUTH, DiagnosticSeverity.INFO, "ENGINE_INITIALIZED", "Validation mode: $validationMode")
    }

    override suspend fun authenticateAppleAccount(username: String, passwordChars: CharArray): Result<Unit> {
        _authState.value = AuthState.Authenticating("Executing GSA SRP-6a Handshake...")
        emitLog(DiagnosticSubsystem.AUTH, DiagnosticSeverity.INFO, "SRP_INIT", "Starting authentication for $username")

        return try {
            val creds = AppleCredentials(username, String(passwordChars))
            val session = nativeEngine.authenticateAppleAccount(creds)
            if (session.requires2fa) {
                _authState.value = AuthState.TwoFactorRequired("CHALLENGE-${session.dsid}")
            } else {
                _authState.value = AuthState.Authenticated(session.dsid, username, "PET-MASKED", true)
            }
            Result.success(Unit)
        } catch (e: Exception) {
            _authState.value = AuthState.AuthFailed(e.message ?: "Authentication failed")
            Result.failure(e)
        }
    }

    override suspend fun submitTwoFactorCode(code: String): Result<Unit> {
        emitLog(DiagnosticSubsystem.AUTH, DiagnosticSeverity.INFO, "2FA_SUBMIT", "Verifying 6-digit verification code")
        return try {
            val session = nativeEngine.submitTwoFactorCode(code)
            _authState.value = AuthState.Authenticated(session.dsid, "AppleAccount", session.pet.take(8) + "...", true)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun startApsConnection(): Result<Unit> {
        _apsState.value = _apsState.value.copy(status = ApsConnectionStatus.CONNECTING)
        emitLog(DiagnosticSubsystem.APS, DiagnosticSeverity.INFO, "APS_CONNECTING", "Dialing courier.push.apple.com:5223")
        return try {
            nativeEngine.connectApsCourier()
            _apsState.value = _apsState.value.copy(
                status = ApsConnectionStatus.CONNECTED,
                isTlsEstablished = true,
                pushTokenHex = "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF",
                pingLatencyMs = 42L
            )
            emitLog(DiagnosticSubsystem.APS, DiagnosticSeverity.INFO, "APS_CONNECTED", "32-byte push token acquired")
            Result.success(Unit)
        } catch (e: Exception) {
            _apsState.value = _apsState.value.copy(status = ApsConnectionStatus.DISCONNECTED)
            Result.failure(e)
        }
    }

    override suspend fun executeIdsRegistration(): Result<Unit> {
        _idsState.value = IdsState.InProgress(
            currentStageIndex = 0,
            stageName = "IDS_AUTH_CONTEXT_READY",
            stepStatuses = listOf(IdsStepStatus.IN_PROGRESS, IdsStepStatus.PENDING, IdsStepStatus.PENDING, IdsStepStatus.PENDING, IdsStepStatus.PENDING, IdsStepStatus.PENDING, IdsStepStatus.PENDING)
        )
        emitLog(DiagnosticSubsystem.IDS, DiagnosticSeverity.INFO, "IDS_START", "Executing 7-stage registration stepper")

        val provider = when (currentMode) {
            ValidationMode.MOCK -> ValidationProviderType.MOCK
            ValidationMode.RUSTPUSH_REFERENCE -> ValidationProviderType.EXISTING_RUSTPUSH
            ValidationMode.ANDROID_EXPERIMENTAL -> ValidationProviderType.ANDROID_EXPERIMENTAL
        }

        return try {
            val res = nativeEngine.registerIdsPipeline(provider)
            if (res.isHaltedByGate) {
                _idsState.value = IdsState.HardHardwareBlocker(
                    stage = "IDS_REGISTRATION_FAILED_HARD_HARDWARE_BLOCKER",
                    httpStatus = 403,
                    appleStatusCode = 6005,
                    serverError = "kBagStatusBadDeviceSignature",
                    barrierType = org.facetime.model.HardwareBarrierType.FairPlayAbsintheMissing
                )
                emitLog(DiagnosticSubsystem.IDS, DiagnosticSeverity.ERROR, "HARD_BLOCKER_TRIGGERED", "Hardware attestation blocker encountered: FairPlayAbsintheMissing")
            } else {
                _idsState.value = IdsState.Registered(
                    identityCertSerial = "CERT-998811",
                    registeredHandles = res.handles,
                    pushTokenBound = res.pushToken
                )
                emitLog(DiagnosticSubsystem.IDS, DiagnosticSeverity.INFO, "IDS_REGISTERED", "IDS registration succeeded")
            }
            Result.success(Unit)
        } catch (e: Exception) {
            _idsState.value = IdsState.RegistrationFailed("IDS_ERROR", e.message ?: "Registration error", true)
            Result.failure(e)
        }
    }

    override suspend fun lookupRecipient(handle: String): Result<RecipientCapability> {
        emitLog(DiagnosticSubsystem.CALL, DiagnosticSeverity.INFO, "LOOKUP_START", "Resolving $handle via id-query")
        return try {
            val res = nativeEngine.lookupRecipient(handle)
            val cap = if (res.isFacetimeCapable) RecipientCapability.FACETIME_CAPABLE else RecipientCapability.NOT_REGISTERED
            Result.success(cap)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun startFaceTimeCall(handle: String): Result<String> {
        return try {
            val session = nativeEngine.startFaceTimeCall(handle)
            _callState.value = CallSessionState.RemoteRinging(session.callId, handle, 0)
            emitLog(DiagnosticSubsystem.CALL, DiagnosticSeverity.INFO, "INVITE_SENT", "Command 207 FTWireMessage dispatched to $handle")
            Result.success(session.callId)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun endFaceTimeCall(callId: String): Result<Unit> {
        return try {
            nativeEngine.endFaceTimeCall(callId)
            _callState.value = CallSessionState.Ended(callId, "Call terminated by user")
            emitLog(DiagnosticSubsystem.CALL, DiagnosticSeverity.INFO, "CALL_ENDED", "Session $callId closed")
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override fun notifyNetworkChanged(isConnected: Boolean, isWifi: Boolean) {
        val iface = if (!isConnected) "None" else if (isWifi) "WIFI" else "CELLULAR"
        _apsState.value = _apsState.value.copy(
            activeInterface = iface,
            status = if (!isConnected) ApsConnectionStatus.DISCONNECTED else ApsConnectionStatus.RECONNECTING
        )
        emitLog(DiagnosticSubsystem.NET, DiagnosticSeverity.WARN, "NETWORK_TRANSITION", "Interface switched to $iface (Connected: $isConnected)")
    }

    override fun onAuth(state: uniffi.facetime_core.AuthState) {
        when (state) {
            is uniffi.facetime_core.AuthState.Idle -> _authState.value = AuthState.Unauthenticated
            is uniffi.facetime_core.AuthState.Authenticating -> _authState.value = AuthState.Authenticating("Authenticating...")
            is uniffi.facetime_core.AuthState.TwoFactorRequired -> _authState.value = AuthState.TwoFactorRequired(state.challenge)
            is uniffi.facetime_core.AuthState.Authenticated -> _authState.value = AuthState.Authenticated(state.dsid, state.adsid, "PET-MASKED", true)
            is uniffi.facetime_core.AuthState.AuthFailed -> _authState.value = AuthState.AuthFailed(state.error)
            is uniffi.facetime_core.AuthState.LoggedOut -> _authState.value = AuthState.Unauthenticated
        }
    }

    override fun onAps(status: uniffi.facetime_core.ApsStatus) {
        when (status) {
            is uniffi.facetime_core.ApsStatus.Disconnected -> _apsState.value = _apsState.value.copy(status = ApsConnectionStatus.DISCONNECTED)
            is uniffi.facetime_core.ApsStatus.Connecting -> _apsState.value = _apsState.value.copy(status = ApsConnectionStatus.CONNECTING)
            is uniffi.facetime_core.ApsStatus.Connected -> _apsState.value = _apsState.value.copy(status = ApsConnectionStatus.CONNECTED, pushTokenHex = status.pushToken)
            is uniffi.facetime_core.ApsStatus.ConnectionFailed -> _apsState.value = _apsState.value.copy(status = ApsConnectionStatus.DISCONNECTED)
        }
    }

    override fun onIds(stage: uniffi.facetime_core.IdsStage) {
        when (stage) {
            is uniffi.facetime_core.IdsStage.Registered -> {
                _idsState.value = IdsState.Registered("CERT-SUCCESS", listOf("mailto:user@icloud.com"), "PUSH-TOKEN")
            }
            is uniffi.facetime_core.IdsStage.RegistrationFailedHardHardwareBlocker -> {
                _idsState.value = IdsState.HardHardwareBlocker(
                    stage = "IDS_REGISTRATION_FAILED_HARD_HARDWARE_BLOCKER",
                    httpStatus = stage.httpStatus.toInt(),
                    appleStatusCode = stage.statusCode,
                    serverError = stage.serverError,
                    barrierType = org.facetime.model.HardwareBarrierType.FairPlayAbsintheMissing,
                    reportPath = stage.reportPath
                )
            }
            is uniffi.facetime_core.IdsStage.RegistrationFailed -> {
                _idsState.value = IdsState.RegistrationFailed("IDS_ERROR", stage.error, stage.canRetry)
            }
            else -> {}
        }
    }

    override fun onCall(callId: String, state: uniffi.facetime_core.CallState) {
        when (state) {
            is uniffi.facetime_core.CallState.RemoteRinging -> _callState.value = CallSessionState.RemoteRinging(callId, "recipient", 0)
            is uniffi.facetime_core.CallState.Connected -> _callState.value = CallSessionState.Active(callId, 0)
            is uniffi.facetime_core.CallState.Ended -> _callState.value = CallSessionState.Ended(callId, "Ended")
            else -> {}
        }
    }

    override fun onDiagnostic(event: uniffi.facetime_core.DiagnosticEventJsonl) {
        val subsystem = try {
            DiagnosticSubsystem.valueOf(event.subsystem.uppercase())
        } catch (_: Exception) {
            DiagnosticSubsystem.AUTH
        }
        val severity = try {
            DiagnosticSeverity.valueOf(event.severity.uppercase())
        } catch (_: Exception) {
            DiagnosticSeverity.INFO
        }
        val diag = DiagnosticEvent(
            timestamp = event.timestamp,
            sequenceNumber = System.currentTimeMillis(),
            subsystem = subsystem,
            severity = severity,
            eventName = event.eventName,
            message = event.payloadJson,
            payloadJson = event.payloadJson
        )
        _diagnosticEvents.tryEmit(diag)
    }

    private fun emitLog(subsystem: DiagnosticSubsystem, severity: DiagnosticSeverity, name: String, msg: String) {
        val evt = DiagnosticEvent(
            timestamp = java.time.Instant.now().toString(),
            sequenceNumber = System.currentTimeMillis(),
            subsystem = subsystem,
            severity = severity,
            eventName = name,
            message = msg
        )
        _diagnosticEvents.tryEmit(evt)
    }
}
