package org.facetime.security

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys

data class StoredCredentials(
    val dsid: String,
    val authToken: String,
    val accountName: String,
    val petToken: String? = null
)

class KeystoreManager(private val context: Context) {

    private val masterKeyAlias: String by lazy {
        try {
            val keyGenSpec = KeyGenParameterSpec.Builder(
                MASTER_KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(false)
                .build()
            MasterKeys.getOrCreate(keyGenSpec)
        } catch (_: Exception) {
            MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        }
    }

    private val encryptedPrefs: SharedPreferences by lazy {
        EncryptedSharedPreferences.create(
            SECURE_PREFS_NAME,
            masterKeyAlias,
            context,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun saveTokens(dsid: String, authToken: String, accountName: String, petToken: String? = null) {
        require(dsid.isNotBlank()) { "DSID cannot be blank" }
        require(authToken.isNotBlank()) { "Auth token cannot be blank" }

        encryptedPrefs.edit()
            .putString(KEY_DSID, dsid)
            .putString(KEY_AUTH_TOKEN, authToken)
            .putString(KEY_ACCOUNT_NAME, accountName)
            .apply {
                if (petToken != null) {
                    putString(KEY_PET_TOKEN, petToken)
                }
            }
            .apply()
    }

    fun getTokens(): StoredCredentials? {
        val dsid = encryptedPrefs.getString(KEY_DSID, null) ?: return null
        val token = encryptedPrefs.getString(KEY_AUTH_TOKEN, null) ?: return null
        val account = encryptedPrefs.getString(KEY_ACCOUNT_NAME, "") ?: ""
        val pet = encryptedPrefs.getString(KEY_PET_TOKEN, null)
        return StoredCredentials(dsid = dsid, authToken = token, accountName = account, petToken = pet)
    }

    fun clearTokens() {
        encryptedPrefs.edit().clear().commit()
    }

    companion object {
        private const val MASTER_KEY_ALIAS = "_facetime_master_key_"
        private const val SECURE_PREFS_NAME = "facetime_secure_prefs"
        const val KEY_DSID = "secure_dsid"
        const val KEY_AUTH_TOKEN = "secure_auth_token"
        const val KEY_ACCOUNT_NAME = "secure_account_name"
        const val KEY_PET_TOKEN = "secure_pet_token"
    }
}
