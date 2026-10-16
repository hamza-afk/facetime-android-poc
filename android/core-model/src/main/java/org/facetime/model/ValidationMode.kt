package org.facetime.model

import kotlinx.serialization.Serializable

@Serializable
enum class ValidationMode {
    MOCK,
    RUSTPUSH_REFERENCE,
    ANDROID_EXPERIMENTAL
}
