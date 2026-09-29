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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wktk/power")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 전원 ON: 백그라운드 대기를 위한 포그라운드 서비스 기동.
                    "setPower" -> {
                        PowerController.setPower(this, call.argument<Boolean>("on") ?: false)
                        result.success(true)
                    }
                    // 백그라운드 대기 중 상대 PTT → 알림 + 진동 + 포그라운드 전환.
                    "ring" -> {
                        PowerController.ring(
                            this,
                            call.argument<String>("talker"),
                            call.argument<Int>("channel"),
                        )
                        result.success(true)
                    }
                    "isPowerOn" -> result.success(PowerController.isActive)
                    else -> result.notImplemented()
                }
            }
    }
}