package org.facetime.diagnostic

import com.google.common.truth.Truth.assertThat
import org.junit.Before
import org.junit.Test

class SecretSanitizerTest {

    @Before
    fun setUp() {
        SecretSanitizer.resetAudit()
    }

    @Test
    fun testPasswordRedactionInJson() {
        val raw = """{"user":"alice","password":"CorrectPassword123!"}"""
        val sanitized = SecretSanitizer.sanitize(raw)
        assertThat(sanitized).doesNotContain("CorrectPassword123!")
        assertThat(sanitized).contains("[REDACTED_PASSWORD]")
        assertThat(SecretSanitizer.getRedactionCount()).isAtLeast(1)
    }

    @Test
    fun testPasswordRedactionWithAngleBracketsCompatibility() {
        val raw = """{"user":"alice","password":"CorrectPassword123!"}"""
        val sanitized = SecretSanitizer.sanitize(raw, RedactionStyle.ANGLE_BRACKETS)
        assertThat(sanitized).doesNotContain("CorrectPassword123!")
        assertThat(sanitized).contains("<REDACTED_PASSWORD>")
    }

    @Test
    fun testPetTokenRedaction() {
        val raw = """{"pet":"PET-a1b2c3d4e5f60718293a4b5c6d7e8f90"}"""
        val sanitized = SecretSanitizer.sanitize(raw, RedactionStyle.ANGLE_BRACKETS)
        assertThat(sanitized).doesNotContain("PET-a1b2c3d4e5f60718293a4b5c6d7e8f90")
        assertThat(sanitized).contains("<REDACTED_PET_TOKEN>")
    }

    @Test
    fun testGsTokenRedaction() {
        val raw = """{"token":"GS-TOKEN-LongLivedSession-123456"}"""
        val sanitized = SecretSanitizer.sanitize(raw, RedactionStyle.ANGLE_BRACKETS)
        assertThat(sanitized).doesNotContain("GS-TOKEN-LongLivedSession-123456")
        assertThat(sanitized).contains("<REDACTED_AUTH_TOKEN>")
    }

    @Test
    fun testPrivateKeyPemRedaction() {
        val raw = """
            -----BEGIN RSA PRIVATE KEY-----
            MIIEowIBAAKCAQEA0r1234567890abcdef==
            -----END RSA PRIVATE KEY-----
        """.trimIndent()
        val sanitized = SecretSanitizer.sanitize(raw)
        assertThat(sanitized).doesNotContain("BEGIN RSA PRIVATE KEY")
        assertThat(sanitized).contains("[REDACTED_PRIVATE_KEY]")
    }

    @Test
    fun testDsidMasking() {
        val dsid = "1892837492"
        val masked = SecretSanitizer.maskDsid(dsid)
        assertThat(masked).isEqualTo("189****92")
    }
}
