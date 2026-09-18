package com.ezitech.ezisaver

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Statuses the user has already viewed in a messaging app, which that app
 * keeps on the phone.
 *
 * Access goes through the system folder picker (Storage Access Framework):
 * the user grants this one folder once, and nothing else on the phone is
 * readable. No storage permission is requested, and nothing leaves the
 * device.
 */
class StatusSaver(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private val context: Context get() = activity.applicationContext
    private val prefs by lazy {
        context.getSharedPreferences("status_saver", Context.MODE_PRIVATE)
    }
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var pendingApp: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val app = call.argument<String>("app") ?: APP_MAIN

        when (call.method) {
            "hasAccess" -> result.success(treeFor(app) != null)
            "requestAccess" -> requestAccess(app, result)
            "list" -> background(result) { list(app) }
            "thumbnail" -> {
                val uri = Uri.parse(call.argument<String>("uri"))
                val video = call.argument<Boolean>("video") ?: false
                background(result) { thumbnail(uri, video) }
            }
            "copyToCache" -> {
                val uri = Uri.parse(call.argument<String>("uri"))
                val name = call.argument<String>("name") ?: "status"
                background(result) { copyToCache(uri, name) }
            }
            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------
    // ACCESS
    // ------------------------------------------------------------

    private fun requestAccess(app: String, result: MethodChannel.Result) {
        // Only one picker at a time; answer an earlier caller rather than
        // leaving it waiting forever.
        pendingResult?.success(mapOf("granted" to false, "reason" to "cancelled"))
        pendingApp = app
        pendingResult = result

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
            // Open the picker right on the statuses folder, so the user only
            // has to tap "Use this folder".
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(
                    DocumentsContract.EXTRA_INITIAL_URI,
                    DocumentsContract.buildDocumentUri(STORAGE_AUTHORITY, statusesDocId(app)),
                )
            }
        }

        try {
            activity.startActivityForResult(intent, REQUEST_TREE)
        } catch (e: Exception) {
            pendingResult = null
            result.success(mapOf("granted" to false, "reason" to "no_picker"))
        }
    }

    /** Called from MainActivity.onActivityResult. Returns true if handled. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_TREE) return false

        val result = pendingResult ?: return true
        val app = pendingApp ?: APP_MAIN
        pendingResult = null
        pendingApp = null

        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(mapOf("granted" to false, "reason" to "cancelled"))
            return true
        }

        // Only the statuses folder is any use; anything else would show the
        // user unrelated files, so it is refused and not kept.
        val docId = DocumentsContract.getTreeDocumentId(tree)
        if (!docId.endsWith(".Statuses")) {
            result.success(mapOf("granted" to false, "reason" to "wrong_folder"))
            return true
        }

        context.contentResolver.takePersistableUriPermission(
            tree,
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )
        prefs.edit().putString(KEY_TREE + app, tree.toString()).apply()

        result.success(mapOf("granted" to true))
        return true
    }

    /** The granted folder for [app], if the grant is still held. */
    private fun treeFor(app: String): Uri? {
        val saved = prefs.getString(KEY_TREE + app, null) ?: return null
        val uri = Uri.parse(saved)

        val held = context.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission
        }
        if (!held) {
            prefs.edit().remove(KEY_TREE + app).apply()
            return null
        }
        return uri
    }

    // ------------------------------------------------------------
    // LISTING
    // ------------------------------------------------------------

    private fun list(app: String): List<Map<String, Any>> {
        val tree = treeFor(app) ?: return emptyList()

        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_SIZE,
        )

        val items = mutableListOf<Map<String, Any>>()

        context.contentResolver.query(children, columns, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val id = c.getString(0) ?: continue
                val name = c.getString(1) ?: continue
                val mime = c.getString(2) ?: ""
                if (name.startsWith(".")) continue

                val video = mime.startsWith("video/")
                if (!video && !mime.startsWith("image/")) continue

                items += mapOf(
                    "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                    "name" to name,
                    "video" to video,
                    "modified" to c.getLong(3),
                    "size" to c.getLong(4),
                )
            }
        }

        return items.sortedByDescending { it["modified"] as Long }
    }

    // ------------------------------------------------------------
    // THUMBNAILS
    // ------------------------------------------------------------

    private fun thumbnail(uri: Uri, video: Boolean): ByteArray? {
        val bitmap = (if (video) videoFrame(uri) else scaledImage(uri)) ?: return null

        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
            bitmap.recycle()
            out.toByteArray()
        }
    }

    private fun scaledImage(uri: Uri): Bitmap? {
        val resolver = context.contentResolver

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0) return null

        var sample = 1
        while (bounds.outWidth / (sample * 2) >= THUMB_SIZE &&
            bounds.outHeight / (sample * 2) >= THUMB_SIZE
        ) {
            sample *= 2
        }

        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, options)
        }
    }

    private fun videoFrame(uri: Uri): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, uri)
            val frame = retriever.getFrameAtTime(0) ?: return null
            val scale = THUMB_SIZE.toFloat() / maxOf(frame.width, frame.height)
            if (scale >= 1f) return frame

            val scaled = Bitmap.createScaledBitmap(
                frame,
                (frame.width * scale).toInt(),
                (frame.height * scale).toInt(),
                true,
            )
            if (scaled != frame) frame.recycle()
            scaled
        } catch (e: Exception) {
            null
        } finally {
            retriever.release()
        }
    }

    // ------------------------------------------------------------
    // SAVING
    // ------------------------------------------------------------

    /**
     * Copies the status into the app's cache so the gallery can take it from
     * a plain file path. The caller deletes the copy afterwards.
     */
    private fun copyToCache(uri: Uri, name: String): String {
        val dir = File(context.cacheDir, "status").apply { mkdirs() }
        val safeName = name.replace(Regex("[^A-Za-z0-9._]"), "_")
        val target = File(dir, "VideoSaver_Status_$safeName")

        context.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "The status could not be opened." }
            target.outputStream().use { input.copyTo(it) }
        }
        return target.absolutePath
    }

    // ------------------------------------------------------------

    private fun <T> background(result: MethodChannel.Result, work: () -> T) {
        worker.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("status_error", e.message, null) }
            }
        }
    }

    companion object {
        const val CHANNEL = "com.ezitech.ezisaver/status"

        private const val REQUEST_TREE = 7302
        private const val KEY_TREE = "tree_"
        private const val THUMB_SIZE = 360
        private const val STORAGE_AUTHORITY = "com.android.externalstorage.documents"

        private const val APP_MAIN = "whatsapp"
        private const val APP_BUSINESS = "business"

        /**
         * Where the app keeps viewed statuses. Since Android 11 it moved
         * under Android/media; older phones keep the original location.
         */
        private fun statusesDocId(app: String): String {
            val modern = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
            return when {
                app == APP_BUSINESS && modern ->
                    "primary:Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses"
                app == APP_BUSINESS ->
                    "primary:WhatsApp Business/Media/.Statuses"
                modern ->
                    "primary:Android/media/com.whatsapp/WhatsApp/Media/.Statuses"
                else ->
                    "primary:WhatsApp/Media/.Statuses"
            }
        }
    }
}
