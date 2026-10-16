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
