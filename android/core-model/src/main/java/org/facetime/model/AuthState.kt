package org.facetime.model

import kotlinx.serialization.Serializable

@Serializable
sealed class AuthState {
    @Serializable
    data object Unauthenticated : AuthState()

    @Serializable
    data class Authenticating(val progressMessage: String) : AuthState()

    @Serializable
    data class TwoFactorRequired(
        val challengeToken: String,
        val deliveryOptions: List<String> = listOf("Trusted Device Notification", "SMS Verification")
    ) : AuthState()

    @Serializable
    data class Authenticated(
        val dsid: String,
        val accountName: String,
        val authTokenMasked: String,
        val isPersistedInKeystore: Boolean
    ) : AuthState()

    @Serializable
    data class AuthFailed(
        val errorMessage: String,
        val errorCode: Int = -1,
        val canRetry: Boolean = true
    ) : AuthState()
}
