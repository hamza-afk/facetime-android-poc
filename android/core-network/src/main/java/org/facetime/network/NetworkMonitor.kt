package org.facetime.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

sealed class ActiveNetworkType {
    data object Disconnected : ActiveNetworkType()
    data object Wifi : ActiveNetworkType()
    data object Cellular : ActiveNetworkType()
    data object Other : ActiveNetworkType()
}

class NetworkMonitor(context: Context) {
    private val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

    private val _networkState = MutableStateFlow<ActiveNetworkType>(ActiveNetworkType.Disconnected)
    val networkState: StateFlow<ActiveNetworkType> = _networkState.asStateFlow()

    var onNetworkChangedListener: ((isConnected: Boolean, isWifi: Boolean) -> Unit)? = null

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            updateState(network)
        }

        override fun onLost(network: Network) {
            _networkState.value = ActiveNetworkType.Disconnected
            onNetworkChangedListener?.invoke(false, false)
        }

        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            updateState(network)
        }

        private fun updateState(network: Network) {
            val caps = cm?.getNetworkCapabilities(network) ?: return
            val hasInternet = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            val isWifi = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
            val isCell = caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)

            val newState = when {
                !hasInternet -> ActiveNetworkType.Disconnected
                isWifi -> ActiveNetworkType.Wifi
                isCell -> ActiveNetworkType.Cellular
                else -> ActiveNetworkType.Other
            }

            _networkState.value = newState
            onNetworkChangedListener?.invoke(hasInternet, isWifi)
        }
    }

    fun start() {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        try {
            cm?.registerNetworkCallback(request, callback)
        } catch (_: Exception) {}
    }

    fun stop() {
        try {
            cm?.unregisterNetworkCallback(callback)
        } catch (_: Exception) {}
    }
}
