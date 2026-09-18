package com.ezitech.ezisaver

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges two things Dart cannot do on its own:
 *
 *  - links shared into the app from another app's share sheet, and
 *  - the download progress notification.
 */
class MainActivity : FlutterActivity() {

    private var shareChannel: MethodChannel? = null

    /** Link waiting for Dart to start up and collect it. */
    private var pendingLink: String? = null

    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // A progress notification left over from a download that died with
        // the process. If a download is in fact still running, its next
        // progress update puts the notification straight back.
        DownloadNotifications.cancelOngoing(applicationContext)

        shareChannel = MethodChannel(messenger, SHARE_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeSharedLink" -> {
                        result.success(pendingLink)
                        pendingLink = null
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(messenger, DOWNLOAD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> requestNotificationPermission(result)

                "show" -> {
                    DownloadNotifications.showOngoing(
                        applicationContext,
                        call.argument<String>("title") ?: "Saving video",
                        call.argument<String>("text").orEmpty(),
                        call.argument<Int>("progress") ?: -1,
                    )
                    result.success(null)
                }

                "finish" -> {
                    DownloadNotifications.cancelOngoing(applicationContext)

                    DownloadNotifications.showResult(
                        applicationContext,
                        call.argument<Int>("downloadId") ?: 0,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("text").orEmpty(),
                        call.argument<Boolean>("success") ?: false,
                    )
                    result.success(null)
                }

                "cancel" -> {
                    DownloadNotifications.cancelOngoing(applicationContext)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        linkFrom(intent)?.let { pendingLink = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val link = linkFrom(intent) ?: return
        val openChannel = shareChannel

        if (openChannel == null) {
            pendingLink = link
        } else {
            openChannel.invokeMethod("sharedLink", link)
        }
    }

    // ============================================================
    // NOTIFICATION PERMISSION
    // ============================================================

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED

        if (granted) {
            result.success(true)
            return
        }

        // Only one request can be in flight; answer any earlier one so Dart is
        // never left waiting on a future that will not complete.
        notificationPermissionResult?.success(false)
        notificationPermissionResult = result

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED

        notificationPermissionResult?.success(granted)
        notificationPermissionResult = null
    }

    // ============================================================
    // SHARED LINKS
    // ============================================================

    /**
     * The first http(s) URL inside a shared text payload.
     *
     * Share sheets rarely send a bare link — TikTok and Instagram wrap it in a
     * caption — so the URL has to be picked out of the surrounding text.
     */
    private fun linkFrom(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null

        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null

        return URL_PATTERN.find(text)?.value
    }

    companion object {
        private const val SHARE_CHANNEL = "com.ezitech.ezisaver/share"
        private const val DOWNLOAD_CHANNEL = "com.ezitech.ezisaver/download"
        private const val NOTIFICATION_PERMISSION_REQUEST = 7301
        private val URL_PATTERN = Regex("""https?://\S+""")
    }
}
