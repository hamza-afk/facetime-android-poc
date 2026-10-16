# TestAssertions.ps1
# Opaque-box assertion library and verification helpers for FaceTime Android PoC E2E suite

class TestFailureException : System.Exception {
    TestFailureException([string]$message) : base($message) {}
}

function Assert-True([bool]$condition, [string]$message = "Expected true but got false") {
    if (-not $condition) {
        throw [TestFailureException]::new($message)
    }
}

function Assert-False([bool]$condition, [string]$message = "Expected false but got true") {
    if ($condition) {
        throw [TestFailureException]::new($message)
    }
}

function Assert-Equal($expected, $actual, [string]$message = "") {
    if ($null -eq $expected -and $null -eq $actual) { return }
    if ($expected -ne $actual) {
        $detail = if ($message) { "$message : " } else { "" }
        throw [TestFailureException]::new("${detail}Expected: <$expected>, Actual: <$actual>")
    }
}

function Assert-NotEqual($expected, $actual, [string]$message = "") {
    if ($expected -eq $actual) {
        $detail = if ($message) { "$message : " } else { "" }
        throw [TestFailureException]::new("${detail}Did not expect: <$expected>, but got equal value")
    }
}

function Assert-Matches([string]$pattern, [string]$text, [string]$message = "") {
    if ($text -notmatch $pattern) {
        $detail = if ($message) { "$message : " } else { "" }
        throw [TestFailureException]::new("${detail}Text does not match pattern <$pattern>. Text was: <$text>")
    }
}

function Assert-Contains($item, $collection, [string]$message = "") {
    $found = $false
    if ($collection -is [string]) {
        $found = $collection.Contains($item)
    } elseif ($collection -is [System.Collections.IEnumerable]) {
        foreach ($c in $collection) {
            if ($c -eq $item) { $found = $true; break }
        }
    }
    if (-not $found) {
        $detail = if ($message) { "$message : " } else { "" }
        throw [TestFailureException]::new("${detail}Item <$item> not found in collection")
    }
}

function Assert-NotContains($item, $collection, [string]$message = "") {
    $found = $false
    if ($collection -is [string]) {
        $found = $collection.Contains($item)
    } elseif ($collection -is [System.Collections.IEnumerable]) {
        foreach ($c in $collection) {
            if ($c -eq $item) { $found = $true; break }
        }
    }
    if ($found) {
        $detail = if ($message) { "$message : " } else { "" }
        throw [TestFailureException]::new("${detail}Item <$item> unexpectedly found in collection")
    }
}

function Assert-Throws([scriptblock]$action, [string]$expectedMessagePattern = "", [string]$message = "") {
    $threw = $false
    try {
        & $action
    } catch {
        $threw = $true
        if ($expectedMessagePattern) {
            if ($_.Exception.Message -notmatch $expectedMessagePattern) {
                throw [TestFailureException]::new("Caught expected exception, but message '$($_.Exception.Message)' did not match pattern '$expectedMessagePattern'")
            }
        }
    }
    if (-not $threw) {
        $detail = if ($message) { "$message : " } else { "" }
        throw [TestFailureException]::new("${detail}Expected scriptblock to throw exception, but it succeeded")
    }
}

# Asserts that a plist or dictionary PDU contains all required fields and valid types
function Assert-WirePduValid([hashtable]$pdu, [string[]]$requiredKeys, [string]$pduName = "PDU") {
    foreach ($key in $requiredKeys) {
        if (-not $pdu.ContainsKey($key)) {
            throw [TestFailureException]::new("$pduName missing mandatory protocol key: '$key'")
        }
        if ($null -eq $pdu[$key]) {
            throw [TestFailureException]::new("$pduName key '$key' has null value")
        }
    }
}

# Asserts that text or data structure contains ZERO unredacted sensitive tokens, passwords, or keys
function Assert-Redacted([string]$content) {
    $sensitivePatterns = @(
        'password\s*[:=]\s*["''][^"''\s]{4,}["'']',
        'com\.apple\.gs\.idms\.pet\s*[:=]\s*["''][^"''\s]{16,}["'']',
        'PET-[0-9a-zA-Z]{32,}',
        '-----BEGIN RSA PRIVATE KEY-----',
        '-----BEGIN EC PRIVATE KEY-----',
        '-----BEGIN PRIVATE KEY-----',
        'security-code\s*[:=]\s*["''][0-9]{6}["'']'
    )
    foreach ($pat in $sensitivePatterns) {
        if ($content -match $pat) {
            throw [TestFailureException]::new("Security Invariant Violated: Unredacted sensitive credential matched pattern: $pat")
        }
    }
}

# Asserts clean-room compliance: zero genuine Apple hardware serials or donor certificates
function Assert-CleanRoomCompliance([hashtable]$headers, [string]$sourceCode = "") {
    $appleSerialPattern = '^[A-Z0-9]{10,12}$' # Typical 12-char Apple serial e.g. C02X1234JHC8
    if ($headers.ContainsKey("X-Apple-I-SRL-NO")) {
        $serial = $headers["X-Apple-I-SRL-NO"]
        if ($serial -match $appleSerialPattern -and $serial -notmatch 'MOCK|SYNTHETIC|ANDROID') {
            throw [TestFailureException]::new("Anti-Cheating Failure: Genuine Apple serial number detected in headers: $serial")
        }
    }
    if ($sourceCode -match '-----BEGIN CERTIFICATE-----[\s\S]*?Apple Inc\.') {
        throw [TestFailureException]::new("Anti-Cheating Failure: Embedded genuine Apple certificate found in source code")
    }
}

# Asserts valid state machine transition
function Assert-ValidTransition([string]$currentState, [string]$nextState, [hashtable]$allowedTransitions) {
    if (-not $allowedTransitions.ContainsKey($currentState)) {
        throw [TestFailureException]::new("State machine error: Unknown current state '$currentState'")
    }
    $validNext = $allowedTransitions[$currentState]
    if ($validNext -notcontains $nextState) {
        $validStr = ($validNext -join ", ")
        throw [TestFailureException]::new("Invalid state transition from '$currentState' to '$nextState'. Valid target states: [$validStr]")
    }
}
