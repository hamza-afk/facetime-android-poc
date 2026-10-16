package org.facetime.poc

import android.app.Application
import org.facetime.diagnostic.DiagnosticLogger
import org.facetime.rust.RustEngineBridge
import org.facetime.security.DefaultTokenRepository
import org.facetime.security.KeystoreManager
import org.facetime.security.TokenRepository

class FaceTimeApplication : Application() {

    lateinit var keystoreManager: KeystoreManager
        private set

    lateinit var tokenRepository: TokenRepository
        private set

    lateinit var diagnosticLogger: DiagnosticLogger
        private set

    lateinit var engineBridge: RustEngineBridge
        private set

    override fun onCreate() {
        super.onCreate()
        keystoreManager = KeystoreManager(this)
        tokenRepository = DefaultTokenRepository(keystoreManager)
        diagnosticLogger = DiagnosticLogger()
        engineBridge = RustEngineBridge()
    }
}
