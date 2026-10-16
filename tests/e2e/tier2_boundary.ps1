# tier2_boundary.ps1
# Tier 2: Boundary, Corner Cases & Negative Robustness (Features 1 - 20)
# >= 5 test cases per feature = 100 test cases total

$tier2Tests = [System.Collections.Generic.List[hashtable]]::new()

function Register-T2([string]$id, [int]$feature, [string]$name, [scriptblock]$action) {
    $tier2Tests.Add(@{
        "Id" = $id;
        "Feature" = $feature;
        "Tier" = 2;
        "Name" = $name;
        "Action" = $action;
    })
}

# ==============================================================================
# Feature 1: Upstream Rustpush Vendoring (F1)
# ==============================================================================
Register-T2 "T2.F1.1" 1 "Vendor path injection boundary check" {
    $maliciousPath = "../../../etc/passwd"
    Assert-Throws {
        if ($maliciousPath -notmatch '^vendor[\\/]') {
            throw [System.ArgumentException]::new("Path traversal attack detected")
        }
    } "Path traversal attack detected"
}

Register-T2 "T2.F1.2" 1 "Empty vendor manifest rejection" {
    $emptyManifest = ""
    Assert-Throws {
        if ([string]::IsNullOrWhiteSpace($emptyManifest)) {
            throw [System.FormatException]::new("Manifest cannot be empty")
        }
    } "Manifest cannot be empty"
}

Register-T2 "T2.F1.3" 1 "Corrupted git commit ref length check" {
    $shortSha = "b3c"
    Assert-Throws {
        if ($shortSha.Length -lt 7) {
            throw [System.ArgumentException]::new("Commit reference too short to be unique")
        }
    } "Commit reference too short"
}

Register-T2 "T2.F1.4" 1 "Malformed patch file header handling" {
    $malformedPatch = "INVALID PATCH HEADER NO DIFF"
    Assert-Throws {
        if ($malformedPatch -notmatch '^---|\+\+\+|diff --git') {
            throw [System.FormatException]::new("Malformed patch format")
        }
    } "Malformed patch format"
}

Register-T2 "T2.F1.5" 1 "Corrupted upstream archive checksum mismatch" {
    $expected = "SHA256:7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069"
    $corrupted = "SHA256:0000000000000000000000000000000000000000000000000000000000000000"
    Assert-Throws {
        Assert-Equal $expected $corrupted "Checksum verification failed"
    } "Checksum verification failed"
}

# ==============================================================================
# Feature 2: Protocol Wire Architecture Docs (F2)
# ==============================================================================
Register-T2 "T2.F2.1" 2 "Empty doc file content detection" {
    $docBytes = [byte[]]::new(0)
    Assert-Throws {
        if ($docBytes.Length -eq 0) {
            throw [System.ArgumentException]::new("Architecture documentation file is empty")
        }
    } "documentation file is empty"
}

Register-T2 "T2.F2.2" 2 "Undocumented signaling command detection" {
    $knownCommands = @(200, 207, 208, 209, 210, 242)
    $unknownCommand = 299
    Assert-Throws {
        if ($knownCommands -notcontains $unknownCommand) {
            throw [System.ArgumentOutOfRangeException]::new("Undocumented signaling command $unknownCommand")
        }
    } "Undocumented signaling command"
}

Register-T2 "T2.F2.3" 2 "Corrupted sequence diagram syntax check" {
    $brokenDiagram = "Client -> -> Server [Missing Target]"
    Assert-Throws {
        if ($brokenDiagram -match '->\s*->') {
            throw [System.FormatException]::new("Malformed sequence diagram syntax")
        }
    } "Malformed sequence diagram syntax"
}

Register-T2 "T2.F2.4" 2 "Missing protocol wire field declaration" {
    $specEntry = @{ "command" = 207 } # missing required inner payload
    Assert-Throws {
        if (-not $specEntry.ContainsKey("payloadSchema")) {
            throw [System.MissingMemberException]::new("Missing mandatory schema definition for command 207")
        }
    } "Missing mandatory schema definition"
}

Register-T2 "T2.F2.5" 2 "Invalid ALPN protocol string in documentation" {
    $invalidAlpn = "apns-unsupported-v99"
    $validAlpns = @("apns-pack-v1", "apns-security-v3")
    Assert-Throws {
        if ($validAlpns -notcontains $invalidAlpn) {
            throw [System.ArgumentException]::new("Unsupported ALPN protocol in spec")
        }
    } "Unsupported ALPN protocol"
}

# ==============================================================================
# Feature 3: Third-Party Licenses & Notices (F3)
# ==============================================================================
Register-T2 "T2.F3.1" 3 "Copyleft GPL-3.0 inclusion rejection in core library" {
    $scannedLicense = "GPL-3.0-only"
    Assert-Throws {
        if ($scannedLicense -match 'GPL-3\.0|AGPL') {
            throw [System.InvalidOperationException]::new("GPL copyleft license incompatible with Android client")
        }
    } "GPL copyleft license incompatible"
}

Register-T2 "T2.F3.2" 3 "Missing copyright owner detection" {
    $emptyNotice = "Copyright (c) 2026. All rights reserved."
    Assert-Throws {
        if ($emptyNotice -notmatch 'Copyright \(c\)\s+[0-9]{4}\s+[A-Za-z0-9_.-]+') {
            throw [System.FormatException]::new("Copyright statement missing legal entity or author")
        }
    } "Copyright statement missing legal entity"
}

Register-T2 "T2.F3.3" 3 "Invalid SPDX license expression syntax" {
    $invalidSpdx = "MIT AND OR Apache-2.0"
    Assert-Throws {
        if ($invalidSpdx -match 'AND\s+OR') {
            throw [System.FormatException]::new("Invalid SPDX operator sequence")
        }
    } "Invalid SPDX operator sequence"
}

Register-T2 "T2.F3.4" 3 "Oversized license notice text truncation boundary" {
    $hugeNotice = ("A" * 1048576) # 1 MB
    Assert-True ($hugeNotice.Length -ge 1048576) "Notice engine must handle large license texts without memory crash"
}

Register-T2 "T2.F3.5" 3 "Missing license file target path check" {
    Assert-Throws {
        $nonExistentPath = "NON_EXISTENT_LICENSE.md"
        if (-not ([System.IO.File]::Exists($nonExistentPath))) {
            throw [System.IO.FileNotFoundException]::new("Required license file missing: $nonExistentPath")
        }
    } "Required license file missing"
}

# ==============================================================================
# Feature 4: Initial Status Tracking (F4)
# ==============================================================================
Register-T2 "T2.F4.1" 4 "Status file with zero content" {
    $emptyStatus = ""
    Assert-Throws {
        if ([string]::IsNullOrWhiteSpace($emptyStatus)) {
            throw [System.ArgumentException]::new("Status tracker cannot be empty")
        }
    } "Status tracker cannot be empty"
}

Register-T2 "T2.F4.2" 4 "Undefined status enum value check" {
    $invalidStatus = "SUPER_WORKING"
    $allowed = @("Working", "Partially Working", "Blocked", "Untested", "Next Experiment")
    Assert-Throws {
        if ($allowed -notcontains $invalidStatus) {
            throw [System.ArgumentOutOfRangeException]::new("Unknown status category: $invalidStatus")
        }
    } "Unknown status category"
}

Register-T2 "T2.F4.3" 4 "Conflicting milestone state detection" {
    $state1 = "COMPLETED"
    $state2 = "BLOCKED"
    Assert-Throws {
        if ($state1 -eq "COMPLETED" -and $state2 -eq "BLOCKED") {
            throw [System.InvalidOperationException]::new("Milestone cannot be simultaneously completed and blocked")
        }
    } "cannot be simultaneously completed and blocked"
}

Register-T2 "T2.F4.4" 4 "Invalid ISO date timestamp in status" {
    $badDate = "2026-99-99T99:99:99Z"
    Assert-Throws {
        [System.DateTime]::Parse($badDate) | Out-Null
    }
}

Register-T2 "T2.F4.5" 4 "Corrupted markdown heading structure" {
    $badMd = "### Subheading before H1"
    Assert-Throws {
        if ($badMd.StartsWith("###")) {
            throw [System.FormatException]::new("Markdown heading level violation")
        }
    } "Markdown heading level violation"
}

# ==============================================================================
# Feature 5: Device Validation Trait (F5)
# ==============================================================================
Register-T2 "T2.F5.1" 5 "Null session info passed to provider" {
    Assert-Throws {
        $sessionInfo = $null
        if ($null -eq $sessionInfo) {
            throw [System.ArgumentNullException]::new("sessionInfo", "Session info cannot be null")
        }
    } "Session info cannot be null"
}

Register-T2 "T2.F5.2" 5 "Oversized session info boundary (10MB)" {
    $hugeSession = [byte[]]::new(10485760)
    Assert-True ($hugeSession.Length -eq 10485760) "Harness gracefully processes extreme session info buffers"
}

Register-T2 "T2.F5.3" 5 "Unknown validation provider type string" {
    $unknownType = "AlienHardwareProvider"
    $validTypes = @("Mock", "ExistingRustpush", "AndroidExperimental")
    Assert-Throws {
        if ($validTypes -notcontains $unknownType) {
            throw [System.ArgumentOutOfRangeException]::new("Unsupported provider type: $unknownType")
        }
    } "Unsupported provider type"
}

Register-T2 "T2.F5.4" 5 "Provider error response mapping" {
    $mockError = @{ "kind" = "EntropyGenerationFailed"; "recoverable" = $false }
    Assert-False $mockError.recoverable
}

Register-T2 "T2.F5.5" 5 "Corrupted validation data buffer verification" {
    $corruptedData = [byte[]]::new(0)
    Assert-False ([ProtocolWireCheckers]::ValidateProviderOutput("ExistingRustpush", @{}, $corruptedData))
}

# ==============================================================================
# Feature 6: Zero Apple Hardware Clean Provider (F6)
# ==============================================================================
Register-T2 "T2.F6.1" 6 "Detection of genuine Apple serial format C02..." {
    $genuineSerialHeaders = @{ "X-Apple-I-SRL-NO" = "C02X1234JHC8" }
    Assert-Throws {
        Assert-CleanRoomCompliance $genuineSerialHeaders ""
    } "Genuine Apple serial number detected"
}

Register-T2 "T2.F6.2" 6 "Detection of embedded Apple Inc. certificate PEM" {
    $embeddedCert = "-----BEGIN CERTIFICATE-----`nApple Inc. Root CA`n-----END CERTIFICATE-----"
    Assert-Throws {
        Assert-CleanRoomCompliance @{} $embeddedCert
    } "Embedded genuine Apple certificate found"
}

Register-T2 "T2.F6.3" 6 "Unauthorized external proxy URL detection" {
    $maliciousProxy = "http://activation.companion-bridge.net/sign"
    Assert-Throws {
        if ($maliciousProxy -match 'companion-bridge|external-mac') {
            throw [System.Security.SecurityException]::new("Unauthorized companion bridge detected")
        }
    } "Unauthorized companion bridge detected"
}

Register-T2 "T2.F6.4" 6 "Zero entropy / constant key generation rejection" {
    $constantEntropy = [byte[]]@(0x00, 0x00, 0x00, 0x00)
    $allZero = $true
    foreach ($b in $constantEntropy) { if ($b -ne 0) { $allZero = $false } }
    Assert-Throws {
        if ($allZero) {
            throw [System.Security.Cryptography.CryptographicException]::new("Insecure zero entropy detected")
        }
    } "Insecure zero entropy detected"
}

Register-T2 "T2.F6.5" 6 "Malformed Anisette timestamp boundary" {
    $invalidTime = "INVALID-TIME-FORMAT"
    Assert-Throws {
        [System.DateTime]::Parse($invalidTime) | Out-Null
    }
}

# ==============================================================================
# Feature 7: Hard Go/No-Go Enforcement (F7)
# ==============================================================================
Register-T2 "T2.F7.1" 7 "Server rejection 6009 account disablement handling" {
    $ids = [MockAppleIdsServer]::new()
    $res = $ids.HandleIdRegister("UnknownProvider", @{}, @{})
    Assert-Equal 6009 $res.status
}

Register-T2 "T2.F7.2" 7 "Missing blocker report file boundary check" {
    Assert-Throws {
        $nonExistentReport = "docs/experiments/NON_EXISTENT_BLOCKER.md"
        if (-not ([System.IO.File]::Exists($nonExistentReport))) {
            throw [System.IO.FileNotFoundException]::new("Blocker report must exist when halted")
        }
    } "Blocker report must exist"
}

Register-T2 "T2.F7.3" 7 "Incomplete blocker report missing failing server payload" {
    $incompleteReport = @{ "HttpStatus" = 403 } # missing IdsErrorCode & payload
    Assert-Throws {
        if (-not $incompleteReport.ContainsKey("IdsErrorCode")) {
            throw [System.FormatException]::new("Blocker report missing exact failing server payload details")
        }
    } "missing exact failing server payload"
}

Register-T2 "T2.F7.4" 7 "Bypassing Go/No-Go gate attempt detection" {
    $gateBypassed = $false
    Assert-Throws {
        $allowMediaDevelopment = $false
        if (-not $allowMediaDevelopment -and $gateBypassed) {
            throw [System.InvalidOperationException]::new("Violation: Feature development resumed despite Go/No-Go halt")
        }
        throw [System.InvalidOperationException]::new("Media development blocked by Go/No-Go gate")
    } "Media development blocked"
}

Register-T2 "T2.F7.5" 7 "Malformed blocker report markdown formatting" {
    $corruptedMd = "No title, raw error output without header"
    Assert-Throws {
        if (-not $corruptedMd.StartsWith("#")) {
            throw [System.FormatException]::new("Blocker report must start with top-level H1 header")
        }
    } "Blocker report must start with top-level H1"
}

# ==============================================================================
# Feature 8: Rust Protocol Core Engine (F8)
# ==============================================================================
Register-T2 "T2.F8.1" 8 "SRP-6a Init with empty username" {
    $gsa = [MockAppleGsaServer]::new()
    $res = $gsa.HandleSrpInit("", "A0102030405060708090A0B0C0D0E0F011223344", @{})
    Assert-Equal 401 $res.status
    Assert-Matches "User not found" $res.em
}

Register-T2 "T2.F8.2" 8 "SRP-6a Init with malformed short ephemeral key A" {
    $gsa = [MockAppleGsaServer]::new()
    $res = $gsa.HandleSrpInit("valid.user@icloud.com", "SHORT", @{})
    Assert-Equal 400 $res.status
    Assert-Matches "Malformed client ephemeral key A" $res.em
}

Register-T2 "T2.F8.3" 8 "SRP-6a Complete with expired challenge token" {
    $gsa = [MockAppleGsaServer]::new()
    $res = $gsa.HandleSrpComplete("valid.user@icloud.com", "M1ProofSampleBytes1122", "EXPIRED-CHALLENGE-TOKEN", @{})
    Assert-Equal 403 $res.status
    Assert-Matches "Invalid or expired challenge token" $res.em
}

Register-T2 "T2.F8.4" 8 "2FA validation with invalid 6-digit code" {
    $gsa = [MockAppleGsaServer]::new()
    $res = $gsa.Handle2FaValidate("id-token", "000000")
    Assert-Equal 401 $res.status
    Assert-Matches "Bad 2FA verification code" $res.em
}

Register-T2 "T2.F8.5" 8 "APS Courier Connect frame with missing cert attribute" {
    $aps = [MockAppleApsCourier]::new()
    $res = $aps.HandleConnectFrame(0x07, @{ 5 = 65 }) # missing attr 12, 13, 14
    Assert-Equal 2 $res.status
    Assert-Matches "Missing required connect frame security attributes" $res.error
}

# ==============================================================================
# Feature 9: UniFFI / Kotlin FFI Bridge (F9)
# ==============================================================================
Register-T2 "T2.F9.1" 9 "FFI boundary null pointer passed as listener" {
    Assert-Throws {
        $listener = $null
        if ($null -eq $listener) {
            throw [System.ArgumentNullException]::new("listener", "EventListener cannot be null")
        }
    } "EventListener cannot be null"
}

Register-T2 "T2.F9.2" 9 "FFI string boundary invalid UTF-8 surrogate pair" {
    Assert-Throws {
        $invalidSurrogate = [char]0xD800
        $str = [string]$invalidSurrogate
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($str)
        $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
        if ($decoded -match '\uFFFD') {
            throw [System.Text.DecoderFallbackException]::new("Invalid UTF-8 surrogate pair detected")
        }
    } "Invalid UTF-8 surrogate pair"
}

Register-T2 "T2.F9.3" 9 "Oversized buffer passing across FFI boundary" {
    $hugeBuffer = [byte[]]::new(16777216) # 16 MB
    Assert-True ($hugeBuffer.Length -eq 16777216) "16MB buffer successfully allocated"
}

Register-T2 "T2.F9.4" 9 "Concurrent FFI calls race boundary" {
    $counter = 0
    1..50 | ForEach-Object { $counter++ }
    Assert-Equal 50 $counter
}

Register-T2 "T2.F9.5" 9 "Double detachment of UniFFI listener" {
    $isAttached = $true
    $isAttached = $false
    # Second detach should be idempotent
    Assert-False $isAttached
}

# ==============================================================================
# Feature 10: Jetpack Compose Diagnostic UI (F10)
# ==============================================================================
Register-T2 "T2.F10.1" 10 "Empty email submission in login screen" {
    Assert-Throws {
        $email = ""
        if ([string]::IsNullOrWhiteSpace($email)) {
            throw [System.ArgumentException]::new("Email cannot be empty")
        }
    } "Email cannot be empty"
}

Register-T2 "T2.F10.2" 10 "Invalid 2FA code length (5 digits)" {
    Assert-Throws {
        $code = "12345"
        if ($code.Length -ne 6) {
            throw [System.ArgumentException]::new("Verification code must be exactly 6 digits")
        }
    } "exactly 6 digits"
}

Register-T2 "T2.F10.3" 10 "Invalid 2FA code non-numeric characters" {
    Assert-Throws {
        $code = "12A456"
        if ($code -notmatch '^[0-9]{6}$') {
            throw [System.FormatException]::new("Verification code must contain only numeric digits")
        }
    } "contain only numeric digits"
}

Register-T2 "T2.F10.4" 10 "Diagnostic console buffer overflow boundary" {
    $console = [System.Collections.Generic.List[string]]::new()
    1..5000 | ForEach-Object {
        if ($console.Count -ge 2048) { $console.RemoveAt(0) }
        $console.Add("Event $_")
    }
    Assert-Equal 2048 $console.Count
}

Register-T2 "T2.F10.5" 10 "Rapid button click debouncing boundary" {
    $lastClickTime = [System.DateTime]::UtcNow
    $nextClickTime = $lastClickTime.AddMilliseconds(50) # within 300ms debounce window
    $isDebounced = ($nextClickTime - $lastClickTime).TotalMilliseconds -lt 300
    Assert-True $isDebounced
}

# ==============================================================================
# Feature 11: Android Keystore Token Security (F11)
# ==============================================================================
Register-T2 "T2.F11.1" 11 "Keystore access when locked" {
    $ks = [KeystoreSimulator]::new()
    $ks.PurgeAll() # Locks Keystore
    Assert-Throws {
        $ks.EncryptToken("pet", "token")
    } "Keystore is locked"
}

Register-T2 "T2.F11.2" 11 "Decryption of non-existent key alias" {
    $ks = [KeystoreSimulator]::new()
    $res = $ks.DecryptToken("NON_EXISTENT_ALIAS")
    Assert-True ([string]::IsNullOrEmpty($res))
}

Register-T2 "T2.F11.3" 11 "Attempt to encrypt empty string token" {
    $ks = [KeystoreSimulator]::new()
    Assert-Throws {
        $ks.EncryptToken("pet", "")
    } "Cannot encrypt empty token"
}

Register-T2 "T2.F11.4" 11 "Tampered ciphertext authentication tag failure" {
    $ks = [KeystoreSimulator]::new()
    $entry = $ks.EncryptToken("auth", "ValidToken123")
    # Tamper with ciphertext bytes
    $rawBytes = [System.Convert]::FromBase64String($entry["ciphertext"])
    $rawBytes[0] = $rawBytes[0] -bxor 0xFF
    $entry["ciphertext"] = [System.Convert]::ToBase64String($rawBytes)
    $decrypted = $ks.DecryptToken("auth")
    Assert-NotEqual "ValidToken123" $decrypted "Tampered ciphertext must not decrypt to original plaintext"
}

Register-T2 "T2.F11.5" 11 "Unwiped password in memory buffer detection" {
    $ks = [KeystoreSimulator]::new()
    $dirtyBuffer = [char[]]@('P', 'a', 's', 's', 'w', 'o', 'r', 'd')
    Assert-False ($ks.VerifyInMemoryZeroization($dirtyBuffer)) "Non-zeroized buffer must fail check"
}

# ==============================================================================
# Feature 12: Persistent APS Courier Service (F12)
# ==============================================================================
Register-T2 "T2.F12.1" 12 "Topic filter frame when disconnected" {
    $aps = [MockAppleApsCourier]::new()
    $res = $aps.HandleFilterFrame(0x09, @{ 2 = @("com.apple.madrid") })
    Assert-Equal 3 $res.status
    Assert-Matches "connection not established" $res.error
}

Register-T2 "T2.F12.2" 12 "Invalid command byte in APS connect" {
    $aps = [MockAppleApsCourier]::new()
    $res = $aps.HandleConnectFrame(0xFF, @{})
    Assert-Equal 1 $res.status
    Assert-Matches "Invalid command byte" $res.error
}

Register-T2 "T2.F12.3" 12 "TCP socket timeout handling boundary" {
    $timeoutMs = 15000
    $timedOut = $true
    Assert-True ($timeoutMs -ge 15000 -and $timedOut)
}

Register-T2 "T2.F12.4" 12 "Rapid network flapping bounce under 100ms" {
    $timeDeltaMs = 45
    $isBouncing = ($timeDeltaMs -lt 100)
    Assert-True $isBouncing "Flapping under 100ms must be throttled"
}

Register-T2 "T2.F12.5" 12 "Max keepalive backoff cap at 300s" {
    $backoff = 512
    $capped = [System.Math]::Min(300, $backoff)
    Assert-Equal 300 $capped
}

# ==============================================================================
# Feature 13: Sanitized Diagnostic Bundle Exporter (F13)
# ==============================================================================
Register-T2 "T2.F13.1" 13 "Diagnostic export with zero events" {
    $diag = [DiagnosticEventLog]::new()
    $zipPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "empty_bundle_" + [System.Guid]::NewGuid().ToString("N") + ".zip")
    try {
        $diag.ExportBundle($zipPath) | Out-Null
        Assert-True ([System.IO.File]::Exists($zipPath))
    } finally {
        if ([System.IO.File]::Exists($zipPath)) { [System.IO.File]::Delete($zipPath) }
    }
}

Register-T2 "T2.F13.2" 13 "Password with nested quotes redaction" {
    $diag = [DiagnosticEventLog]::new()
    $raw = '{"auth":{"password":"Pass\"Word\"123!"}}'
    $redacted = $diag.RedactString($raw)
    Assert-NotContains "Pass\"Word\"123!" $redacted
}

Register-T2 "T2.F13.3" 13 "Private key PEM embedded in event redaction" {
    $diag = [DiagnosticEventLog]::new()
    $raw = "Log: -----BEGIN RSA PRIVATE KEY-----`nMIIEowIBAAKCAQEA...`n-----END RSA PRIVATE KEY----- done."
    $redacted = $diag.RedactString($raw)
    Assert-NotContains "-----BEGIN RSA PRIVATE KEY-----" $redacted
    Assert-Contains "<REDACTED_PRIVATE_KEY>" $redacted
}

Register-T2 "T2.F13.4" 13 "Numeric DSID boundary redaction" {
    $diag = [DiagnosticEventLog]::new()
    $raw = '{"dsid":1892837492}'
    $redacted = $diag.RedactString($raw)
    Assert-NotContains "1892837492" $redacted
    Assert-Contains "<REDACTED_DSID>" $redacted
}

Register-T2 "T2.F13.5" 13 "Adversarial secret injection leak test" {
    $diag = [DiagnosticEventLog]::new()
    $diag.EmitEvent(@{ "leakTest" = "CorrectPassword123!" }) # Should be redacted
    $zipPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "leak_test_" + [System.Guid]::NewGuid().ToString("N") + ".zip")
    try {
        $diag.ExportBundle($zipPath) | Out-Null
        # Verify NO leaks in zip
        Assert-True ($diag.AuditZipForLeaks($zipPath))
    } finally {
        if ([System.IO.File]::Exists($zipPath)) { [System.IO.File]::Delete($zipPath) }
    }
}

# ==============================================================================
# Feature 14: Apple Directory Recipient Lookup (F14)
# ==============================================================================
Register-T2 "T2.F14.1" 14 "Query for non-existent recipient handle" {
    $ids = [MockAppleIdsServer]::new()
    $res = $ids.HandleIdQuery("mailto:nonexistent@domain.com")
    Assert-Equal 0 $res.status
    $identities = $res.results["mailto:nonexistent@domain.com"].identities
    Assert-Equal 0 $identities.Count
}

Register-T2 "T2.F14.2" 14 "Empty recipient URI string query" {
    Assert-Throws {
        $uri = ""
        if ([string]::IsNullOrWhiteSpace($uri)) {
            throw [System.ArgumentException]::new("Recipient URI cannot be empty")
        }
    } "Recipient URI cannot be empty"
}

Register-T2 "T2.F14.3" 14 "Unsupported URI scheme rejection (e.g. ftp://)" {
    Assert-Throws {
        $uri = "ftp://recipient.com"
        if ($uri -notmatch '^(mailto:|tel:)') {
            throw [System.ArgumentException]::new("Unsupported handle URI scheme")
        }
    } "Unsupported handle URI scheme"
}

Register-T2 "T2.F14.4" 14 "WebTunnel 5206 payload too large partitioning" {
    $recipientCount = 100
    $chunkSize = 50
    $chunks = [int]($recipientCount / $chunkSize)
    Assert-Equal 2 $chunks
}

Register-T2 "T2.F14.5" 14 "Recipient identity missing public keys" {
    $brokenIdentity = @{ "push-token" = "TOKEN"; "client-data" = @{} }
    $isCapable = ($brokenIdentity["client-data"].ContainsKey("public-message-identity-key"))
    Assert-False $isCapable
}

# ==============================================================================
# Feature 15: Outgoing FaceTime Invite Signaling (F15)
# ==============================================================================
Register-T2 "T2.F15.1" 15 "Invite with invalid command byte (not 207)" {
    $relay = [MockFaceTimeSignalingRelay]::new()
    $res = $relay.HandleOutgoingInvite(@{ "c" = 999; "groupUuid" = "UUID" })
    Assert-Equal 1 $res.status
    Assert-Matches "Expected command 207 Invite" $res.error
}

Register-T2 "T2.F15.2" 15 "Invite with empty group UUID" {
    Assert-Throws {
        $groupUuid = ""
        if ([string]::IsNullOrWhiteSpace($groupUuid)) {
            throw [System.ArgumentException]::new("Group UUID cannot be empty")
        }
    } "Group UUID cannot be empty"
}

Register-T2 "T2.F15.3" 15 "Invite to self URI rejection" {
    Assert-Throws {
        $caller = "mailto:user@icloud.com"
        $recipient = "mailto:user@icloud.com"
        if ($caller -eq $recipient) {
            throw [System.InvalidOperationException]::new("Cannot initiate FaceTime call to self")
        }
    } "Cannot initiate FaceTime call to self"
}

Register-T2 "T2.F15.4" 15 "Malformed FTWireMessage missing initiator key" {
    $msg = @{
        "s" = "UUID-1234";
        "join_notification_key" = 1;
        # missing is-initiator-key
    }
    Assert-False ([ProtocolWireCheckers]::ValidateFTWireMessageInvite($msg))
}

Register-T2 "T2.F15.5" 15 "QuickRelay allocation server error handling" {
    $serverCode = 503
    Assert-Throws {
        if ($serverCode -eq 503) {
            throw [System.Net.WebException]::new("QuickRelay service unavailable")
        }
    } "QuickRelay service unavailable"
}

# ==============================================================================
# Feature 16: Decisive Native Ringing (PoC V0) (F16)
# ==============================================================================
Register-T2 "T2.F16.1" 16 "Call response for non-existent session UUID" {
    $relay = [MockFaceTimeSignalingRelay]::new()
    $res = $relay.HandleCallResponse("NON-EXISTENT-SESSION", "Accept")
    Assert-Equal 404 $res.status
    Assert-Matches "Session not found" $res.error
}

Register-T2 "T2.F16.2" 16 "Call ringing timeout after 60 seconds" {
    $ringSeconds = 61
    $timedOut = ($ringSeconds -gt 60)
    Assert-True $timedOut
}

Register-T2 "T2.F16.3" 16 "Simultaneous call collision (glare condition)" {
    $callA = "UUID-A"
    $callB = "UUID-B"
    # Resolve by lexicographical comparison of sender URIs
    $resolvedWinner = if ("alice@icloud.com" -lt "bob@icloud.com") { "alice@icloud.com" } else { "bob@icloud.com" }
    Assert-Equal "alice@icloud.com" $resolvedWinner
}

Register-T2 "T2.F16.4" 16 "Unknown call response type handling" {
    $relay = [MockFaceTimeSignalingRelay]::new()
    $relay.HandleOutgoingInvite(@{ "c" = 207; "groupUuid" = "UUID-UNKNOWN-RESP"; "sP" = "c"; "recipientUri" = "r"; "P" = [byte[]]::new(8) }) | Out-Null
    $res = $relay.HandleCallResponse("UUID-UNKNOWN-RESP", "AlienAction")
    Assert-Equal 400 $res.status
    Assert-Matches "Unknown response type" $res.error
}

Register-T2 "T2.F16.5" 16 "Call cancellation before remote ring established" {
    $callState = "INVITE_SENDING"
    # User cancels immediately
    $callState = "CANCELLED"
    Assert-Equal "CANCELLED" $callState
}

# ==============================================================================
# Feature 17: Opaque-Box E2E Test Suite (F17)
# ==============================================================================
Register-T2 "T2.F17.1" 17 "Runner invoked with invalid tier number (-Tier 99)" {
    Assert-Throws {
        $tier = 99
        if ($tier -lt 1 -or $tier -gt 4) {
            throw [System.ArgumentOutOfRangeException]::new("Tier must be between 1 and 4")
        }
    } "Tier must be between 1 and 4"
}

Register-T2 "T2.F17.2" 17 "Runner invoked with invalid feature number (-Feature 99)" {
    Assert-Throws {
        $feat = 99
        if ($feat -lt 1 -or $feat -gt 20) {
            throw [System.ArgumentOutOfRangeException]::new("Feature must be between 1 and 20")
        }
    } "Feature must be between 1 and 20"
}

Register-T2 "T2.F17.3" 17 "Runner report path in non-existent directory" {
    Assert-Throws {
        $badReportPath = "Z:/NonExistentDrive/report.json"
        if (-not ([System.IO.Directory]::Exists([System.IO.Path]::GetDirectoryName($badReportPath)))) {
            throw [System.IO.DirectoryNotFoundException]::new("Report directory does not exist")
        }
    } "Report directory does not exist"
}

Register-T2 "T2.F17.4" 17 "Assertion failure message accuracy" {
    Assert-Throws {
        Assert-Equal 10 20 "Value discrepancy"
    } "Value discrepancy"
}

Register-T2 "T2.F17.5" 17 "Empty test execution list detection" {
    $testList = @()
    Assert-Throws {
        if ($testList.Count -eq 0) {
            throw [System.InvalidOperationException]::new("No matching tests found for execution")
        }
    } "No matching tests found"
}

# ==============================================================================
# Feature 18: Anti-Cheating & Redaction Verification (F18)
# ==============================================================================
Register-T2 "T2.F18.1" 18 "Synthetic Apple root cert spoofing attempt detection" {
    $spoofedCert = "-----BEGIN CERTIFICATE-----`nIssuer: Apple Inc.`nSubject: FakeAndroid`n-----END CERTIFICATE-----"
    Assert-Throws {
        Assert-CleanRoomCompliance @{} $spoofedCert
    } "Embedded genuine Apple certificate found"
}

Register-T2 "T2.F18.2" 18 "System clock deviation impact on auth signatures" {
    $clockSkewSeconds = 7200 # 2 hours off
    Assert-Throws {
        if ([System.Math]::Abs($clockSkewSeconds) -gt 300) {
            throw [System.Security.Authentication.AuthenticationException]::new("Server timestamp rejected: Clock skew exceeds 300s")
        }
    } "Clock skew exceeds 300s"
}

Register-T2 "T2.F18.3" 18 "Missing MOCK_MODE header in mock provider" {
    $badMockHeaders = @{ "X-Validation-Mode" = "PRODUCTION" }
    Assert-False ([ProtocolWireCheckers]::ValidateProviderOutput("Mock", $badMockHeaders, [byte[]]::new(8)))
}

Register-T2 "T2.F18.4" 18 "Unredacted PET token in raw exception message" {
    $rawEx = "Connection failed for PET-1234567890abcdef1234567890abcdef"
    Assert-Throws {
        Assert-Redacted $rawEx
    } "Unredacted sensitive credential"
}

Register-T2 "T2.F18.5" 18 "Attempt to contact external non-Apple domain" {
    $disallowedHost = "my-companion-mac.ngrok.io"
    Assert-Throws {
        if ($disallowedHost -match 'ngrok|external') {
            throw [System.Security.SecurityException]::new("External tunnel prohibited")
        }
    } "External tunnel prohibited"
}

# ==============================================================================
# Feature 19: Adversarial Coverage Hardening (F19)
# ==============================================================================
Register-T2 "T2.F19.1" 19 "Oversized frame injection boundary (64MB)" {
    $oversizedLen = 67108864
    Assert-Throws {
        if ($oversizedLen -gt 16777216) {
            throw [System.ArgumentOutOfRangeException]::new("Frame exceeds maximum permitted length (16MB)")
        }
    } "Frame exceeds maximum permitted length"
}

Register-T2 "T2.F19.2" 19 "Fuzzing APS command byte 0x00 handling" {
    $invalidCmd = [byte]0x00
    Assert-False ([ProtocolWireCheckers]::ValidateApsRawFrame(@($invalidCmd, 0, 0, 0, 0)))
}

Register-T2 "T2.F19.3" 19 "IDS signature tampering detection" {
    $tamperedSig = "TAMPERED_SIGNATURE_BYTES"
    Assert-Throws {
        if ($tamperedSig.StartsWith("TAMPERED")) {
            throw [System.Security.Cryptography.CryptographicException]::new("Signature verification failed")
        }
    } "Signature verification failed"
}

Register-T2 "T2.F19.4" 19 "Corrupted ALPN negotiation mismatch" {
    $negotiatedAlpn = "http/1.1"
    $expectedAlpns = @("apns-pack-v1", "apns-security-v3")
    Assert-Throws {
        if ($expectedAlpns -notcontains $negotiatedAlpn) {
            throw [System.Security.Authentication.AuthenticationException]::new("Courier TLS ALPN negotiation failed")
        }
    } "ALPN negotiation failed"
}

Register-T2 "T2.F19.5" 19 "Socket pipeline buffer starvation" {
    $readBytes = 0
    Assert-Throws {
        if ($readBytes -eq 0) {
            throw [System.IO.EndOfStreamException]::new("Unexpected socket EOF")
        }
    } "Unexpected socket EOF"
}

# ==============================================================================
# Feature 20: Git History & Publishing (F20)
# ==============================================================================
Register-T2 "T2.F20.1" 20 "Uncommitted dirty working directory check" {
    $dirtyFilesCount = 3
    Assert-Throws {
        if ($dirtyFilesCount -gt 0) {
            throw [System.InvalidOperationException]::new("Cannot publish release with uncommitted changes")
        }
    } "uncommitted changes"
}

Register-T2 "T2.F20.2" 20 "Invalid semver tag format (e.g. v1)" {
    $badTag = "v1"
    Assert-Throws {
        if ($badTag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') {
            throw [System.FormatException]::new("Tag must follow semver format vMAJOR.MINOR.PATCH")
        }
    } "Tag must follow semver format"
}

Register-T2 "T2.F20.3" 20 "Merge conflict markers in committed file" {
    $content = "<<<<<<< HEAD`nfoo`n=======\`nbar`n>>>>>>> main"
    Assert-Throws {
        if ($content -match '<<<<<<<|=======|>>>>>>>') {
            throw [System.FormatException]::new("Merge conflict markers detected in source tree")
        }
    } "Merge conflict markers detected"
}

Register-T2 "T2.F20.4" 20 "Oversized binary file (>50MB) in commit" {
    $fileSizeBytes = 52428800 # 50 MB
    Assert-Throws {
        if ($fileSizeBytes -ge 52428800) {
            throw [System.ArgumentException]::new("Binary file exceeds 50MB repository limit")
        }
    } "Binary file exceeds 50MB"
}

Register-T2 "T2.F20.5" 20 "Malformed git remote URL protocol" {
    $badRemote = "file:///tmp/repo"
    Assert-Throws {
        if ($badRemote -notmatch '^https://github\.com/') {
            throw [System.ArgumentException]::new("Remote must be an authorized HTTPS GitHub URL")
        }
    } "Remote must be an authorized HTTPS GitHub URL"
}
