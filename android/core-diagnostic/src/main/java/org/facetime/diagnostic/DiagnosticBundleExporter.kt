package org.facetime.diagnostic

import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

@Serializable
data class DeviceEnvironment(
    val os: String,
    val buildFingerprint: String,
    val device: String,
    val abi: String,
    val validationProvider: String,
    val cleanRoomVerified: Boolean,
    val appVersion: String,
    val timestamp: String = Instant.now().toString()
)

@Serializable
data class NetworkSummary(
    val apsCourier: String,
    val apsConnected: Boolean,
    val activeInterface: String,
    val tlsHandshakeDurationMs: Long,
    val pingLatencyMs: Long,
    val bytesSent: Long,
    val bytesReceived: Long,
    val reconnectCount: Int
)

data class LeakAuditResult(
    val isClean: Boolean,
    val leaksDetected: List<String>
)

/**
 * Generates an atomic, sanitized .zip diagnostic bundle containing:
 * - events.jsonl
 * - environment.json
 * - network-summary.json
 * - redaction_audit.log
 * - checksum.sha256
 */
class DiagnosticBundleExporter(
    private val buffer: CircularEventBuffer,
    private val stagingBaseDir: File? = null
) {
    private val json = Json {
        prettyPrint = true
        encodeDefaults = true
        ignoreUnknownKeys = true
    }

    /**
     * Exports a sanitized bundle to targetZipPath atomically.
     * Returns the generated zip file.
     */
    fun exportBundle(
        targetZipFile: File,
        environment: DeviceEnvironment = defaultEnvironment(),
        networkSummary: NetworkSummary = defaultNetworkSummary()
    ): File {
        val baseDir = stagingBaseDir ?: targetZipFile.parentFile ?: File(System.getProperty("java.io.tmpdir"))
        val stagingDir = File(baseDir, "ft_diag_staging_" + UUID.randomUUID().toString().replace("-", ""))
        val tempZipFile = File(baseDir, "ft_diag_" + UUID.randomUUID().toString().replace("-", "") + ".tmp")

        try {
            if (!stagingDir.mkdirs()) {
                throw IllegalStateException("Failed to create staging directory: ${stagingDir.absolutePath}")
            }

            // 1. Generate events.jsonl
            val eventsFile = File(stagingDir, "events.jsonl")
            eventsFile.bufferedWriter().use { writer ->
                val events = buffer.snapshot()
                for (event in events) {
                    val sanitizedJson = SecretSanitizer.sanitize(event.toJsonl())
                    writer.write(sanitizedJson)
                    writer.write("\n")
                }
            }

            // 2. Generate environment.json
            val envFile = File(stagingDir, "environment.json")
            val sanitizedEnvJson = SecretSanitizer.sanitize(json.encodeToString(environment))
            envFile.writeText(sanitizedEnvJson)

            // 3. Generate network-summary.json
            val netFile = File(stagingDir, "network-summary.json")
            val sanitizedNetJson = SecretSanitizer.sanitize(json.encodeToString(networkSummary))
            netFile.writeText(sanitizedNetJson)

            // 4. Generate redaction_audit.log
            val auditFile = File(stagingDir, "redaction_audit.log")
            auditFile.bufferedWriter().use { writer ->
                writer.write("# Redaction Audit Trail\n")
                writer.write("# Generated: ${Instant.now()}\n")
                writer.write("# Total Redactions: ${SecretSanitizer.getRedactionCount()}\n\n")
                for (record in SecretSanitizer.getAuditLog()) {
                    writer.write("[${record.timestamp}] Rule: ${record.ruleName} (Count: ${record.matchCount})\n")
                }
            }

            // 5. Generate checksum.sha256
            val checksumFile = File(stagingDir, "checksum.sha256")
            val manifest = StringBuilder()
            for (f in listOf(eventsFile, envFile, netFile, auditFile)) {
                manifest.append("${computeSha256(f)}  ${f.name}\n")
            }
            checksumFile.writeText(manifest.toString())

            // 6. Create Zip Archive into Temporary File
            ZipOutputStream(FileOutputStream(tempZipFile).buffered()).use { zos ->
                val filesToZip = listOf(eventsFile, envFile, netFile, auditFile, checksumFile)
                val bufferBytes = ByteArray(8192)
                for (file in filesToZip) {
                    val entry = ZipEntry(file.name)
                    zos.putNextEntry(entry)
                    file.inputStream().buffered().use { input ->
                        var read = input.read(bufferBytes)
                        while (read != -1) {
                            zos.write(bufferBytes, 0, read)
                            read = input.read(bufferBytes)
                        }
                    }
                    zos.closeEntry()
                }
            }

            // 7. Atomic Move to Destination File
            if (targetZipFile.exists()) {
                targetZipFile.delete()
            }
            targetZipFile.parentFile?.mkdirs()
            Files.move(tempZipFile.toPath(), targetZipFile.toPath(), StandardCopyOption.ATOMIC_MOVE)

            return targetZipFile

        } finally {
            // Clean up staging directory and temp file under all conditions
            if (stagingDir.exists()) {
                stagingDir.deleteRecursively()
            }
            if (tempZipFile.exists()) {
                tempZipFile.delete()
            }
        }
    }

    /**
     * Audits an exported zip file for known honey tokens or unredacted secret patterns.
     * Mirrors E2E Scenario 6 (T4.RW.6) and AuditZipForLeaks.
     */
    fun auditZipForLeaks(zipFile: File): LeakAuditResult {
        require(zipFile.exists()) { "Target zip file does not exist: ${zipFile.absolutePath}" }
        val leaks = mutableListOf<String>()

        val adversarialLeakPatterns = listOf(
            Regex("""CorrectPassword123!""") to "Plaintext Password Leak",
            Regex("""PET-a1b2c3d4e5f60718293a4b5c6d7e8f90""") to "Raw PET Token Leak",
            Regex("""GS-TOKEN-[a-zA-Z0-9_-]+""") to "Raw GS-Token Leak",
            Regex("""-----BEGIN (RSA |EC )?PRIVATE KEY-----""") to "Raw Private Key PEM Leak",
            Regex(""""security-code"\s*:\s*"123456"""") to "Raw 2FA PIN Code Leak"
        )

        ZipFile(zipFile).use { archive ->
            val entries = archive.entries()
            while (entries.hasMoreElements()) {
                val entry = entries.nextElement()
                val content = archive.getInputStream(entry).bufferedReader().readText()

                for ((regex, description) in adversarialLeakPatterns) {
                    if (regex.containsMatchIn(content)) {
                        leaks.add("Entry '${entry.name}' failed rule: $description")
                    }
                }
            }
        }

        return LeakAuditResult(
            isClean = leaks.isEmpty(),
            leaksDetected = leaks
        )
    }

    private fun computeSha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { stream ->
            val buffer = ByteArray(8192)
            var bytesRead = stream.read(buffer)
            while (bytesRead != -1) {
                digest.update(buffer, 0, bytesRead)
                bytesRead = stream.read(buffer)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    companion object {
        fun defaultEnvironment(): DeviceEnvironment {
            return DeviceEnvironment(
                os = "Android 14 (API 34)",
                buildFingerprint = "cleanroom/android/poc:14/UP1A.231005.007/10754064:user/release-keys",
                device = "CleanRoom-Android-Pixel8",
                abi = "arm64-v8a",
                validationProvider = "AndroidExperimental",
                cleanRoomVerified = true,
                appVersion = "1.0.0-poc"
            )
        }

        fun defaultNetworkSummary(): NetworkSummary {
            return NetworkSummary(
                apsCourier = "courier.push.apple.com:5223",
                apsConnected = true,
                activeInterface = "WIFI",
                tlsHandshakeDurationMs = 145,
                pingLatencyMs = 35,
                bytesSent = 14200,
                bytesReceived = 28400,
                reconnectCount = 0
            )
        }
    }
}
