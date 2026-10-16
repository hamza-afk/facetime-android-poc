package org.facetime.diagnostic

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class CircularEventBufferTest {

    @Test
    fun testBufferCapsAtCapacity() {
        val buffer = CircularEventBuffer(capacity = 5)
        for (i in 1..10) {
            buffer.append(
                DiagnosticEvent(
                    subsystem = DiagnosticSubsystem.AUTH,
                    severity = DiagnosticSeverity.INFO,
                    eventName = "EVENT_$i",
                    message = "Message $i"
                )
            )
        }

        assertThat(buffer.size()).isEqualTo(5)
        val snapshot = buffer.snapshot()
        assertThat(snapshot).hasSize(5)
        // Oldest events (1..5) should have been evicted; 6..10 remain
        assertThat(snapshot.first().eventName).isEqualTo("EVENT_6")
        assertThat(snapshot.last().eventName).isEqualTo("EVENT_10")
    }

    @Test
    fun testBufferFiltering() {
        val buffer = CircularEventBuffer(capacity = 10)
        buffer.append(DiagnosticEvent(subsystem = DiagnosticSubsystem.AUTH, severity = DiagnosticSeverity.INFO, eventName = "AUTH_LOGIN"))
        buffer.append(DiagnosticEvent(subsystem = DiagnosticSubsystem.APS, severity = DiagnosticSeverity.WARN, eventName = "APS_DROP"))
        buffer.append(DiagnosticEvent(subsystem = DiagnosticSubsystem.IDS, severity = DiagnosticSeverity.ERROR, eventName = "IDS_FAIL"))

        val errorOnly = buffer.filter(minSeverity = DiagnosticSeverity.ERROR)
        assertThat(errorOnly).hasSize(1)
        assertThat(errorOnly.first().eventName).isEqualTo("IDS_FAIL")

        val apsOnly = buffer.filter(subsystem = DiagnosticSubsystem.APS)
        assertThat(apsOnly).hasSize(1)
        assertThat(apsOnly.first().eventName).isEqualTo("APS_DROP")

        val queryMatch = buffer.filter(query = "LOGIN")
        assertThat(queryMatch).hasSize(1)
        assertThat(queryMatch.first().eventName).isEqualTo("AUTH_LOGIN")
    }
}
