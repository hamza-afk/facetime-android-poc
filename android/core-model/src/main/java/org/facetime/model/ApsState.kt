package org.facetime.model

import kotlinx.serialization.Serializable

@Serializable
enum class ApsConnectionStatus {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    RECONNECTING
}

@Serializable
data class ApsState(
    val status: ApsConnectionStatus = ApsConnectionStatus.DISCONNECTED,
    val courierHost: String = "5-courier.push.apple.com:5223",
    val pushTokenHex: String? = null,
    val isTlsEstablished: Boolean = false,
    val cipherSuite: String? = null,
    val activeInterface: String = "Unknown",
    val pingLatencyMs: Long? = null,
    val registeredTopics: List<String> = listOf(
        "com.apple.ess",
        "com.apple.private.alloy.facetime",
        "com.apple.madrid"
    ),
    val lastPingTimestamp: Long = 0L
)
