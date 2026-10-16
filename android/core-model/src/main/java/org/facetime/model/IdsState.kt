package org.facetime.model

import kotlinx.serialization.Serializable

@Serializable
enum class HardwareBarrierType {
    FairPlayAbsintheMissing,
    AnisetteHmacRejected,
    AlbertActivationRejected,
    SecureEnclaveMissing
}

@Serializable
enum class IdsStepStatus {
    PENDING,
    IN_PROGRESS,
    SUCCESS,
    FAILED
}

@Serializable
sealed class IdsState {
    @Serializable
    data object Idle : IdsState()

    @Serializable
    data class InProgress(
        val currentStageIndex: Int,
        val stageName: String,
        val stepStatuses: List<IdsStepStatus>
    ) : IdsState()

    @Serializable
    data class Registered(
        val identityCertSerial: String,
        val registeredHandles: List<String>,
        val pushTokenBound: String
    ) : IdsState()

    @Serializable
    data class RegistrationFailed(
        val stage: String,
        val errorMessage: String,
        val canRetry: Boolean
    ) : IdsState()

    @Serializable
    data class HardHardwareBlocker(
        val stage: String,
        val httpStatus: Int,
        val appleStatusCode: Int,
        val serverError: String,
        val barrierType: HardwareBarrierType,
        val reportPath: String = "docs/experiments/Standalone_Android_FaceTime_Registration_Blocker.md"
    ) : IdsState()
}
