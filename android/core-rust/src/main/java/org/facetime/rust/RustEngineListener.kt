package org.facetime.rust

import uniffi.facetime_core.ApsStatus
import uniffi.facetime_core.AuthState
import uniffi.facetime_core.CallState
import uniffi.facetime_core.DiagnosticEventJsonl
import uniffi.facetime_core.FaceTimeCoreEventListener
import uniffi.facetime_core.IdsStage

interface EngineEventConsumer {
    fun onAuth(state: AuthState)
    fun onAps(status: ApsStatus)
    fun onIds(stage: IdsStage)
    fun onCall(callId: String, state: CallState)
    fun onDiagnostic(event: DiagnosticEventJsonl)
}

class RustEngineListener(
    private val consumer: EngineEventConsumer
) : FaceTimeCoreEventListener {
    override fun onAuthStateChanged(state: AuthState) {
        consumer.onAuth(state)
    }

    override fun onApsStateChanged(status: ApsStatus) {
        consumer.onAps(status)
    }

    override fun onIdsStateChanged(stage: IdsStage) {
        consumer.onIds(stage)
    }

    override fun onCallStateChanged(callId: String, state: CallState) {
        consumer.onCall(callId, state)
    }

    override fun onDiagnosticEvent(event: DiagnosticEventJsonl) {
        consumer.onDiagnostic(event)
    }
}
