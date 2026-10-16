package org.facetime.security

import java.util.Arrays

object PasswordZeroizer {
    /**
     * Overwrites the provided character buffer with null characters to prevent
     * plaintext credentials from lingering in process heap memory.
     */
    fun wipe(passwordBuffer: CharArray?) {
        if (passwordBuffer != null) {
            Arrays.fill(passwordBuffer, '\u0000')
        }
    }

    /**
     * Executes the supplied block with the password buffer and guarantees
     * immediate zeroization upon block completion, even in case of exceptions.
     */
    inline fun <R> useAndWipe(passwordBuffer: CharArray, block: (CharArray) -> R): R {
        return try {
            block(passwordBuffer)
        } finally {
            wipe(passwordBuffer)
        }
    }

    /**
     * Verifies that the buffer contains only null characters ('\u0000').
     */
    fun isZeroized(passwordBuffer: CharArray): Boolean {
        return passwordBuffer.all { it == '\u0000' }
    }
}
