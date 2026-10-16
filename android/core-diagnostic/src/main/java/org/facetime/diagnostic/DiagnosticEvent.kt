package org.facetime.diagnostic

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.Instant
import java.util.concurrent.atomic.AtomicLong

@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class DiagnosticEvent(
    @SerialName("timestamp")
    val timestamp: String = Instant.now().toString(),

    @SerialName("seq")
    val seq: Long = nextSequenceNumber(),

    @SerialName("subsystem")
    val subsystem: DiagnosticSubsystem,

    @SerialName("severity")
    val severity: DiagnosticSeverity,

    @SerialName("eventName")
    val eventName: String,

    @SerialName("payload")
    val payload: Map<String, String> = emptyMap(),

    @SerialName("message")
    val message: String? = null,

    @EncodeDefault
    @SerialName("sanitized")
    val sanitized: Boolean = true
) {
    fun toJsonl(): String = jsonSerializer.encodeToString(this)

    companion object {
        private val seqCounter = AtomicLong(1L)
        fun nextSequenceNumber(): Long = seqCounter.getAndIncrement()

        val jsonSerializer = Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
            isLenient = true
            prettyPrint = false // Strict single-line JSONL
        }

        fun fromJson(jsonStr: String): DiagnosticEvent {
            return jsonSerializer.decodeFromString(jsonStr)
        }
    }
}
