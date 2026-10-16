# ProtocolWireCheckers.ps1
# Wire-level protocol format validators, frame inspectors, and schema checkers

class ProtocolWireCheckers {

    # Validates raw APS binary frame structure
    static [bool] ValidateApsRawFrame([byte[]]$frameBytes) {
        if ($null -eq $frameBytes -or $frameBytes.Length -lt 5) {
            return $false
        }
        $cmd = $frameBytes[0]
        # Valid APS commands: 0x07 (Connect), 0x08 (ConnectResponse), 0x09 (Filter), 0x0A (Notification), 0x0B (Ack), 0x0C (Ping), 0x0D (Pong), 0x14 (SetState)
        $validCmds = @(0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x14)
        if ($validCmds -notcontains $cmd) {
            return $false
        }
        # Big-endian length
        $payloadLen = ([int]$frameBytes[1] -shl 24) -bor ([int]$frameBytes[2] -shl 16) -bor ([int]$frameBytes[3] -shl 8) -bor [int]$frameBytes[4]
        if ($frameBytes.Length -ne (5 + $payloadLen)) {
            return $false
        }
        return $true
    }

    # Validates packed APS frame (apns-pack-v1 ALPN)
    static [bool] ValidateApsPackedFrame([byte[]]$frameBytes) {
        if ($null -eq $frameBytes -or $frameBytes.Length -lt 2) {
            return $false
        }
        $cmd = $frameBytes[0]
        # In apns-pack-v1, length is variable-length integer
        return $cmd -ge 0x01 -and $cmd -le 0x20
    }

    # Validates FTWireMessage plist structure for command 207 Invite
    static [bool] ValidateFTWireMessageInvite([hashtable]$msg) {
        $requiredKeys = @(
            "s",                            # Group UUID
            "fanout-groupID-key",           # Group UUID
            "is-initiator-key",             # Boolean true
            "join_notification_key",        # Integer 1 (Invite)
            "participant-id-key",           # Integer participant ID
            "fanout-groupMembers-key",      # Array of URIs
            "participant_data_key",         # Media negotiation blob
            "client_context_data_key"       # Protobuf join context
        )
        foreach ($k in $requiredKeys) {
            if (-not $msg.ContainsKey($k)) {
                return $false
            }
        }
        if ($msg["join_notification_key"] -ne 1) {
            return $false # 1 = Invite, 2 = Leave
        }
        if ($msg["is-initiator-key"] -ne $true) {
            return $false
        }
        return $true
    }

    # Validates FTWireMessage plist structure for command 208 Leave
    static [bool] ValidateFTWireMessageLeave([hashtable]$msg) {
        if (-not $msg.ContainsKey("s") -or -not $msg.ContainsKey("join_notification_key")) {
            return $false
        }
        return $msg["join_notification_key"] -eq 2 # 2 = Leave
    }

    # Validates IDS Multi-Key Header Signatures
    static [bool] ValidateIdsRequestHeaders([hashtable]$headers) {
        $reqHeaders = @(
            "x-protocol-version",
            "x-push-token",
            "x-push-nonce",
            "x-push-sig",
            "x-push-cert"
        )
        foreach ($h in $reqHeaders) {
            if (-not $headers.ContainsKey($h) -or [string]::IsNullOrEmpty($headers[$h])) {
                return $false
            }
        }
        # Nonce must be 17 bytes base64 encoded (min 24 chars)
        if ($headers["x-push-nonce"].Length -lt 24) {
            return $false
        }
        return $true
    }

    # Validates DeviceValidationProvider contract output
    static [bool] ValidateProviderOutput([string]$providerType, [hashtable]$headers, [byte[]]$validationData) {
        if ($providerType -eq "Mock") {
            # Must contain MOCK_MODE flag
            return ($headers.ContainsKey("X-Validation-Mode") -and $headers["X-Validation-Mode"] -eq "MOCK_MODE")
        } elseif ($providerType -eq "AndroidExperimental") {
            # Must NOT contain genuine Apple serial or donor certificates
            if ($headers.ContainsKey("X-Apple-I-SRL-NO")) {
                $srl = $headers["X-Apple-I-SRL-NO"]
                if ($srl -notmatch 'ANDROID|CLEANROOM') { return $false }
            }
            return ($null -ne $validationData -and $validationData.Length -gt 0)
        } elseif ($providerType -eq "ExistingRustpush") {
            return ($null -ne $validationData -and $validationData.Length -gt 0)
        }
        return $false
    }
}
