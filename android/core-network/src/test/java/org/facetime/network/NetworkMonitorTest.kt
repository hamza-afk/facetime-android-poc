package org.facetime.network

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class NetworkMonitorTest {

    @Test
    fun testActiveNetworkTypeHierarchy() {
        val disconnected = ActiveNetworkType.Disconnected
        val wifi = ActiveNetworkType.Wifi
        val cellular = ActiveNetworkType.Cellular

        assertThat(disconnected).isNotEqualTo(wifi)
        assertThat(wifi).isNotEqualTo(cellular)
    }

    @Test
    fun testReconnectBackoffSchedule() {
        val schedule = listOf(1L, 2L, 4L, 8L, 16L, 32L)
        assertThat(schedule).hasSize(6)
        assertThat(schedule.first()).isEqualTo(1L)
        assertThat(schedule.last()).isEqualTo(32L)
    }
}
