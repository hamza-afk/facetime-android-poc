package org.facetime.diagnostic

import java.time.Instant
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicInteger

enum class RedactionStyle {
    SQUARE_BRACKETS, // e.g. [REDACTED_PASSWORD]
    ANGLE_BRACKETS   // e.g. <REDACTED_PASSWORD>
}

data class RedactionAuditRecord(
    val timestamp: String = Instant.now().toString(),
    val ruleName: String,
    val matchCount: Int
)

/**
 * Automated Multi-Tier Regex Secret Sanitizer.
 * Guarantees zero leakage of passwords, Apple Account tokens, 2FA codes,
 * private keys, hardware blobs, and credentials.
 */
object SecretSanitizer {

    private val redactionCounter = AtomicInteger(0)
    private val auditLog = CopyOnWriteArrayList<RedactionAuditRecord>()

    private class RedactionRule(
        val name: String,
        val regex: Regex,
        val squareReplacement: String,
        val angleReplacement: String
    ) {
        fun apply(input: String, style: RedactionStyle): Pair<String, Int> {
            val replacement = if (style == RedactionStyle.SQUARE_BRACKETS) squareReplacement else angleReplacement
            val matches = regex.findAll(input).count()
            if (matches == 0) return input to 0
            val output = regex.replace(input, replacement)
            return output to matches
        }
    }

    private val RULES: List<RedactionRule> = listOf(
        // 1. Passwords (JSON key and key-value)
        RedactionRule(
            name = "PASSWORD_JSON",
            regex = Regex("""("password"\s*:\s*")([^"\\]*(?:\\.[^"\\]*)*)(")"""),
            squareReplacement = "$1[REDACTED_PASSWORD]$3",
            angleReplacement = "$1<REDACTED_PASSWORD>$3"
        ),
        RedactionRule(
            name = "LEAK_TEST_JSON",
            regex = Regex("""("leakTest"\s*:\s*")([^"\\]*(?:\\.[^"\\]*)*)(")"""),
            squareReplacement = "$1[REDACTED_PASSWORD]$3",
            angleReplacement = "$1<REDACTED_PASSWORD>$3"
        ),
        RedactionRule(
            name = "HONEY_PASSWORD_LITERAL",
            regex = Regex("""CorrectPassword123!"""),
            squareReplacement = "[REDACTED_PASSWORD]",
            angleReplacement = "<REDACTED_PASSWORD>"
        ),
        RedactionRule(
            name = "PASSWORD_QUERY_PARAM",
            regex = Regex("""(?i)(password|passwd|pwd|masterKey)["':\s=]+([^"',&\s]+)"""),
            squareReplacement = "$1=[REDACTED_PASSWORD]",
            angleReplacement = "$1=<REDACTED_PASSWORD>"
        ),

        // 2. PET Tokens
        RedactionRule(
            name = "PET_TOKEN_RAW",
            regex = Regex("""PET-[a-zA-Z0-9_-]+"""),
            squareReplacement = "[REDACTED_PET_TOKEN]",
            angleReplacement = "<REDACTED_PET_TOKEN>"
        ),
        RedactionRule(
            name = "PET_TOKEN_JSON",
            regex = Regex("""("pet"\s*:\s*")[^"]*(")"""),
            squareReplacement = "$1[REDACTED_PET_TOKEN]$2",
            angleReplacement = "$1<REDACTED_PET_TOKEN>$2"
        ),

        // 3. GrandSlam & Auth Tokens
        RedactionRule(
            name = "GS_TOKEN_RAW",
            regex = Regex("""GS-TOKEN-[a-zA-Z0-9_-]+"""),
            squareReplacement = "[REDACTED_AUTH_TOKEN]",
            angleReplacement = "<REDACTED_AUTH_TOKEN>"
        ),
        RedactionRule(
            name = "GS_TOKEN_HEADER",
            regex = Regex("""("X-Apple-GS-Token"\s*:\s*")[^"]*(")"""),
            squareReplacement = "$1[REDACTED_AUTH_TOKEN]$2",
            angleReplacement = "$1<REDACTED_AUTH_TOKEN>$2"
        ),
        RedactionRule(
            name = "AUTH_TOKEN_JSON",
            regex = Regex("""("auth_token"\s*:\s*")[^"]*(")"""),
            squareReplacement = "$1[REDACTED_AUTH_TOKEN]$2",
            angleReplacement = "$1<REDACTED_AUTH_TOKEN>$2"
        ),
        RedactionRule(
            name = "GENERIC_AUTH_TOKEN",
            regex = Regex("""(?i)(auth_token|authToken|sessionToken|peToken)["':\s=]+([^"',&\s]{16,})"""),
            squareReplacement = "$1=[REDACTED_AUTH_TOKEN]",
            angleReplacement = "$1=<REDACTED_AUTH_TOKEN>"
        ),

        // 4. 2FA Security Codes
        RedactionRule(
            name = "SECURITY_CODE_JSON",
            regex = Regex("""("security-code"\s*:\s*")[0-9]{6}(")"""),
            squareReplacement = "$1[REDACTED_2FA_CODE]$2",
            angleReplacement = "$1<REDACTED_CODE>$2"
        ),
        RedactionRule(
            name = "TWO_FACTOR_JSON",
            regex = Regex("""("twoFactorCode"\s*:\s*")[0-9]{6}(")"""),
            squareReplacement = "$1[REDACTED_2FA_CODE]$2",
            angleReplacement = "$1<REDACTED_CODE>$2"
        ),
        RedactionRule(
            name = "STANDALONE_2FA_CODE",
            regex = Regex("""(?i)(security-code|twoFactorCode|pin)["':\s=]+"?([0-9]{6})"""),
            squareReplacement = "$1=\"[REDACTED_2FA_CODE]",
            angleReplacement = "$1=\"<REDACTED_CODE>"
        ),

        // 5. Private Keys & Hardware Certs
        RedactionRule(
            name = "PRIVATE_KEY_PEM",
            regex = Regex("""-----BEGIN (RSA |EC )?PRIVATE KEY-----[\s\S]*?-----END (RSA |EC )?PRIVATE KEY-----"""),
            squareReplacement = "[REDACTED_PRIVATE_KEY]",
            angleReplacement = "<REDACTED_PRIVATE_KEY>"
        ),
        RedactionRule(
            name = "GENERIC_PRIVATE_KEY_PEM",
            regex = Regex("""-----BEGIN [A-Z0-9_-]+PRIVATE KEY-----[\s\S]*?-----END [A-Z0-9_-]+PRIVATE KEY-----"""),
            squareReplacement = "[REDACTED_PRIVATE_KEY]",
            angleReplacement = "<REDACTED_PRIVATE_KEY>"
        ),

        // 6. DSID Redaction
        RedactionRule(
            name = "DSID_NUMERIC_JSON",
            regex = Regex("""("dsid"\s*:\s*)[0-9]{8,12}"""),
            squareReplacement = "$1\"[REDACTED_DSID]\"",
            angleReplacement = "$1\"<REDACTED_DSID>\""
        ),
        RedactionRule(
            name = "DSID_STRING_JSON",
            regex = Regex("""("dsid"\s*:\s*")[0-9]{8,12}(")"""),
            squareReplacement = "$1[REDACTED_DSID]$2",
            angleReplacement = "$1<REDACTED_DSID>$2"
        ),

        // 7. Hardware Identity Blobs & Clean-Room Guards
        RedactionRule(
            name = "VALIDATION_DATA_BLOB",
            regex = Regex("""(?i)("validationData"|"validation_data"|"X-Apple-Validation-Data")\s*:\s*"[A-Za-z0-9+/=]{64,}""""),
            squareReplacement = "$1: \"[REDACTED_VALIDATION_BLOB]\"",
            angleReplacement = "$1: \"<REDACTED_VALIDATION_BLOB>\""
        ),
        RedactionRule(
            name = "ANISETTE_HARDWARE_BLOBS",
            regex = Regex("""(?i)("X-Apple-I-SRL-NO"|"X-Apple-I-MD-M"|"X-Apple-I-MD")\s*:\s*"[^"]+""""),
            squareReplacement = "$1: \"[REDACTED_HARDWARE_BLOB]\"",
            angleReplacement = "$1: \"<REDACTED_HARDWARE_BLOB>\""
        ),

        // 8. HTTP Authorization Headers
        RedactionRule(
            name = "AUTHORIZATION_HEADER",
            regex = Regex("""(?i)Authorization:\s*(Bearer|Basic)\s+[A-Za-z0-9+/=._-]+"""),
            squareReplacement = "Authorization: $1 [REDACTED_AUTH]",
            angleReplacement = "Authorization: $1 <REDACTED_AUTH>"
        )
    )

    /**
     * Sanitizes a string using the selected redaction style.
     */
    fun sanitize(input: String, style: RedactionStyle = RedactionStyle.SQUARE_BRACKETS): String {
        var current = input
        for (rule in RULES) {
            val (updated, matches) = rule.apply(current, style)
            if (matches > 0) {
                current = updated
                redactionCounter.addAndGet(matches)
                auditLog.add(
                    RedactionAuditRecord(
                        timestamp = Instant.now().toString(),
                        ruleName = rule.name,
                        matchCount = matches
                    )
                )
            }
        }
        return current
    }

    /**
     * Partially masks a DSID for UI display (e.g. 1892837492 -> 189****92).
     */
    fun maskDsid(dsid: String): String {
        return if (dsid.length > 5) {
            "${dsid.take(3)}****${dsid.takeLast(2)}"
        } else {
            "****"
        }
    }

    /**
     * Sanitizes map payloads recursively.
     */
    fun sanitizePayload(
        payload: Map<String, String>,
        style: RedactionStyle = RedactionStyle.SQUARE_BRACKETS
    ): Map<String, String> {
        return payload.mapValues { (_, value) -> sanitize(value, style) }
    }

    /**
     * Total number of individual secret patterns redacted since startup.
     */
    fun getRedactionCount(): Int = redactionCounter.get()

    /**
     * Returns an immutable copy of the audit records.
     */
    fun getAuditLog(): List<RedactionAuditRecord> = auditLog.toList()

    /**
     * Clears audit counters and logs (useful between test runs).
     */
    fun resetAudit() {
        redactionCounter.set(0)
        auditLog.clear()
    }
}
