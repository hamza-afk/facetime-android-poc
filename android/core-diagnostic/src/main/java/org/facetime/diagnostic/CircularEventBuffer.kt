package org.facetime.diagnostic

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

/**
 * Bounded circular FIFO ring buffer preventing OutOfMemory (OOM) errors
 * during prolonged testing and high-frequency event floods.
 */
class CircularEventBuffer(val capacity: Int = DEFAULT_CAPACITY) {
    init {
        require(capacity > 0) { "Buffer capacity must be strictly positive: $capacity" }
    }

    private val buffer = arrayOfNulls<DiagnosticEvent>(capacity)
    private var head = 0
    private var count = 0
    private val rwLock = ReentrantReadWriteLock()

    private val _eventFlow = MutableSharedFlow<DiagnosticEvent>(
        extraBufferCapacity = 128,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val eventFlow: SharedFlow<DiagnosticEvent> = _eventFlow.asSharedFlow()

    /**
     * Appends an event to the buffer in O(1) time.
     * Overwrites oldest event if capacity is reached.
     */
    fun append(event: DiagnosticEvent) {
        rwLock.write {
            val insertIndex = (head + count) % capacity
            if (count == capacity) {
                head = (head + 1) % capacity
            } else {
                count++
            }
            buffer[insertIndex] = event
        }
        _eventFlow.tryEmit(event)
    }

    /**
     * Returns an immutable point-in-time snapshot of current events in chronological order.
     */
    fun snapshot(): List<DiagnosticEvent> {
        return rwLock.read {
            val list = ArrayList<DiagnosticEvent>(count)
            for (i in 0 until count) {
                val item = buffer[(head + i) % capacity]
                if (item != null) {
                    list.add(item)
                }
            }
            list
        }
    }

    /**
     * Filters active buffer events according to subsystem, minimum severity, and text query.
     */
    fun filter(
        subsystem: DiagnosticSubsystem? = null,
        minSeverity: DiagnosticSeverity? = null,
        query: String? = null
    ): List<DiagnosticEvent> {
        val normalizedQuery = query?.trim()?.lowercase()?.takeIf { it.isNotEmpty() }
        return rwLock.read {
            val result = ArrayList<DiagnosticEvent>(count)
            for (i in 0 until count) {
                val item = buffer[(head + i) % capacity] ?: continue

                if (subsystem != null && item.subsystem != subsystem) continue
                if (minSeverity != null && item.severity.ordinal < minSeverity.ordinal) continue
                if (normalizedQuery != null) {
                    val matchesName = item.eventName.lowercase().contains(normalizedQuery)
                    val matchesMsg = item.message?.lowercase()?.contains(normalizedQuery) == true
                    val matchesPayload = item.payload.values.any { it.lowercase().contains(normalizedQuery) }
                    if (!matchesName && !matchesMsg && !matchesPayload) continue
                }
                result.add(item)
            }
            result
        }
    }

    /**
     * Returns the current event count in the buffer (0..capacity).
     */
    fun size(): Int = rwLock.read { count }

    /**
     * Resets the buffer and purges all entries.
     */
    fun clear() {
        rwLock.write {
            head = 0
            count = 0
            buffer.fill(null)
        }
    }

    companion object {
        const val DEFAULT_CAPACITY = 1000
        const val EXTENDED_CAPACITY = 2048
    }
}
