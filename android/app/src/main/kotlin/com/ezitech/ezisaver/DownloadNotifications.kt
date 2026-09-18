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

    /** A progress notification not updated for this long belongs to a dead download. */
    private const val STALE_AFTER_MS = 2 * 60 * 1000L

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
     * Shows, or updates, the progress notification for a running download.
     *
     * A plain notification, not a foreground service: a download here takes a
     * few seconds, so it does not need to hold the process against Android
     * freezing it, and a foreground service would need a Play declaration with
     * a demonstration video the app does not have.
     *
     * A [progress] below zero shows an indeterminate bar (length not known yet).
     */
    fun showOngoing(context: Context, title: String, text: String, progress: Int) {
        ensureChannel(context)

        val notification = baseBuilder(context, title, text)
            .setOngoing(true)
            .setProgress(100, progress.coerceIn(0, 100), progress < 0)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            // An ongoing notification cannot be swiped away. If Android kills
            // the app mid download nothing is left to cancel it, so let it
            // expire on its own. Every update restarts the clock.
            .setTimeoutAfter(STALE_AFTER_MS)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(ONGOING_ID, notification)
        } catch (e: SecurityException) {
            // Notifications not permitted; the download still runs unseen.
        }
    }

    fun cancelOngoing(context: Context) {
        NotificationManagerCompat.from(context).cancel(ONGOING_ID)
    }

    fun showResult(
        context: Context,
        downloadId: Int,
        title: String,
        text: String,
        success: Boolean,
    ) {
        ensureChannel(context)

        // The finished notification must not reuse the in-progress arrow, or
        // the status bar keeps saying "downloading" after the video is saved.
        val icon = if (success) {
            android.R.drawable.stat_sys_download_done
        } else {
            android.R.drawable.stat_notify_error
        }

        val notification = baseBuilder(context, title, text, icon)
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
        smallIcon: Int = android.R.drawable.stat_sys_download,
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
            .setSmallIcon(smallIcon)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pending)
            .setOnlyAlertOnce(true)
    }
}
