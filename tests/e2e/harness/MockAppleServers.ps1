# MockAppleServers.ps1
# High-fidelity Apple GSA, APS, and IDS mock service simulation engine
# Strictly derived from spec_report.md and PROJECT.md wire formats

class MockAppleGsaServer {
    [hashtable]$accounts = @{
        "valid.user@icloud.com" = @{
            "password" = "CorrectPassword123!";
            "dsid" = 1892837492;
            "adsid" = "W1892837492";
            "pet" = "PET-a1b2c3d4e5f60718293a4b5c6d7e8f90";
            "valid2fa" = "123456";
        }
    }
    [string]$currentChallenge = "CHALLENGE-TOKEN-778899"

    [hashtable] HandleSrpInit([string]$username, [string]$clientEphemeralA, [hashtable]$cpd) {
        if (-not $this.accounts.ContainsKey($username)) {
            return @{ "status" = 401; "ec" = -20101; "em" = "Authentication Failed: User not found" }
        }
        if ([string]::IsNullOrEmpty($clientEphemeralA) -or $clientEphemeralA.Length -lt 32) {
            return @{ "status" = 400; "ec" = -20102; "em" = "Malformed client ephemeral key A" }
        }
        # Server ephemeral B, salt s, PBKDF2 iterations i, challenge c
        return @{
            "status" = 200;
            "ec" = 0;
            "B" = "B99887766554433221100FFEEDDCCBBAA";
            "s" = "sAltVAluE1234567890abcdef";
            "i" = 2048;
            "c" = $this.currentChallenge;
            "sp" = "s2k_fo";
        }
    }

    [hashtable] HandleSrpComplete([string]$username, [string]$clientProofM1, [string]$challengeToken, [hashtable]$cpd) {
        if ($challengeToken -ne $this.currentChallenge) {
            return @{ "status" = 403; "ec" = -20103; "em" = "Invalid or expired challenge token" }
        }
        if ([string]::IsNullOrEmpty($clientProofM1) -or $clientProofM1.Length -lt 16) {
            return @{ "status" = 401; "ec" = -20104; "em" = "Bad client proof M1" }
        }
        $acc = $this.accounts[$username]
        return @{
            "status" = 200;
            "ec" = 0;
            "M2" = "M2ProofServerVerified998877";
            "spd" = "AES256EncryptedServiceProvisioningDataBlock";
            "au" = "trustedDeviceSecondaryAuth";
            "adsid" = $acc.adsid;
            "dsid" = $acc.dsid;
        }
    }

    [hashtable] Handle2FaValidate([string]$identityToken, [string]$securityCode) {
        if ($securityCode -ne "123456") {
            return @{ "status" = 401; "ec" = -20105; "em" = "Bad 2FA verification code" }
        }
        return @{
            "status" = 200;
            "ec" = 0;
            "X-Apple-GS-Token" = "GS-TOKEN-LongLivedSession-8877";
            "X-Apple-HB-Token" = "HB-TOKEN-Heartbeat-6655";
            "X-Apple-PE-Token" = "PET-a1b2c3d4e5f60718293a4b5c6d7e8f90";
            "dsid" = 1892837492;
        }
    }

    [hashtable] HandleDelegateLogin([string]$petToken) {
        if ($petToken -notlike "PET-*") {
            return @{ "status" = 401; "ec" = -20106; "em" = "Unauthorized PET token" }
        }
        return @{
            "status" = 200;
            "ec" = 0;
            "delegates" = @{
                "com.apple.private.ids" = @{
                    "auth_token" = "IDS-AUTH-TOKEN-99228811";
                    "profile_id" = "PROFILE-DSID-1892837492";
                };
                "com.apple.mobileme" = @{
                    "auth_token" = "MOBILEME-TOKEN-443322";
                }
            }
        }
    }
}

class MockAppleApsCourier {
    [bool]$isConnected = $false
    [string]$assignedPushToken = "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"
    [System.Collections.ArrayList]$registeredTopics = [System.Collections.ArrayList]::new()
    [int]$lastMessageId = 1000

    [hashtable] HandleConnectFrame([byte]$command, [hashtable]$attributes) {
        if ($command -ne 0x07) {
            return @{ "status" = 1; "error" = "Invalid command byte: expected 0x07 Connect" }
        }
        # Required attributes: attr 5 (flags), attr 12 (cert), attr 13 (nonce), attr 14 (sig)
        if (-not $attributes.ContainsKey(12) -or -not $attributes.ContainsKey(13) -or -not $attributes.ContainsKey(14)) {
            return @{ "status" = 2; "error" = "Missing required connect frame security attributes" }
        }
        $this.isConnected = $true
        # Return 0x08 ConnectResponse
        return @{
            "command" = 0x08;
            "status" = 0; # Success
            "pushToken" = $this.assignedPushToken;
        }
    }

    [hashtable] HandleFilterFrame([byte]$command, [hashtable]$attributes) {
        if ($command -ne 0x09) {
            return @{ "status" = 1; "error" = "Expected 0x09 Filter frame" }
        }
        if (-not $this.isConnected) {
            return @{ "status" = 3; "error" = "Cannot filter topics: connection not established" }
        }
        if ($attributes.ContainsKey(2)) {
            $topics = $attributes[2]
            foreach ($t in $topics) {
                if (-not $this.registeredTopics.Contains($t)) {
                    [void]$this.registeredTopics.Add($t)
                }
            }
        }
        return @{ "command" = 0x09; "status" = 0; "registeredCount" = $this.registeredTopics.Count }
    }

    [hashtable] HandlePingFrame([byte]$command) {
        if ($command -ne 0x0C) {
            return @{ "status" = 1; "error" = "Expected 0x0C Ping frame" }
        }
        return @{ "command" = 0x0D; "status" = 0; "type" = "Pong" }
    }
}

class MockAppleIdsServer {
    [hashtable] HandleIdAuthenticate([string]$authToken, [string]$csrPem) {
        if ([string]::IsNullOrEmpty($authToken)) {
            return @{ "status" = 6001; "error" = "Missing IDS auth token" }
        }
        return @{
            "status" = 0;
            "authCert" = "-----BEGIN CERTIFICATE-----`nMIICMockIdsAuthCertificateData`n-----END CERTIFICATE-----";
            "userDsid" = 1892837492;
        }
    }

    [hashtable] HandleIdGetHandles([string]$userDsid) {
        return @{
            "status" = 0;
            "handles" = @(
                @{ "uri" = "mailto:valid.user@icloud.com"; "status" = "active"; "primary" = $true },
                @{ "uri" = "tel:+15555550199"; "status" = "active"; "primary" = $false }
            )
        }
    }

    [hashtable] HandleIdRegister([string]$providerType, [hashtable]$validationData, [hashtable]$publicIdentities) {
        # Hard Go/No-Go rule check:
        if ($providerType -eq "AndroidExperimental") {
            # Apple server rejects clean Android validation data
            return @{
                "status" = 6005;
                "error" = "ValidationDataRejected";
                "localizedError" = "Your device could not be registered with Apple Identity Services (Missing FairPlay hardware endorsement)";
                "httpStatus" = 403;
            }
        }
        if ($providerType -eq "Mock" -or $providerType -eq "ExistingRustpush") {
            return @{
                "status" = 0;
                "next-hbi" = 3600;
                "services" = @{
                    "com.apple.madrid" = @{ "cert" = "MOCK-MADRID-CERT"; "status" = "active" };
                    "com.apple.ess" = @{ "cert" = "MOCK-ESS-CERT"; "status" = "active" };
                    "com.apple.private.alloy.facetime.multi" = @{ "cert" = "MOCK-FT-MULTI-CERT"; "status" = "active" };
                };
            }
        }
        return @{ "status" = 6009; "error" = "UnknownProvider" }
    }

    [hashtable] HandleIdQuery([string]$recipientUri) {
        if ($recipientUri -eq "mailto:recipient@example.com" -or $recipientUri -eq "tel:+15555550100") {
            return @{
                "status" = 0;
                "results" = @{
                    $recipientUri = @{
                        "sender-correlation-identifier" = "UUID-CORR-11223344";
                        "identities" = @(
                            @{
                                "push-token" = "RECIPIENT_32_BYTE_APS_PUSH_TOKEN_9988";
                                "session-token" = "RECIPIENT_SESSION_ROUTING_TOKEN_1122";
                                "session-token-expires-seconds" = 2592000;
                                "client-data" = @{
                                    "public-message-identity-key" = "DER_IDSPublicIdentity_Data";
                                    "public-message-ngm-device-prekey-data-key" = "PROTOBUF_PREKEY_DATA";
                                    "ngm-public-identity" = "COMPACT_P256_PUBLIC_KEY";
                                    "supports-certified-delivery-v1" = $true;
                                };
                            }
                        );
                    }
                }
            }
        }
        # Non-existent recipient
        return @{
            "status" = 0;
            "results" = @{
                $recipientUri = @{ "identities" = @() }
            }
        }
    }
}

class MockFaceTimeSignalingRelay {
    [hashtable]$activeSessions = @{}

    [hashtable] HandleQuickRelayAllocation([string]$groupUuid, [int]$memberCount) {
        return @{
            "status" = 0;
            "relayIp" = "17.253.144.10";
            "relayPort" = 3478;
            "relayToken" = "QR-ALLOC-TOKEN-998811";
            "groupUuid" = $groupUuid;
        }
    }

    [hashtable] HandleOutgoingInvite([hashtable]$envelope) {
        if ($envelope["c"] -ne 207) {
            return @{ "status" = 1; "error" = "Expected command 207 Invite" }
        }
        $groupUuid = $envelope["groupUuid"]
        $this.activeSessions[$groupUuid] = @{
            "state" = "REMOTE_RINGING";
            "caller" = $envelope["sP"];
            "recipient" = $envelope["recipientUri"];
            "invitePayload" = $envelope["P"];
        }
        return @{
            "status" = 0;
            "state" = "REMOTE_RINGING";
            "groupUuid" = $groupUuid;
            "nativeCallKitDelivered" = $true;
        }
    }

    [hashtable] HandleCallResponse([string]$groupUuid, [string]$responseType) {
        if (-not $this.activeSessions.ContainsKey($groupUuid)) {
            return @{ "status" = 404; "error" = "Session not found" }
        }
        if ($responseType -eq "Accept") {
            $this.activeSessions[$groupUuid]["state"] = "CONNECTED"
            return @{ "status" = 0; "command" = 210; "state" = "CONNECTED" }
        } elseif ($responseType -eq "Decline") {
            $this.activeSessions[$groupUuid]["state"] = "DECLINED"
            return @{ "status" = 0; "command" = 242; "state" = "DECLINED"; "declineType" = 9 }
        } elseif ($responseType -eq "RespondedElsewhere") {
            $this.activeSessions[$groupUuid]["state"] = "RESPONDED_ELSEWHERE"
            return @{ "status" = 0; "command" = 242; "state" = "RESPONDED_ELSEWHERE"; "declineType" = 6 }
        } elseif ($responseType -eq "Leave") {
            $this.activeSessions[$groupUuid]["state"] = "ENDED"
            return @{ "status" = 0; "command" = 208; "state" = "ENDED" }
        }
        return @{ "status" = 400; "error" = "Unknown response type" }
    }
}
