package com.wktk.wktk

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * 전원 ON 상태를 유지하는 포그라운드 서비스.
 *
 * 앱이 백그라운드로 가면 Android는 CPU를 절전(Doze) 상태로 보내 PRESENCE 타이머와 UDP 수신이
 * 멈추고, Wi-Fi 멀티캐스트 멤버십도 정지되어 접속이 끊긴 것처럼 보인다. 이 서비스는
 *  1) 포그라운드 상태로 프로세스 생존을 보장하고,
 *  2) 부분 웨이크락(화면 꺼짐 중 CPU 유지) + Wi-Fi 락 + 멀티캐스트 락을 잡아
 *     화면이 꺼진 상태에서도 계속 대기하고,
 *  3) 상시 알림으로 사용자가 상태를 확인하고 전원을 끌 수 있게 한다.
 *
 * 전원 OFF(앱 버튼 또는 알림 액션)는 [PowerController.setPower]가 정지 + 프로세스 종료까지
 * 수행하므로, 이 서비스의 `onDestroy` 는 정리 전용이다.
 */
class WktkPowerService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        PowerController.ensureChannels(this)
        acquireLocks()
        PowerController.markActive(true)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == PowerController.ACTION_POWER_OFF) {
            // 전원 OFF = 서비스 정지 + 프로세스 완전 종료(앱 버튼과 동일한 동작).
            stopSelf()
            PowerController.exitProcessSoon()
            return START_NOT_STICKY
        }
        val notification = PowerController.buildOngoingNotification(this)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    PowerController.NOTIFICATION_ID_POWER,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(PowerController.NOTIFICATION_ID_POWER, notification)
            }
        } catch (_: Exception) {
            // 정책/제한으로 포그라운드 전환이 막히면 앱을 죽이지 않고 일반 서비스로 물러난다.
            stopSelf()
            return START_NOT_STICKY
        }
        // OS가 서비스를 죽였다면 트래픽이 복구될 때 다시 띄운다.
        return START_STICKY
    }

    override fun onDestroy() {
        PowerController.markActive(false)
        releaseLocks()
        super.onDestroy()
    }

    private fun acquireLocks() {
        try {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "wktk:power").apply {
                setReferenceCounted(false)
                acquire()
            }
        } catch (_: Exception) {
            wakeLock = null
        }
        try {
            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            wifiLock = wifi.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "wktk:power-wifi")
                .apply {
                    setReferenceCounted(false)
                    acquire()
                }
            multicastLock = wifi.createMulticastLock("wktk:power-mcast").apply {
                setReferenceCounted(false)
                acquire()
            }
        } catch (_: Exception) {
            wifiLock = null
            multicastLock = null
        }
    }

    private fun releaseLocks() {
        runCatching { wakeLock?.takeIf { it.isHeld }?.release() }
        wakeLock = null
        runCatching { wifiLock?.takeIf { it.isHeld }?.release() }
        wifiLock = null
        runCatching { multicastLock?.takeIf { it.isHeld }?.release() }
        multicastLock = null
    }
}
