package com.ezitech.ezisaver

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hands links shared into the app from other apps' share sheets over to Dart.
 *
 * A share can arrive two ways: it launches the app, in which case Dart is not
 * listening yet and the link waits in [pendingLink] until Dart asks for it; or
 * the app is already running, in which case it is pushed straight across.
 */
class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null

    /** Link waiting for Dart to start up and collect it. */
    private var pendingLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).apply {
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

        linkFrom(intent)?.let { pendingLink = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val link = linkFrom(intent) ?: return
        val openChannel = channel

        if (openChannel == null) {
            pendingLink = link
        } else {
            openChannel.invokeMethod("sharedLink", link)
        }
    }

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
        private const val CHANNEL = "com.ezitech.ezisaver/share"
        private val URL_PATTERN = Regex("""https?://\S+""")
    }
}
