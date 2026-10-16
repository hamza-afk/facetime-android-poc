package org.facetime.security

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class PasswordZeroizerTest {

    @Test
    fun testWipeClearsAllCharacters() {
        val password = "SuperSecretPassword123!".toCharArray()
        assertThat(PasswordZeroizer.isZeroized(password)).isFalse()

        PasswordZeroizer.wipe(password)
        assertThat(PasswordZeroizer.isZeroized(password)).isTrue()
        assertThat(password).isEqualTo(CharArray(password.size) { '\u0000' })
    }

    @Test
    fun testUseAndWipeClearsOnCompletion() {
        val password = "AnotherSecretPassword".toCharArray()
        var observedLength = 0

        val result = PasswordZeroizer.useAndWipe(password) { buf ->
            observedLength = buf.size
            "success"
        }

        assertThat(result).isEqualTo("success")
        assertThat(observedLength).isGreaterThan(0)
        assertThat(PasswordZeroizer.isZeroized(password)).isTrue()
    }

    @Test
    fun testUseAndWipeClearsOnException() {
        val password = "ExceptionPassword".toCharArray()

        try {
            PasswordZeroizer.useAndWipe(password) {
                throw IllegalStateException("Forced error during password handling")
            }
        } catch (_: IllegalStateException) {}

        assertThat(PasswordZeroizer.isZeroized(password)).isTrue()
    }
}
