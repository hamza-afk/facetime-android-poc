package org.facetime.poc

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import org.facetime.model.ValidationMode
import org.facetime.poc.ui.FaceTimeViewModel
import org.facetime.rust.RustEngineBridge
import org.facetime.security.KeystoreManager
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.mock

@OptIn(ExperimentalCoroutinesApi::class)
class FaceTimeViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var engineBridge: RustEngineBridge
    private lateinit var keystoreManager: KeystoreManager
    private lateinit var viewModel: FaceTimeViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        engineBridge = RustEngineBridge()
        keystoreManager = mock(KeystoreManager::class.java)
        viewModel = FaceTimeViewModel(engineBridge, keystoreManager)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testInitialValidationMode() {
        assertThat(viewModel.validationMode.value).isEqualTo(ValidationMode.ANDROID_EXPERIMENTAL)
    }

    @Test
    fun testChangeValidationMode() {
        viewModel.setValidationMode(ValidationMode.MOCK)
        assertThat(viewModel.validationMode.value).isEqualTo(ValidationMode.MOCK)
    }
}
