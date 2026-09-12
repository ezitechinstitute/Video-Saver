package com.ezitech.ezisaver

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app's process alive while a download runs, and shows its progress
 * in the notification shade.
 *
 * The service downloads nothing itself. The work stays in Dart, exactly as it
 * runs when the app is on screen — this only stops Android from freezing that
 * work the moment the user switches away, and gives them something to watch
 * while it finishes.
 */
class DownloadService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundAndSelf()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Saving video"
        val text = intent?.getStringExtra(EXTRA_TEXT).orEmpty()
        val progress = intent?.getIntExtra(EXTRA_PROGRESS, -1) ?: -1

        val notification = DownloadNotifications.ongoing(this, title, text, progress)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                DownloadNotifications.ONGOING_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(DownloadNotifications.ONGOING_ID, notification)
        }

        // If Android kills the process mid-download there is nothing worth
        // restarting: the Dart side that was doing the work is gone too.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopForegroundCompat()
        super.onDestroy()
    }

    private fun stopForegroundAndSelf() {
        stopForegroundCompat()
        stopSelf()
    }

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    companion object {
        const val ACTION_STOP = "com.ezitech.ezisaver.STOP_DOWNLOAD"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_PROGRESS = "progress"

        /** Starts the service, or updates the notification if it is running. */
        fun show(context: Context, title: String, text: String, progress: Int) {
            val intent = Intent(context, DownloadService::class.java).apply {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TEXT, text)
                putExtra(EXTRA_PROGRESS, progress)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, DownloadService::class.java).apply {
                action = ACTION_STOP
            }

            // startService, not startForegroundService: asking for a foreground
            // start just to stop it would demand another startForeground call.
            try {
                context.startService(intent)
            } catch (e: IllegalStateException) {
                // The app is in the background and the service is not running.
                // Nothing to stop.
            }
        }
    }
}
