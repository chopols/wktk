package com.wktk.wktk

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wktk/multicast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        val wifiManager = getSystemService(Context.WIFI_SERVICE) as WifiManager
                        val lock = multicastLock
                            ?: wifiManager.createMulticastLock("wktk").apply {
                                setReferenceCounted(false)
                                multicastLock = this
                            }
                        try {
                            lock.acquire()
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "release" -> {
                        try {
                            multicastLock?.release()
                        } catch (_: Exception) {
                            // 무시
                        }
                        multicastLock = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}