package org.facetime.model

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class IdsStateTest {

    @Test
    fun testHardHardwareBlockerProperties() {
        val blocker = IdsState.HardHardwareBlocker(
            stage = "IDS_REGISTRATION_FAILED_HARD_HARDWARE_BLOCKER",
            httpStatus = 403,
            appleStatusCode = 6005,
            serverError = "kBagStatusBadDeviceSignature",
            barrierType = HardwareBarrierType.FairPlayAbsintheMissing,
            reportPath = "docs/experiments/Standalone_Android_FaceTime_Registration_Blocker.md"
        )

        assertThat(blocker.httpStatus).isEqualTo(403)
        assertThat(blocker.appleStatusCode).isEqualTo(6005)
        assertThat(blocker.barrierType).isEqualTo(HardwareBarrierType.FairPlayAbsintheMissing)
        assertThat(blocker.reportPath).contains("Standalone_Android_FaceTime_Registration_Blocker.md")
    }

    @Test
    fun testIdsStateProgressTransition() {
        val inProgress = IdsState.InProgress(
            currentStageIndex = 0,
            stageName = "IDS_AUTH_CONTEXT_READY",
            stepStatuses = listOf(IdsStepStatus.IN_PROGRESS, IdsStepStatus.PENDING)
        )
        assertThat(inProgress.currentStageIndex).isEqualTo(0)
        assertThat(inProgress.stageName).isEqualTo("IDS_AUTH_CONTEXT_READY")
        assertThat(inProgress.stepStatuses).hasSize(2)
    }
}
