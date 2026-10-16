package org.facetime.security

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

interface TokenRepository {
    suspend fun saveTokens(dsid: String, authToken: String, accountName: String, petToken: String? = null)
    suspend fun getTokens(): StoredCredentials?
    suspend fun clearTokens()
}

class DefaultTokenRepository(
    private val keystoreManager: KeystoreManager
) : TokenRepository {

    override suspend fun saveTokens(dsid: String, authToken: String, accountName: String, petToken: String?) {
        withContext(Dispatchers.IO) {
            keystoreManager.saveTokens(dsid, authToken, accountName, petToken)
        }
    }

    override suspend fun getTokens(): StoredCredentials? {
        return withContext(Dispatchers.IO) {
            keystoreManager.getTokens()
        }
    }

    override suspend fun clearTokens() {
        withContext(Dispatchers.IO) {
            keystoreManager.clearTokens()
        }
    }
}
