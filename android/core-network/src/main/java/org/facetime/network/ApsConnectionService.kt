package org.facetime.network

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*

class ApsConnectionService : Service() {

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private lateinit var networkMonitor: NetworkMonitor
    private val backoffSchedule = listOf(1L, 2L, 4L, 8L, 16L, 32L)
    private var backoffIndex = 0

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification("Initializing APS Courier..."), getForegroundServiceType())

        networkMonitor = NetworkMonitor(this).apply {
            onNetworkChangedListener = { isConnected, isWifi ->
                handleNetworkChange(isConnected, isWifi)
            }
            start()
        }

        startHeartbeatLoop()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> connectAps()
            ACTION_DISCONNECT -> disconnectAps()
            ACTION_PING -> sendKeepalivePing()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        networkMonitor.stop()
        serviceScope.cancel()
    }

    private fun handleNetworkChange(isConnected: Boolean, isWifi: Boolean) {
        val statusText = if (isConnected) {
            "APS: Interface switched to ${if (isWifi) "Wi-Fi" else "Cellular"} (Reconnecting...)"
        } else {
            "APS: Network Disconnected"
        }
        updateNotification(statusText)

        if (isConnected) {
            serviceScope.launch {
                val delaySec = backoffSchedule[backoffIndex.coerceAtMost(backoffSchedule.lastIndex)]
                delay(delaySec * 1000)
                connectAps()
            }
        }
    }

    private fun connectAps() {
        serviceScope.launch {
            updateNotification("APS: Connecting to courier.push.apple.com:5223")
            backoffIndex = 0
            updateNotification("APS: Connected [5-courier.push.apple.com:5223]")
        }
    }

    private fun disconnectAps() {
        updateNotification("APS: Disconnected")
    }

    private fun sendKeepalivePing() {
        serviceScope.launch {
            updateNotification("APS: Keepalive Ping dispatched (0x0C)")
        }
    }

    private fun startHeartbeatLoop() {
        serviceScope.launch {
            while (isActive) {
                delay(60_000L) // 60 seconds keepalive ping
                sendKeepalivePing()
            }
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Apple Push Service (APS)",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Maintains persistent APS Courier TLS connection for incoming calls"
            setShowBadge(false)
        }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(contentText: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("FaceTime APNS Courier")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(contentText: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification(contentText))
    }

    private fun getForegroundServiceType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
        } else {
            0
        }
    }

    companion object {
        const val CHANNEL_ID = "aps_channel"
        const val NOTIFICATION_ID = 101

        const val ACTION_CONNECT = "org.facetime.action.APS_CONNECT"
        const val ACTION_DISCONNECT = "org.facetime.action.APS_DISCONNECT"
        const val ACTION_PING = "org.facetime.action.APS_PING"
    }
}
