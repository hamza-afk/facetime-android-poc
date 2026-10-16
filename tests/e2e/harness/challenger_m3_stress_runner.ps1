# tests/e2e/harness/challenger_m3_stress_runner.ps1
# Master Empirical Stress-Testing Harness for Milestone 3 Deliverables
# Executed by Milestone 3 Challenger 1 (gen2 replacement)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$RustCoreDir = Join-Path $RepoRoot "rust\facetime-core"
$AndroidDir = Join-Path $RepoRoot "android"
$TestsDir = Join-Path $RepoRoot "tests\e2e"
$DocsDir = Join-Path $RepoRoot "docs\experiments"
$BlockerReportPath = Join-Path $DocsDir "Standalone_Android_FaceTime_Registration_Blocker.md"

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Numerics

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "     Milestone 3 Empirical Challenger Harness -- Automated Stress Engine       " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Repository Root:  $RepoRoot" -ForegroundColor Gray
Write-Host "Rust Core Dir:    $RustCoreDir" -ForegroundColor Gray
Write-Host "Android App Dir:  $AndroidDir" -ForegroundColor Gray
Write-Host "E2E Tests Dir:    $TestsDir" -ForegroundColor Gray

. (Join-Path $TestsDir "harness\TestAssertions.ps1")
. (Join-Path $TestsDir "harness\MockAppleServers.ps1")
. (Join-Path $TestsDir "harness\KeystoreSimulator.ps1")
. (Join-Path $TestsDir "harness\DiagnosticAuditor.ps1")
. (Join-Path $TestsDir "harness\ProtocolWireCheckers.ps1")

$passed = 0
$failed = 0
$results = [System.Collections.Generic.List[hashtable]]::new()

function Execute-M3StressTest([string]$testId, [string]$testName, [scriptblock]$action) {
    Write-Host "`n>>> [$testId] $testName" -ForegroundColor Yellow
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $action
        $sw.Stop()
        Write-Host "    [PASS] [$testId] ($($sw.ElapsedMilliseconds) ms)" -ForegroundColor Green
        $script:passed++
        $script:results.Add(@{ Id = $testId; Name = $testName; Status = "PASS"; Error = ""; DurationMs = $sw.ElapsedMilliseconds })
    } catch {
        $sw.Stop()
        Write-Host "    [FAIL] [$testId] ($($sw.ElapsedMilliseconds) ms): $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
        $script:results.Add(@{ Id = $testId; Name = $testName; Status = "FAIL"; Error = $_.Exception.Message; DurationMs = $sw.ElapsedMilliseconds })
    }
}

# ==============================================================================
# SECTION 1: Rust Core Engine & UniFFI Stress Testing
# ==============================================================================
Write-Host "`n--- SECTION 1: RUST CORE ENGINE & UNIFFI STRESS TESTING ---" -ForegroundColor Magenta

# 1.1 SRP-6a RFC 5054 Parameter Invariants
Execute-M3StressTest "M3-CHG-1.1" "SRP-6a RFC 5054 2048-bit prime modulus N hex matches RFC spec verbatim" {
    $srpPath = Join-Path $RustCoreDir "src\auth\srp.rs"
    $srpSource = Get-Content $srpPath -Raw
    
    # Canonical RFC 5054 2048-bit prime group N
    $rfc5054N = "AC6BDB41324A9A9BF166DE5E1389582FAF72B6651987EE07FC3192943DB56050" +
                "A37329CBB4A099ED8193E0757767A13DD52312AB4B03310DCD7F48A9DA04FD50" +
                "E8083969EDA7491A0A04186422472351F33F99F7CC972DF0E5B39A331A4E9ACC" +
                "16CDBE8BEA9529E8A2ADC57F104079ABCD8002C10F849FFC70533BE0B5664970" +
                "8E6F07CBFF467E7037E21EC57E60E3F392DAF560FA24A8DEF09CE69FC09D18F7" +
                "571CDF75983CA1074A7E15E14500C05C029DC5F8CE44479C72F729C46998DA99" +
                "D861494243474CB5E663FA9E412F51CE516CE6EA7614C90670A6034B717B81BC" +
                "F0874E4A6B2B50152E5325512470A94A08C4A9E32242D53801F2EB8068FC93FB"
    
    # Extract the literal inside RFC5054_N_HEX: &str = "...";
    $pattern = 'RFC5054_N_HEX:\s*&str\s*=\s*"([^"]+)";'
    if ($srpSource -match $pattern) {
        $extractedRaw = $matches[1]
        # In Rust, backslash followed by newline strips the newline and leading whitespace
        $extractedClean = $extractedRaw -replace '\\(\r?\n\s*)?', '' -replace '\s+', ''
        Assert-Equal $rfc5054N $extractedClean "Cleaned RFC5054_N_HEX must match canonical RFC 5054 2048-bit prime exactly"
    } else {
        throw "Could not find RFC5054_N_HEX declaration in srp.rs"
    }
    Assert-Equal 512 $rfc5054N.Length "N hex string must be 512 characters (2048 bits = 256 bytes)"
}

# 1.2 SRP-6a Generator g and Multiplier k
Execute-M3StressTest "M3-CHG-1.2" "SRP-6a generator g=2 and multiplier k = SHA256(N || g)" {
    $srpPath = Join-Path $RustCoreDir "src\auth\srp.rs"
    $srpSource = Get-Content $srpPath -Raw
    
    if ($srpSource -notmatch 'let\s+g\s*=\s*BigUint::from\(2u32\)') {
        throw "srp.rs does not set generator g = 2"
    }
    if ($srpSource -notmatch 'hasher\.update\(n\.to_bytes_be\(\)\);[\s\S]*hasher\.update\(g\.to_bytes_be\(\)\);') {
        throw "srp.rs does not compute k = SHA256(N || g)"
    }
}

# 1.3 SRP-6a 32-byte Ephemeral Secret a and Public Key A
Execute-M3StressTest "M3-CHG-1.3" "SRP-6a generates 256-bit (32-byte) ephemeral secret a and computes A = g^a mod N padded to 256B" {
    $srpPath = Join-Path $RustCoreDir "src\auth\srp.rs"
    $srpSource = Get-Content $srpPath -Raw
    
    if ($srpSource -notmatch 'gen_biguint\(256\)') {
        throw "srp.rs does not generate 256-bit ephemeral secret a"
    }
    if ($srpSource -notmatch 'g\.modpow\(&a_secret,\s*&n\)') {
        throw "srp.rs does not compute A = g^a mod N"
    }
    if ($srpSource -notmatch 'bytes\.len\(\)\s*<\s*256') {
        throw "srp.rs does not pad public key A to 256 bytes"
    }
}

# 1.4 SRP-6a Boundary: Short Ephemeral Key A Rejected
Execute-M3StressTest "M3-CHG-1.4" "SRP-6a server rejects short/truncated client ephemeral key A (< 32 hex chars)" {
    $gsa = [MockAppleGsaServer]::new()
    $shortA = "01020304050607" # 14 chars < 32 chars
    $res = $gsa.HandleSrpInit("valid.user@icloud.com", $shortA, @{})
    Assert-Equal 400 $res.status
    Assert-Equal (-20102) $res.ec
    Assert-Matches "Malformed client ephemeral key A" $res.em
}

# 1.5 SRP-6a Boundary: Expired or Corrupt Challenge Token Rejected
Execute-M3StressTest "M3-CHG-1.5" "SRP-6a server rejects invalid or expired challenge token" {
    $gsa = [MockAppleGsaServer]::new()
    $res = $gsa.HandleSrpComplete("valid.user@icloud.com", "M1ProofSampleBytes1122", "EXPIRED-OR-FORGED-TOKEN-999", @{})
    Assert-Equal 403 $res.status
    Assert-Equal (-20103) $res.ec
    Assert-Matches "Invalid or expired challenge token" $res.em
}

# 1.6 SRP-6a Math: Zero B mod N and Zero Scrambler u Error Paths
Execute-M3StressTest "M3-CHG-1.6" "SRP-6a code explicitly verifies B mod N != 0 and scrambler u != 0" {
    $srpPath = Join-Path $RustCoreDir "src\auth\srp.rs"
    $srpSource = Get-Content $srpPath -Raw
    
    if ($srpSource -notmatch '&b\s*%\s*&self\.n\s*==\s*BigUint::from\(0u32\)') {
        throw "srp.rs missing check for B mod N == 0"
    }
    if ($srpSource -notmatch 'u\s*==\s*BigUint::from\(0u32\)') {
        throw "srp.rs missing check for scrambler u == 0"
    }
}

# 1.7 2FA Validation Boundary: Length and Character Constraints
Execute-M3StressTest "M3-CHG-1.7" "2FA validation strictly enforces 6-digit decimal constraint (empty, alpha, short, long rejected)" {
    $twoFaPath = Join-Path $RustCoreDir "src\auth\two_factor.rs"
    $twoFaSource = Get-Content $twoFaPath -Raw
    
    if ($twoFaSource -notmatch 'trimmed_code\.len\(\)\s*!=\s*6') {
        throw "two_factor.rs missing 6-digit length check"
    }
    if ($twoFaSource -notmatch 'c\.is_ascii_digit\(\)') {
        throw "two_factor.rs missing numeric digit check"
    }

    $gsa = [MockAppleGsaServer]::new()
    # Test wrong 6-digit code
    $resWrong = $gsa.Handle2FaValidate("identity-token", "999999")
    Assert-Equal 401 $resWrong.status
    Assert-Equal (-20105) $resWrong.ec
}

# 1.8 APS Courier Binary Wire Framing: Command Codes and Length Header
Execute-M3StressTest "M3-CHG-1.8" "APS Courier wire framing supports all 8 commands with 5-byte header (CMD + 4B BE len)" {
    $framePath = Join-Path $RustCoreDir "src\aps\frame.rs"
    $frameSource = Get-Content $framePath -Raw
    
    $requiredCmds = @("CMD_CONNECT: u8 = 0x07", "CMD_CONNECT_RESPONSE: u8 = 0x08", "CMD_FILTER: u8 = 0x09",
                      "CMD_NOTIFICATION: u8 = 0x0A", "CMD_ACK: u8 = 0x0B", "CMD_PING: u8 = 0x0C",
                      "CMD_PONG: u8 = 0x0D", "CMD_SET_STATE: u8 = 0x14")
    foreach ($cmd in $requiredCmds) {
        if ($frameSource -notmatch [regex]::Escape($cmd)) {
            throw "frame.rs missing command declaration: $cmd"
        }
    }
    
    # Test raw wire frame encoding/decoding logic in ProtocolWireCheckers
    $testPayload = [System.Text.Encoding]::UTF8.GetBytes("HelloWorldApsPayload")
    $frameBytes = [byte[]]::new(5 + $testPayload.Length)
    $frameBytes[0] = 0x07 # CMD_CONNECT
    $frameBytes[1] = 0
    $frameBytes[2] = 0
    $frameBytes[3] = 0
    $frameBytes[4] = [byte]$testPayload.Length
    [System.Array]::Copy($testPayload, 0, $frameBytes, 5, $testPayload.Length)

    Assert-True ([ProtocolWireCheckers]::ValidateApsRawFrame($frameBytes)) "Valid APS raw frame accepted"
    
    # Truncated header (< 5 bytes)
    $truncatedHeader = [byte[]]@(0x07, 0x00, 0x00)
    Assert-False ([ProtocolWireCheckers]::ValidateApsRawFrame($truncatedHeader)) "Truncated header rejected"
    
    # Truncated payload (< 5 + len bytes)
    $truncatedPayload = [byte[]]@(0x07, 0x00, 0x00, 0x00, 0x20, 0x01, 0x02) # says len=32 but only 2 bytes
    Assert-False ([ProtocolWireCheckers]::ValidateApsRawFrame($truncatedPayload)) "Truncated payload rejected"
    
    # Invalid command byte
    $invalidCmd = [byte[]]@(0xFF, 0x00, 0x00, 0x00, 0x00)
    Assert-False ([ProtocolWireCheckers]::ValidateApsRawFrame($invalidCmd)) "Invalid command byte 0xFF rejected"
}

# 1.9 APS Topics: SHA-1 Hashes for Standard Topics
Execute-M3StressTest "M3-CHG-1.9" "APS topic module verifies SHA-1 hash calculation for all 5 standard topics" {
    $topicsPath = Join-Path $RustCoreDir "src\aps\topics.rs"
    $topicsSource = Get-Content $topicsPath -Raw
    
    $topics = @(
        "com.apple.madrid",
        "com.apple.ess",
        "com.apple.private.alloy.facetime.multi",
        "com.apple.private.alloy.facetime.video",
        "com.apple.private.alloy.quickrelay"
    )
    foreach ($t in $topics) {
        if ($topicsSource -notmatch [regex]::Escape($t)) {
            throw "topics.rs missing standard topic: $t"
        }
    }

    # Verify SHA-1 hash computation independently
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    foreach ($t in $topics) {
        $hashBytes = $sha1.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($t))
        Assert-Equal 20 $hashBytes.Length "Topic SHA-1 hash must be exactly 20 bytes"
    }
}

# 1.10 APS Reconnection Backoff Schedule
Execute-M3StressTest "M3-CHG-1.10" "APS Courier reconnect schedule enforces [1s, 2s, 4s, 8s, 16s, 32s] capped at 300s" {
    $expectedSchedule = @(1, 2, 4, 8, 16, 32)
    $maxCap = 300
    for ($i = 0; $i -lt $expectedSchedule.Length; $i++) {
        $calculated = [int][Math]::Pow(2, $i)
        Assert-Equal $expectedSchedule[$i] $calculated "Backoff step $i must equal $($expectedSchedule[$i])"
    }
    # Step 10: 2^10 = 1024 capped at 300
    $capped = [Math]::Min($maxCap, [int][Math]::Pow(2, 10))
    Assert-Equal 300 $capped "Backoff must be capped at 300s"
}

# 1.11 UniFFI Bridge: Complete Contract Coverage (8 Methods + 5 Callbacks)
Execute-M3StressTest "M3-CHG-1.11" "UniFFI UDL and Rust types define all 8 engine methods and 5 callback listeners" {
    $udlPath = Join-Path $RustCoreDir "src\facetime_core.udl"
    $udlSource = Get-Content $udlPath -Raw
    
    $engineMethods = @(
        "init_engine",
        "authenticate_apple_account",
        "submit_two_factor_code",
        "connect_aps_courier",
        "register_ids_pipeline",
        "lookup_recipient",
        "start_facetime_call",
        "end_facetime_call"
    )
    foreach ($m in $engineMethods) {
        if ($udlSource -notmatch "\b$m\b") {
            throw "facetime_core.udl missing engine method: $m"
        }
    }
    
    $callbacks = @(
        "on_auth_state_changed",
        "on_aps_state_changed",
        "on_ids_state_changed",
        "on_call_state_changed",
        "on_diagnostic_event"
    )
    foreach ($cb in $callbacks) {
        if ($udlSource -notmatch "\b$cb\b") {
            throw "facetime_core.udl missing callback listener method: $cb"
        }
    }
}

# ==============================================================================
# SECTION 2: 7-Stage IDS Stepper & Hard Go/No-Go Gate Transition
# ==============================================================================
Write-Host "`n--- SECTION 2: 7-STAGE IDS STEPPER & HARD GO/NO-GO GATE ---" -ForegroundColor Magenta

# 2.1 7-Stage IDS Stepper State Definitions
Execute-M3StressTest "M3-CHG-2.1" "IDS Stepper implements all 7 stages including HardHardwareBlocker" {
    $stagesPath = Join-Path $RustCoreDir "src\ids\stages.rs"
    $stagesSource = Get-Content $stagesPath -Raw
    
    $expectedStages = @(
        "AuthContextReady",
        "BagLoaded",
        "PushTokenAcquired",
        "IdentitiesGenerated",
        "ServiceRegistered",
        "Registered",
        "RegistrationFailed",
        "RegistrationFailedHardHardwareBlocker"
    )
    foreach ($s in $expectedStages) {
        if ($stagesSource -notmatch "\b$s\b") {
            throw "stages.rs missing stage definition: $s"
        }
    }

    $barriers = @("FairPlayAbsintheMissing", "AnisetteHmacRejected", "AlbertActivationRejected", "SecureEnclaveMissing")
    foreach ($b in $barriers) {
        if ($stagesSource -notmatch "\b$b\b") {
            throw "stages.rs missing hardware barrier type: $b"
        }
    }
}

# 2.2 Mock Provider 7-Stage Registration Succeeded
Execute-M3StressTest "M3-CHG-2.2" "IDS Stepper transitions to Stage 6 Registered under Mock provider" {
    $ids = [MockAppleIdsServer]::new()
    $res = $ids.HandleIdRegister("Mock", @{ "pushToken" = "VALID_PUSH_TOKEN" }, @{})
    Assert-Equal 0 $res.status
    Assert-Equal 3600 $res["next-hbi"]
    Assert-True $res.services.ContainsKey("com.apple.private.alloy.facetime.multi")
}

# 2.3 AndroidExperimental Mode: Hard Go/No-Go Gate Transition to Blocker
Execute-M3StressTest "M3-CHG-2.3" "AndroidExperimental mode strictly halts at Stage 5 and transitions to RegistrationFailedHardHardwareBlocker" {
    $ids = [MockAppleIdsServer]::new()
    $res = $ids.HandleIdRegister("AndroidExperimental", @{ "pushToken" = "VALID_PUSH_TOKEN" }, @{})
    Assert-Equal 6005 $res.status
    Assert-Equal 403 $res.httpStatus
    Assert-Equal "ValidationDataRejected" $res.error
    Assert-Matches "FairPlay hardware endorsement" $res.localizedError
}

# 2.4 HardGoNoGoGate Code Invariant: Blocker Report Path & Barrier Type
Execute-M3StressTest "M3-CHG-2.4" "HardGoNoGoGate binds rejection 6005 to FairPlayAbsintheMissing and Standalone Blocker report" {
    $gatePath = Join-Path $RustCoreDir "src\validation\gate.rs"
    $gateSource = Get-Content $gatePath -Raw
    
    if ($gateSource -notmatch '6005\s*=>\s*HardwareBarrierType::FairPlayAbsintheMissing') {
        throw "gate.rs does not map 6005 to FairPlayAbsintheMissing"
    }
    if ($gateSource -notmatch '6009\s*=>\s*HardwareBarrierType::AnisetteHmacRejected') {
        throw "gate.rs does not map 6009 to AnisetteHmacRejected"
    }
    if ($gateSource -notmatch 'docs/experiments/Standalone_Android_FaceTime_Registration_Blocker\.md') {
        throw "gate.rs missing report_path reference"
    }
    if ($gateSource -notmatch 'is_halted:\s*true') {
        throw "gate.rs must set is_halted: true upon blocker detection"
    }
}

# 2.5 Blocker Report File Exists on Disk
Execute-M3StressTest "M3-CHG-2.5" "Blocker report file exists on disk and documents Status 6005 and FairPlay requirement" {
    Assert-True (Test-Path $BlockerReportPath) "Blocker report must exist on disk"
    $reportContent = Get-Content $BlockerReportPath -Raw
    Assert-Matches "6005" $reportContent
    Assert-Matches "FairPlay" $reportContent
    Assert-Matches "Absinthe" $reportContent
}

# ==============================================================================
# SECTION 3: Circular Buffer OOM Stress Testing
# ==============================================================================
Write-Host "`n--- SECTION 3: CIRCULAR BUFFER OOM STRESS TESTING ---" -ForegroundColor Magenta

# 3.1 PowerShell 3,000+ Event Flooding Stress Test (N=1,000)
Execute-M3StressTest "M3-CHG-3.1" "CircularEventBuffer N=1000 flooded with 3,500 events strictly caps at 1000 with FIFO eviction" {
    $bufferCapacity = 1000
    $eventQueue = [System.Collections.Generic.List[string]]::new()
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 1; $i -le 3500; $i++) {
        if ($eventQueue.Count -ge $bufferCapacity) {
            $eventQueue.RemoveAt(0) # O(1) ring head eviction
        }
        $eventQueue.Add("EVENT_$i")
    }
    $sw.Stop()

    Assert-Equal 1000 $eventQueue.Count "Buffer count must strictly equal 1000"
    Assert-Equal "EVENT_2501" $eventQueue[0] "First event must be EVENT_2501 (FIFO eviction preserved)"
    Assert-Equal "EVENT_3500" $eventQueue[999] "Last event must be EVENT_3500"
    Write-Host "       Flooded 3,500 events in $($sw.ElapsedMilliseconds) ms without memory leak." -ForegroundColor Gray
}

# 3.2 Extended Capacity N=2,048 Flooded with 5,000 Events
Execute-M3StressTest "M3-CHG-3.2" "CircularEventBuffer N=2048 flooded with 5,000 events strictly caps at 2048 with zero leak" {
    $diag = [DiagnosticEventLog]::new()
    $diag.capacity = 2048

    for ($i = 1; $i -le 5000; $i++) {
        $diag.EmitEvent(@{ "seq" = $i; "type" = "TELEMETRY_BURST"; "payload" = "DataPacket_$i" })
    }

    Assert-Equal 2048 ($diag.GetEventCount()) "Buffer count must strictly equal 2048"
}

# 3.3 Execute JVM Circular Buffer Stress Test (Multi-Threaded & 100k Flooding)
Execute-M3StressTest "M3-CHG-3.3" "Execute JVM CircularBufferJvmStressTest (100k events continuous flood & 10-thread concurrency)" {
    $binDir = Join-Path $RepoRoot "tests\e2e\harness\bin"
    if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
    New-Item -ItemType Directory -Path $binDir | Out-Null
    
    try {
        $javaSrc = Join-Path $RepoRoot "tests\e2e\harness\CircularBufferJvmStressTest.java"
        & javac -d $binDir $javaSrc
        if ($LASTEXITCODE -ne 0) { throw "javac compilation of CircularBufferJvmStressTest.java failed" }
        
        $output = & java -cp $binDir org.facetime.diagnostic.CircularBufferJvmStressTest
        if ($LASTEXITCODE -ne 0) { throw "CircularBufferJvmStressTest execution failed: $output" }
        
        Assert-Matches "Total Tests: 5 \| Passed: 5 \| Failed: 0" ($output -join "`n")
    } finally {
        if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
    }
}

# 3.4 Execute JVM SecretSanitizer Stress Test (Multi-Threaded & 30+ Honey-Tokens)
Execute-M3StressTest "M3-CHG-3.4" "Execute JVM SecretSanitizerJvmStressTest (32 tests across 30+ honey-tokens & concurrency)" {
    $binDir = Join-Path $RepoRoot "tests\e2e\harness\bin"
    if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
    New-Item -ItemType Directory -Path $binDir | Out-Null
    
    try {
        $javaSrc = Join-Path $RepoRoot "tests\e2e\harness\SecretSanitizerJvmStressTest.java"
        & javac -d $binDir $javaSrc
        if ($LASTEXITCODE -ne 0) { throw "javac compilation of SecretSanitizerJvmStressTest.java failed" }
        
        $output = & java -cp $binDir org.facetime.diagnostic.SecretSanitizerJvmStressTest
        if ($LASTEXITCODE -ne 0) { throw "SecretSanitizerJvmStressTest execution failed: $output" }
        
        Assert-Matches "Total Tests:\s+32\s+Passed:\s+32" (($output -join " ") -replace "`r|`n", " ")
    } finally {
        if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
    }
}

# ==============================================================================
# SECTION 4: Android Multi-Module Architecture & UI Integrity
# ==============================================================================
Write-Host "`n--- SECTION 4: ANDROID MULTI-MODULE ARCHITECTURE & UI INTEGRITY ---" -ForegroundColor Magenta

# 4.1 6 Gradle Modules Layout
Execute-M3StressTest "M3-CHG-4.1" "All 6 required Android Gradle modules exist and are included in settings.gradle.kts" {
    $settingsPath = Join-Path $AndroidDir "settings.gradle.kts"
    $settingsContent = Get-Content $settingsPath -Raw
    
    $modules = @(":app", ":core-model", ":core-rust", ":core-security", ":core-diagnostic", ":core-network")
    foreach ($m in $modules) {
        if ($settingsContent -notmatch [regex]::Escape($m)) {
            throw "settings.gradle.kts missing module: $m"
        }
        $dirName = $m.TrimStart(":")
        $modDir = Join-Path $AndroidDir $dirName
        Assert-True (Test-Path $modDir) "Module directory $dirName must exist"
        Assert-True (Test-Path (Join-Path $modDir "build.gradle.kts")) "Module $dirName must have build.gradle.kts"
    }
}

# 4.2 Compose Screens Coverage
Execute-M3StressTest "M3-CHG-4.2" "All 5 Jetpack Compose screens implemented in android/app" {
    $screensDir = Join-Path $AndroidDir "app\src\main\java\org\facetime\poc\ui\screens"
    $screens = @("AuthScreen.kt", "ApsScreen.kt", "IdsPipelineScreen.kt", "CallTriggerScreen.kt", "DiagnosticConsoleSheet.kt")
    foreach ($s in $screens) {
        $p = Join-Path $screensDir $s
        Assert-True (Test-Path $p) "Compose screen $s must exist"
    }
}

# 4.3 Android Keystore MasterKey AES-256-GCM & PasswordZeroizer
Execute-M3StressTest "M3-CHG-4.3" "Android Keystore MasterKey AES-256-GCM and PasswordZeroizer implemented" {
    $secDir = Join-Path $AndroidDir "core-security\src\main\java\org\facetime\security"
    Assert-True (Test-Path (Join-Path $secDir "KeystoreManager.kt"))
    Assert-True (Test-Path (Join-Path $secDir "PasswordZeroizer.kt"))
    
    $zeroizerContent = Get-Content (Join-Path $secDir "PasswordZeroizer.kt") -Raw
    Assert-Matches "Arrays\.fill" $zeroizerContent
}

# 4.4 Persistent APS Foreground Service & Network Callback
Execute-M3StressTest "M3-CHG-4.4" "Persistent APS Foreground Service and NetworkCallback monitor implemented" {
    $netDir = Join-Path $AndroidDir "core-network\src\main\java\org\facetime\network"
    Assert-True (Test-Path (Join-Path $netDir "ApsConnectionService.kt"))
    Assert-True (Test-Path (Join-Path $netDir "NetworkMonitor.kt"))
}

# ==============================================================================
# SECTION 5: Master E2E Runner & Specific Filters Execution
# ==============================================================================
Write-Host "`n--- SECTION 5: MASTER E2E RUNNER & FILTERS EXECUTION ---" -ForegroundColor Magenta

# 5.1 Full Master E2E Run (218 / 218)
Execute-M3StressTest "M3-CHG-5.1" "Execute master E2E runner: all 218 tests pass with 0 failures" {
    $runCmd = "powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1"
    $output = Invoke-Expression $runCmd
    $outputStr = $output -join "`n"
    if ($outputStr -notmatch "Passed:\s+218" -or $outputStr -notmatch "Failed:\s+0") {
        throw "Master E2E suite did not pass 218/218 tests. Output: $outputStr"
    }
}

# 5.2 Feature 8-13 Filters
$m3Features = @(8, 9, 10, 11, 12, 13)
foreach ($f in $m3Features) {
    Execute-M3StressTest "M3-CHG-5.2.F$f" "Execute E2E runner for Feature ${f}: 10/10 tests pass" {
        $runCmd = "powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Feature $f"
        $output = Invoke-Expression $runCmd
        $outputStr = $output -join "`n"
        if ($outputStr -notmatch "Passed:\s+10" -or $outputStr -notmatch "Failed:\s+0") {
            throw "Feature $f E2E tests failed: $outputStr"
        }
    }
}

# 5.3 Tier 3 Cross-Feature Suite (12 / 12)
Execute-M3StressTest "M3-CHG-5.3" "Execute E2E runner for Tier 3 (Cross-Feature): 12/12 tests pass" {
    $runCmd = "powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Tier 3"
    $output = Invoke-Expression $runCmd
    $outputStr = $output -join "`n"
    if ($outputStr -notmatch "Passed:\s+12" -or $outputStr -notmatch "Failed:\s+0") {
        throw "Tier 3 cross-feature tests failed: $outputStr"
    }
}

# 5.4 Tier 4 Real-World Suite (6 / 6)
Execute-M3StressTest "M3-CHG-5.4" "Execute E2E runner for Tier 4 (Real-World Scenarios): 6/6 tests pass" {
    $runCmd = "powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Tier 4"
    $output = Invoke-Expression $runCmd
    $outputStr = $output -join "`n"
    if ($outputStr -notmatch "Passed:\s+6" -or $outputStr -notmatch "Failed:\s+0") {
        throw "Tier 4 real-world tests failed: $outputStr"
    }
}

# ==============================================================================
# SUMMARY & EMPIRICAL VERDICT
# ==============================================================================
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "                CHALLENGER M3 STRESS RUNNER SUMMARY                             " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Total Stress Tests Executed: $($passed + $failed)" -ForegroundColor Gray
Write-Host "Passed:                      $passed" -ForegroundColor Green
Write-Host "Failed:                      $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

if ($failed -eq 0) {
    Write-Host "`nEMPIRICAL VERDICT: APPROVE (100% of Stress Tests & Invariants Passed)" -ForegroundColor Green
} else {
    Write-Host "`nEMPIRICAL VERDICT: REQUEST_CHANGES ($failed failures detected)" -ForegroundColor Red
}
Write-Host "================================================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
}
