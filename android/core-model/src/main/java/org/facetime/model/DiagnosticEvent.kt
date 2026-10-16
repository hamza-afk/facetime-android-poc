package org.facetime.model

import kotlinx.serialization.Serializable

@Serializable
enum class DiagnosticSeverity {
    VERBOSE,
    DEBUG,
    INFO,
    WARN,
    ERROR
}

@Serializable
enum class DiagnosticSubsystem {
    AUTH,
    APS,
    IDS,
    CALL,
    NET,
    SECURITY,
    VALIDATION
}

@Serializable
data class DiagnosticEvent(
    val timestamp: String,
    val sequenceNumber: Long,
    val subsystem: DiagnosticSubsystem,
    val severity: DiagnosticSeverity,
    val eventName: String,
    val message: String,
    val payloadJson: String = "{}"
)
