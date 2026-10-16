package org.facetime.diagnostic

import kotlinx.serialization.Serializable

@Serializable
enum class DiagnosticSubsystem {
    AUTH,
    APS,
    IDS,
    FACETIME,
    VALIDATION,
    SYSTEM,
    NETWORK,
    SECURITY
}
