package com.ezitech.ezisaver

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Puts a downloaded video into the phone's gallery, the way Android documents
 * it should be done.
 *
 * The gal plugin this replaces put videos under Pictures/, gave MediaStore no
 * MIME type, and made the row visible while it was still zero bytes. Most
 * phones coped. On 22 Oct 2026 a user's phone downloaded three Facebook
 * videos in full — the server logs show every byte delivered — and none of
 * them reached his gallery. Writing it properly closes off each way that can
 * happen:
 *
 *  - Movies/EziDownload, the folder every gallery treats as video;
 *  - an explicit video/mp4 type, so nothing has to guess from the name;
 *  - IS_PENDING while writing, so a gallery that scans early never caches a
 *    half-written file as broken and then hides it;
 *  - and the content URI handed back, so the app can open what it saved.
 */
object GallerySaver {

    private const val ALBUM = "EziDownload"

    /** Saves [source] as [displayName]. Returns the gallery URI; throws on failure. */
    fun saveVideo(context: Context, source: File, displayName: String): Uri {
        require(source.exists() && source.length() > 0) { "The downloaded file is empty." }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveScoped(context, source, displayName)
        } else {
            saveLegacy(context, source, displayName)
        }
    }

    /** Android 10 and later: MediaStore, no storage permission needed. */
    private fun saveScoped(context: Context, source: File, displayName: String): Uri {
        val resolver = context.contentResolver
        val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

        val now = System.currentTimeMillis()
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/$ALBUM")
            put(MediaStore.Video.Media.DATE_TAKEN, now)
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }

        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("The gallery would not accept the video.")

        try {
            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(source).use { input -> input.copyTo(out, 64 * 1024) }
            } ?: throw IllegalStateException("The gallery file could not be opened.")

            val done = ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }
            resolver.update(uri, done, null, null)
            return uri
        } catch (e: Exception) {
            // A pending row left behind shows up nowhere but still takes a
            // name, so the next attempt would be saved as "name (1)".
            runCatching { resolver.delete(uri, null, null) }
            throw e
        }
    }

    /** Android 9 and earlier: a real file, then ask the scanner to index it. */
    private fun saveLegacy(context: Context, source: File, displayName: String): Uri {
        @Suppress("DEPRECATION")
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), ALBUM)
        if (!dir.exists() && !dir.mkdirs()) {
            throw IllegalStateException("Could not create the $ALBUM folder.")
        }

        val target = uniqueFile(dir, displayName)
        source.copyTo(target, overwrite = false)

        // The scanner answers asynchronously; wait briefly for the URI so the
        // app can offer to open the video, but never hang the save on it.
        var scanned: Uri? = null
        val latch = CountDownLatch(1)
        MediaScannerConnection.scanFile(
            context,
            arrayOf(target.absolutePath),
            arrayOf("video/mp4"),
        ) { _, uri ->
            scanned = uri
            latch.countDown()
        }
        latch.await(5, TimeUnit.SECONDS)

        return scanned ?: Uri.fromFile(target)
    }

    private fun uniqueFile(dir: File, displayName: String): File {
        val dot = displayName.lastIndexOf('.')
        val base = if (dot > 0) displayName.substring(0, dot) else displayName
        val ext = if (dot > 0) displayName.substring(dot) else ".mp4"

        var candidate = File(dir, displayName)
        var n = 1
        while (candidate.exists()) {
            candidate = File(dir, "$base ($n)$ext")
            n++
        }
        return candidate
    }

    /**
     * Brings back the videos the gal plugin saved but the gallery hid.
     *
     * gal inserted each gallery row before writing a byte, with no pending
     * flag, so a gallery that indexed the row straight away saw an empty video
     * and kept hiding it — the user's file manager listed every video in
     * Pictures/EziDownload while the gallery showed one. Moving those videos
     * into Movies/EziDownload makes Android index each one afresh, now that
     * the file is complete, and puts old and new saves in one album.
     *
     * Runs once; anything that cannot be moved is just rescanned in place.
     */
    fun repairOldSaves(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return

        val prefs = context.getSharedPreferences("gallery_saver", Context.MODE_PRIVATE)
        if (prefs.getBoolean("old_saves_repaired", false)) return

        val resolver = context.contentResolver
        val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val leftOver = mutableListOf<String>()

        runCatching {
            @Suppress("DEPRECATION")
            resolver.query(
                collection,
                arrayOf(MediaStore.Video.Media._ID, MediaStore.Video.Media.DATA),
                "${MediaStore.Video.Media.RELATIVE_PATH} LIKE ?",
                arrayOf("${Environment.DIRECTORY_PICTURES}/$ALBUM%"),
                null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val uri = android.content.ContentUris.withAppendedId(collection, cursor.getLong(0))
                    val moved = runCatching {
                        val values = ContentValues().apply {
                            put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/$ALBUM")
                        }
                        resolver.update(uri, values, null, null) > 0
                    }.getOrDefault(false)

                    if (!moved) cursor.getString(1)?.let { leftOver.add(it) }
                }
            }
        }

        if (leftOver.isNotEmpty()) {
            MediaScannerConnection.scanFile(
                context,
                leftOver.toTypedArray(),
                Array(leftOver.size) { "video/mp4" },
                null,
            )
        }

        prefs.edit().putBoolean("old_saves_repaired", true).apply()
    }

    /** Opens a saved video in whatever player the phone has. */
    fun open(context: Context, uri: Uri) {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "video/*")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    /** "Xiaomi Redmi Note 12 / Android 13 (33)" — for failure reports. */
    fun deviceLabel(): String =
        "${Build.MANUFACTURER} ${Build.MODEL} / Android ${Build.VERSION.RELEASE} (${Build.VERSION.SDK_INT})"
}
