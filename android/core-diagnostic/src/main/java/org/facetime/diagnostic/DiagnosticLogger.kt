package org.facetime.diagnostic

import android.util.Log

/**
 * Ingestion bus for protocol events emitted by Rust UniFFI or Kotlin services.
 */
class DiagnosticLogger(
    val buffer: CircularEventBuffer = CircularEventBuffer()
) {
    fun emit(
        subsystem: DiagnosticSubsystem,
        severity: DiagnosticSeverity,
        eventName: String,
        payload: Map<String, String> = emptyMap(),
        message: String? = null
    ): DiagnosticEvent {
        // 1. Sanitize payload and message
        val sanitizedPayload = SecretSanitizer.sanitizePayload(payload)
        val sanitizedMessage = message?.let { SecretSanitizer.sanitize(it) }

        // 2. Build structured event
        val event = DiagnosticEvent(
            subsystem = subsystem,
            severity = severity,
            eventName = eventName,
            payload = sanitizedPayload,
            message = sanitizedMessage,
            sanitized = true
        )

        // 3. Append to ring buffer
        buffer.append(event)

        // 4. Log to Android Logcat
        logToPlatform(event)

        return event
    }

    /**
     * Ingestion point for Rust UniFFI onDiagnosticEvent callback.
     */
    fun ingestRustJsonl(rawJsonl: String) {
        val sanitized = SecretSanitizer.sanitize(rawJsonl)
        try {
            val event = DiagnosticEvent.fromJson(sanitized)
            buffer.append(event)
            logToPlatform(event)
        } catch (_: Exception) {
            emit(
                subsystem = DiagnosticSubsystem.SYSTEM,
                severity = DiagnosticSeverity.DEBUG,
                eventName = "RUST_RAW_LOG",
                message = sanitized
            )
        }
    }

    private fun logToPlatform(event: DiagnosticEvent) {
        val tag = "FT:${event.subsystem}"
        val text = "[${event.eventName}] ${event.message ?: ""} ${event.payload}"
        try {
            when (event.severity) {
                DiagnosticSeverity.VERBOSE -> Log.v(tag, text)
                DiagnosticSeverity.DEBUG -> Log.d(tag, text)
                DiagnosticSeverity.INFO -> Log.i(tag, text)
                DiagnosticSeverity.WARN -> Log.w(tag, text)
                DiagnosticSeverity.ERROR -> Log.e(tag, text)
            }
        } catch (_: Exception) {
            // JVM test environment without android.util.Log mock
        }
    }
}
