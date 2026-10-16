# KeystoreSimulator.ps1
# Android Keystore MasterKey (AES-256-GCM) and in-memory zeroization simulator

Add-Type -AssemblyName System.Security

class KeystoreSimulator {
    hidden [byte[]]$masterKey
    [hashtable]$encryptedStorage = @{}
    [bool]$isUnlocked = $true

    KeystoreSimulator() {
        # Generate 256-bit AES MasterKey
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $this.masterKey = [byte[]]::new(32)
        $rng.GetBytes($this.masterKey)
    }

    [hashtable] EncryptToken([string]$keyAlias, [string]$plaintext) {
        if (-not $this.isUnlocked) {
            throw [System.InvalidOperationException]::new("Keystore is locked")
        }
        if ([string]::IsNullOrEmpty($plaintext)) {
            throw [System.ArgumentException]::new("Cannot encrypt empty token")
        }

        # Simulate AES-GCM encryption with IV (12 bytes) and Auth Tag (16 bytes)
        $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($plaintext)
        $iv = [byte[]]::new(12)
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($iv)

        # XOR/AES mock block transformation ensuring non-plaintext output
        $cipherBytes = [byte[]]::new($plainBytes.Length)
        for ($i = 0; $i -lt $plainBytes.Length; $i++) {
            $cipherBytes[$i] = $plainBytes[$i] -bxor $this.masterKey[$i % 32] -bxor $iv[$i % 12]
        }
        $authTag = [byte[]]::new(16)
        $rng.GetBytes($authTag)

        $entry = @{
            "iv" = [System.Convert]::ToBase64String($iv);
            "tag" = [System.Convert]::ToBase64String($authTag);
            "ciphertext" = [System.Convert]::ToBase64String($cipherBytes);
        }
        $this.encryptedStorage[$keyAlias] = $entry
        return $entry
    }

    [string] DecryptToken([string]$keyAlias) {
        if (-not $this.isUnlocked) {
            throw [System.InvalidOperationException]::new("Keystore is locked")
        }
        if (-not $this.encryptedStorage.ContainsKey($keyAlias)) {
            return $null
        }
        $entry = $this.encryptedStorage[$keyAlias]
        $iv = [System.Convert]::FromBase64String($entry["iv"])
        $cipherBytes = [System.Convert]::FromBase64String($entry["ciphertext"])

        $plainBytes = [byte[]]::new($cipherBytes.Length)
        for ($i = 0; $i -lt $cipherBytes.Length; $i++) {
            $plainBytes[$i] = $cipherBytes[$i] -bxor $this.masterKey[$i % 32] -bxor $iv[$i % 12]
        }
        return [System.Text.Encoding]::UTF8.GetString($plainBytes)
    }

    [void] PurgeAll() {
        $this.encryptedStorage.Clear()
        # Overwrite masterKey in memory
        [System.Array]::Clear($this.masterKey, 0, $this.masterKey.Length)
        $this.isUnlocked = $false
    }

    [bool] VerifyInMemoryZeroization([char[]]$passwordBuffer) {
        # Check if passwordBuffer has been wiped (all characters are 0 or null)
        for ($i = 0; $i -lt $passwordBuffer.Length; $i++) {
            if ($passwordBuffer[$i] -ne [char]0) {
                return $false # Password was NOT zeroized!
            }
        }
        return $true # Successfully zeroized
    }
}
