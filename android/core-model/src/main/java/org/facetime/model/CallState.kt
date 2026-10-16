package org.facetime.model

import kotlinx.serialization.Serializable

@Serializable
enum class RecipientCapability {
    UNKNOWN,
    CHECKING,
    FACETIME_CAPABLE,
    AUDIO_ONLY,
    NOT_REGISTERED
}

@Serializable
sealed class CallSessionState {
    @Serializable
    data object Idle : CallSessionState()

    @Serializable
    data class Resolving(val handle: String) : CallSessionState()

    @Serializable
    data class SessionCreated(
        val callId: String,
        val recipientHandle: String
    ) : CallSessionState()

    @Serializable
    data class InviteSent(
        val callId: String,
        val recipientHandle: String
    ) : CallSessionState()

    @Serializable
    data class RemoteRinging(
        val callId: String,
        val recipientHandle: String,
        val elapsedSeconds: Int
    ) : CallSessionState()

    @Serializable
    data class Active(
        val callId: String,
        val durationSeconds: Int
    ) : CallSessionState()

    @Serializable
    data class Ended(
        val callId: String,
        val reason: String
    ) : CallSessionState()
}

@Serializable
enum class CallStep {
    IDLE,
    INITIATING,
    LOOKING_UP,
    ALLOCATING_RELAY,
    DISPATCHING_INVITE,
    REMOTE_RINGING,
    CONNECTED,
    TERMINATED
}

@Serializable
enum class CallTerminationReason {
    USER_CANCELLED,
    REMOTE_DECLINED,
    REMOTE_BUSY,
    RINGING_TIMEOUT,
    NETWORK_ERROR,
    RELAY_ALLOCATION_FAILED,
    RECIPIENT_NOT_CAPABLE
}

@Serializable
sealed class GranularCallState {
    @Serializable
    data object Idle : GranularCallState()

    @Serializable
    data class Initiating(val handle: String) : GranularCallState()

    @Serializable
    data class LookingUp(val handle: String) : GranularCallState()

    @Serializable
    data class AllocatingRelay(val callId: String, val handle: String) : GranularCallState()

    @Serializable
    data class DispatchingInvite(val callId: String, val handle: String) : GranularCallState()

    @Serializable
    data class RemoteRinging(
        val callId: String,
        val handle: String,
        val elapsedSeconds: Int,
        val relayIp: String,
        val relayPort: Int
    ) : GranularCallState()

    @Serializable
    data class Connected(
        val callId: String,
        val handle: String,
        val durationSeconds: Int
    ) : GranularCallState()

    @Serializable
    data class Terminated(
        val callId: String,
        val handle: String,
        val reason: CallTerminationReason,
        val detailMessage: String
    ) : GranularCallState()
}
