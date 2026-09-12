package com.ezitech.ezisaver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/** The notification shown while a download runs, and the one left behind after. */
object DownloadNotifications {

    const val CHANNEL_ID = "downloads"
    const val ONGOING_ID = 1001

    /** Result notifications are keyed off the download so several can stack. */
    fun resultId(downloadId: Int): Int = 2000 + downloadId

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Downloads",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Progress of videos being saved to your gallery"
            setShowBadge(false)
        }

        context.getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    /**
     * Progress notification. A [progress] below zero means the length is not
     * known yet — while the server is still preparing the video, for instance.
     */
    fun ongoing(
        context: Context,
        title: String,
        text: String,
        progress: Int,
    ): android.app.Notification {
        ensureChannel(context)

        return baseBuilder(context, title, text)
            .setOngoing(true)
            .setProgress(100, progress.coerceIn(0, 100), progress < 0)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            // Android 12+ holds a foreground service notification back for ten
            // seconds. Most downloads here finish in about that long, so
            // without this the progress bar is never actually seen.
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    fun showResult(
        context: Context,
        downloadId: Int,
        title: String,
        text: String,
        success: Boolean,
    ) {
        ensureChannel(context)

        val notification = baseBuilder(context, title, text)
            .setAutoCancel(true)
            .setPriority(
                if (success) NotificationCompat.PRIORITY_DEFAULT
                else NotificationCompat.PRIORITY_HIGH,
            )
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .build()

        // Posting without the permission throws on API 33+; the user simply
        // does not get a notification, which must not break the download.
        try {
            NotificationManagerCompat.from(context)
                .notify(resultId(downloadId), notification)
        } catch (e: SecurityException) {
            // Notifications are not permitted. Nothing to do.
        }
    }

    fun cancelResult(context: Context, downloadId: Int) {
        NotificationManagerCompat.from(context).cancel(resultId(downloadId))
    }

    private fun baseBuilder(
        context: Context,
        title: String,
        text: String,
    ): NotificationCompat.Builder {
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pending = PendingIntent.getActivity(
            context,
            0,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pending)
            .setOnlyAlertOnce(true)
    }
}
