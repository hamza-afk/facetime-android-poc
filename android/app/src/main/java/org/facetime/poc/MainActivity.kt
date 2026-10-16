package org.facetime.poc

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import org.facetime.poc.ui.AppNavGraph
import org.facetime.poc.ui.FaceTimeViewModel
import org.facetime.poc.ui.theme.FaceTimeDiagnosticTheme
import org.facetime.rust.RustEngineBridge
import org.facetime.security.KeystoreManager

class MainActivity : ComponentActivity() {

    private val keystore by lazy { KeystoreManager(applicationContext) }
    private val engineBridge by lazy { RustEngineBridge() }
    private val viewModel by lazy { FaceTimeViewModel(engineBridge, keystore) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            FaceTimeDiagnosticTheme {
                AppNavGraph(viewModel)
            }
        }
    }
}
