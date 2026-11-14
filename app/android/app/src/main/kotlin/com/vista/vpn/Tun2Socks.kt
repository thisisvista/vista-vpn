package com.vista.vpn

import android.os.ParcelFileDescriptor

/**
 * hev-socks5-tunnel (app/android), the C library that takes the VPN's packets
 * apart and opens a SOCKS5 connection to the core for each TCP connection and
 * UDP flow, on a thread of its own. A stack in the Go core cost two to three
 * times its CPU.
 *
 * The library binds these native methods to this class by name when it loads:
 * proguard-rules.pro keeps them, and app/build.gradle.kts names the class.
 */
object Tun2Socks {
    private external fun TProxyStartService(configPath: String, fd: Int): Boolean
    private external fun TProxyStopService(): Boolean
    private external fun TProxyIsRunning(): Boolean

    @Suppress("unused") // The library binds all four, or none.
    private external fun TProxyGetStats(): LongArray

    /** The VPN's device: the library only borrows it. */
    private var device: ParcelFileDescriptor? = null

    /**
     * Runs the library on [tun], which this now owns, instead of a device it
     * ran on before. False, or a throw, when it could not start: [tun] is
     * closed then, which ends the VPN instead of holding the phone's traffic.
     */
    @Synchronized
    fun start(configPath: String, tun: ParcelFileDescriptor): Boolean {
        try {
            stop()
            System.loadLibrary("hev-socks5-tunnel")
            device = tun
            if (TProxyStartService(configPath, tun.fd)) return true
        } catch (e: Throwable) {
            device = null
            tun.close()
            throw e
        }
        stop()
        return false
    }

    /** Stops the library, which ends its connections, and closes the device. */
    @Synchronized
    fun stop() {
        val tun = device ?: return
        device = null
        TProxyStopService()
        tun.close()
    }

    /**
     * Restarts the packet processor on the existing VPN device. If the
     * previous native run ended unexpectedly, JNI first stops its TUN
     * packet dropper, then starts the processor. If this run also fails,
     * JNI returns to dropping packets instead of releasing the VPN device.
     */
    @Synchronized
    fun restart(configPath: String): Boolean {
        val tun = device ?: return false
        return try {
            TProxyStartService(configPath, tun.fd)
        } catch (e: Throwable) {
            android.util.Log.e("Tun2Socks", "the tunnel could not restart", e)
            false
        }
    }

    /**
     * True when the VPN device is still held but the native packet processor
     * has ended. JNI keeps draining and discarding packets in this state.
     */
    @Synchronized
    fun ended(): Boolean = device != null && !TProxyIsRunning()
}
