package uniffi.facetime_core

data class CoreConfig(
    val environment: String,
    val userAgent: String,
    val courierHost: String?,
    val defaultProvider: ValidationProviderType
)

data class AppleCredentials(
    val username: String,
    val password: String
)

data class AuthSession(
    val dsid: String,
    val adsid: String,
    val pet: String,
    val idsAuthToken: String?,
    val idsProfileId: String?,
    val requires2fa: Boolean
)

data class IdsRegistrationResult(
    val stage: IdsStage,
    val isSuccess: Boolean,
    val isHaltedByGate: Boolean,
    val message: String,
    val pushToken: String,
    val handles: List<String>,
    val registeredServices: List<String>
)

data class RecipientCapabilities(
    val handle: String,
    val isFacetimeCapable: Boolean,
    val pushToken: String,
    val sessionToken: String,
    val publicKeyDer: ByteArray,
    val prekeyData: ByteArray
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as RecipientCapabilities
        if (handle != other.handle) return false
        if (isFacetimeCapable != other.isFacetimeCapable) return false
        if (pushToken != other.pushToken) return false
        if (sessionToken != other.sessionToken) return false
        if (!publicKeyDer.contentEquals(other.publicKeyDer)) return false
        if (!prekeyData.contentEquals(other.prekeyData)) return false
        return true
    }

    override fun hashCode(): Int {
        var result = handle.hashCode()
        result = 31 * result + isFacetimeCapable.hashCode()
        result = 31 * result + pushToken.hashCode()
        result = 31 * result + sessionToken.hashCode()
        result = 31 * result + publicKeyDer.contentHashCode()
        result = 31 * result + prekeyData.contentHashCode()
        return result
    }
}

data class CallSession(
    val callId: String,
    val conversationId: String,
    val recipientHandle: String,
    val state: CallState,
    val quickRelayIp: String?,
    val quickRelayPort: UShort?
)

data class DiagnosticEventJsonl(
    val timestamp: String,
    val subsystem: String,
    val severity: String,
    val eventName: String,
    val payloadJson: String
)

enum class ValidationProviderType {
    MOCK,
    EXISTING_RUSTPUSH,
    ANDROID_EXPERIMENTAL
}

enum class HardwareBarrierType {
    FAIR_PLAY_ABSINTHE_MISSING,
    ANISETTE_HMAC_REJECTED,
    ALBERT_ACTIVATION_REJECTED,
    SECURE_ENCLAVE_MISSING
}

sealed class IdsStage {
    data object AuthContextReady : IdsStage()
    data object BagLoaded : IdsStage()
    data object PushTokenAcquired : IdsStage()
    data object IdentitiesGenerated : IdsStage()
    data object ServiceRegistered : IdsStage()
    data object Registered : IdsStage()
    data class RegistrationFailed(val error: String, val canRetry: Boolean) : IdsStage()
    data class RegistrationFailedHardHardwareBlocker(
        val statusCode: Int,
        val httpStatus: UShort,
        val serverError: String,
        val barrierType: HardwareBarrierType,
        val reportPath: String
    ) : IdsStage()
}

sealed class AuthState {
    data object Idle : AuthState()
    data object Authenticating : AuthState()
    data class TwoFactorRequired(val challenge: String) : AuthState()
    data class Authenticated(val dsid: String, val adsid: String) : AuthState()
    data class AuthFailed(val error: String) : AuthState()
    data object LoggedOut : AuthState()
}

sealed class ApsStatus {
    data object Disconnected : ApsStatus()
    data object Connecting : ApsStatus()
    data class Connected(val host: String, val pushToken: String) : ApsStatus()
    data class ConnectionFailed(val error: String) : ApsStatus()
}

sealed class CallState {
    data object Idle : CallState()
    data class Resolving(val handle: String) : CallState()
    data object QuickRelayAllocating : CallState()
    data class InviteSending(val callId: String) : CallState()
    data class RemoteRinging(val callId: String) : CallState()
    data class Connected(val callId: String) : CallState()
    data class Declined(val callId: String, val reason: String) : CallState()
    data class Ended(val callId: String) : CallState()
    data class Failed(val callId: String, val error: String) : CallState()
}

interface FaceTimeCoreEventListener {
    fun onAuthStateChanged(state: AuthState)
    fun onApsStateChanged(status: ApsStatus)
    fun onIdsStateChanged(stage: IdsStage)
    fun onCallStateChanged(callId: String, state: CallState)
    fun onDiagnosticEvent(event: DiagnosticEventJsonl)
}

open class FaceTimeCoreException(message: String) : Exception(message)

class FaceTimeCoreEngine {
    fun initEngine(config: CoreConfig, listener: FaceTimeCoreEventListener) {}
    fun authenticateAppleAccount(credentials: AppleCredentials): AuthSession {
        return AuthSession("1892837492", "W1892837492", "PET-123", null, null, true)
    }
    fun submitTwoFactorCode(code: String): AuthSession {
        return AuthSession("1892837492", "W1892837492", "PET-456", "IDS-TOKEN", "PROFILE-1", false)
    }
    fun connectApsCourier() {}
    fun registerIdsPipeline(provider: ValidationProviderType): IdsRegistrationResult {
        return IdsRegistrationResult(IdsStage.Registered, true, false, "Success", "012345", listOf("mailto:user@icloud.com"), listOf("com.apple.madrid"))
    }
    fun lookupRecipient(handle: String): RecipientCapabilities {
        return RecipientCapabilities(handle, true, "TOKEN", "SESSION", byteArrayOf(), byteArrayOf())
    }
    fun startFaceTimeCall(recipientHandle: String): CallSession {
        return CallSession("CALL-001", "CONV-001", recipientHandle, CallState.RemoteRinging("CALL-001"), "17.253.144.10", 3478u)
    }
    fun endFaceTimeCall(callId: String) {}
}
