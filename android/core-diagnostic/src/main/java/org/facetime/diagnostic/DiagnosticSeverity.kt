package org.facetime.diagnostic

import kotlinx.serialization.Serializable

@Serializable
enum class DiagnosticSeverity {
    VERBOSE,
    DEBUG,
    INFO,
    WARN,
    ERROR
}
