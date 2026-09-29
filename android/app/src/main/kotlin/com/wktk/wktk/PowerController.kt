package com.wktk.wktk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat

/**
 * 전원(포그라운드 서비스) 제어 유틸리티.
 *
 * - [setPower] ON : 백그라운드 대기를 위한 포그라운드 서비스를 기동한다.
 * - [setPower] OFF: 서비스를 정지하고 **프로세스 자체를 종료**한다(전원 OFF = 완전 종료).
 * - [ring]       : 백그라운드 대기 중 상대 PTT 감지 시 앱을 앞으로 올리고 알린다.
 */
object PowerController {
    /** 서비스 시작(전원 ON). */
    const val ACTION_POWER_ON = "com.wktk.wktk.action.POWER_ON"

    /** 서비스 정지(전원 OFF). 알림 액션에서도 사용된다. */
    const val ACTION_POWER_OFF = "com.wktk.wktk.action.POWER_OFF"

    /** 상시 알림(전원 ON 표시) 채널 — 낮은 중요도. */
    const val CHANNEL_POWER = "wktk_power"

    /** 상대 호출(전화) 알림 채널 — 높은 중요도 + 헤드업. */
    const val CHANNEL_INCOMING = "wktk_incoming"

    const val NOTIFICATION_ID_POWER = 4101
    const val NOTIFICATION_ID_INCOMING = 4102

    /** 호출 인텐트에 실리는 발화자 닉네임(선택). */
    const val EXTRA_CALLER = "caller"

    /** 프로세스 종료 지연(알림 액트/MethodChannel 응답이 먼저 전달되도록). */
    private const val EXIT_DELAY_MS = 250L

    @Volatile
    var isActive: Boolean = false
        private set

    internal fun markActive(value: Boolean) {
        isActive = value
    }

    /** 전원 ON/OFF 스위치. OFF 는 서비스 정지 후 프로세스 완전 종료까지 수행한다. */
    fun setPower(context: Context, on: Boolean) {
        val app = context.applicationContext
        if (on) {
            val intent = Intent(app, WktkPowerService::class.java).setAction(ACTION_POWER_ON)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    app.startForegroundService(intent)
                } else {
                    app.startService(intent)
                }
            } catch (_: Exception) {
                // 포그라운드 서비스 기동 실패(백그라운드 제한 등)는 무시한다.
            }
        } else {
            try {
                app.stopService(Intent(app, WktkPowerService::class.java))
            } catch (_: Exception) {
                // 이미 정지된 경우.
            }
            exitProcessSoon()
        }
    }

    /**
     * 백그라운드 대기 중 상대가 PTT를 눌렀을 때 호출.
     * 헤드업 알림 + 진동 후 앱을 포그라운드로 가져온다.
     */
    fun ring(context: Context, talker: String?, channel: Int?) {
        val app = context.applicationContext
        ensureChannels(app)
        val who = talker?.trim()?.takeIf { it.isNotEmpty() } ?: "다른 무전기"
        val ch = channel ?: 1
        val open = launchIntent(app, who)
        val fullIntent = PendingIntent.getActivity(
            app,
            1,
            open,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification: Notification = NotificationCompat.Builder(app, CHANNEL_INCOMING)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("$who 님이 말하는 중")
            .setContentText("채널 $ch 에서 통화가 왔습니다 · 탭하여 응답")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(false)
            .setAutoCancel(true)
            .setContentIntent(fullIntent)
            .setFullScreenIntent(fullIntent, true)
            .build()
        notify(app, NOTIFICATION_ID_INCOMING, notification)
        vibrate(app)
        try {
            app.startActivity(open)
        } catch (_: Exception) {
            // 백그라운드 시작 제한 시에는 알림만으로 알린다.
        }
    }

    /** 상시 알림(전원 ON · 대기 중). */
    fun buildOngoingNotification(context: Context): Notification {
        val app = context.applicationContext
        ensureChannels(app)
        val open = PendingIntent.getActivity(
            app,
            0,
            launchIntent(app, null),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val off = PendingIntent.getService(
            app,
            2,
            Intent(app, WktkPowerService::class.java).setAction(ACTION_POWER_OFF),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(app, CHANNEL_POWER)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("WKTK 무전기 · 전원 켬")
            .setContentText("백그라운드에서 대기 중입니다")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setContentIntent(open)
            .addAction(0, "열기", open)
            .addAction(0, "전원 끄기", off)
            .build()
    }

    /** 앱을 포그라운드로 올리는 인텐트(기존 태스크 재사용). */
    fun launchIntent(context: Context, talker: String?): Intent {
        val base = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        return base.apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
            if (talker != null) putExtra(EXTRA_CALLER, talker)
        }
    }

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val power = NotificationChannel(
            CHANNEL_POWER,
            "전원(백그라운드 대기)",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "전원이 켜져 있는 동안 백그라운드에서 대기합니다."
            setShowBadge(false)
            enableVibration(false)
        }
        val incoming = NotificationChannel(
            CHANNEL_INCOMING,
            "호출",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "다른 무전기에서 PTT가 눌려 전화를 받을 때 알립니다."
            setShowBadge(true)
            enableVibration(true)
        }
        manager.createNotificationChannel(power)
        manager.createNotificationChannel(incoming)
    }

    private fun notify(context: Context, id: Int, notification: Notification) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        try {
            manager.notify(id, notification)
        } catch (_: SecurityException) {
            // Android 13+ 알림 권한이 없으면 표시되지 않는다(전원 기능에는 영향 없음).
        }
    }

    private fun vibrate(context: Context) {
        val vibrator = context.getSystemService(Vibrator::class.java) ?: return
        if (!vibrator.hasVibrator()) return
        try {
            vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 250, 500), -1))
        } catch (_: Exception) {
            // 진동 권한/기기 특성 차이는 무시.
        }
    }

    /** 전원 OFF: 현재 앱 프로세스를 완전히 종료한다. */
    fun exitProcessSoon() {
        Handler(Looper.getMainLooper()).postDelayed({
            Process.killProcess(Process.myPid())
        }, EXIT_DELAY_MS)
    }
}
