package com.example.free_reader

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    companion object {
        private const val PICK_RESOURCE_FILE_REQUEST = 4107
    }

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var ttsChannel: MethodChannel? = null
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tts = TextToSpeech(this, this)

        ttsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "free_reader/tts"
        )
        ttsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text").orEmpty()
                    speak(text)
                    result.success(null)
                }
                "speakSegments" -> {
                    val segments = call.argument<List<Map<String, Any>>>("segments").orEmpty()
                    speakSegments(segments)
                    result.success(null)
                }
                "stop" -> {
                    tts?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "free_reader/files"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickResourceFile" -> {
                    pickResourceFile(result)
                }
                "openDirectory" -> {
                    val path = call.argument<String>("path").orEmpty()
                    result.success(openDirectory(path))
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_RESOURCE_FILE_REQUEST) {
            return
        }

        val result = pendingPickResult ?: return
        pendingPickResult = null

        if (resultCode != RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        try {
            result.success(copyPickedResourceToCache(data.data!!))
        } catch (error: Throwable) {
            result.error("PICK_RESOURCE_FAILED", error.message, null)
        }
    }

    override fun onInit(status: Int) {
        ttsReady = status == TextToSpeech.SUCCESS
        if (ttsReady) {
            tts?.language = Locale.CHINA
            tts?.setSpeechRate(0.92f)
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {
                    sendTtsProgress(utteranceId)
                }

                override fun onDone(utteranceId: String?) = Unit

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) = Unit
            })
        }
    }

    private fun speak(text: String) {
        if (!ttsReady || text.isBlank()) {
            return
        }

        tts?.stop()
        val chunks = text.chunked(1800)
        chunks.forEachIndexed { index, chunk ->
            val params = Bundle()
            val queueMode = if (index == 0) {
                TextToSpeech.QUEUE_FLUSH
            } else {
                TextToSpeech.QUEUE_ADD
            }
            tts?.speak(chunk, queueMode, params, "free_reader_tts_$index")
        }
    }

    private fun speakSegments(segments: List<Map<String, Any>>) {
        if (!ttsReady || segments.isEmpty()) {
            return
        }

        tts?.stop()
        segments.forEachIndexed { index, segment ->
            val text = segment["text"] as? String ?: ""
            if (text.isBlank()) {
                return@forEachIndexed
            }

            val segmentId = segment["id"] as? String ?: ""
            val utteranceId = if (segmentId.isBlank()) {
                "segment_$index"
            } else {
                segmentId
            }
            val params = Bundle()
            val queueMode = if (index == 0) {
                TextToSpeech.QUEUE_FLUSH
            } else {
                TextToSpeech.QUEUE_ADD
            }
            tts?.speak(text, queueMode, params, utteranceId)
        }
    }

    private fun sendTtsProgress(segmentId: String?) {
        if (segmentId.isNullOrBlank() || segmentId.startsWith("free_reader_tts_")) {
            return
        }

        runOnUiThread {
            ttsChannel?.invokeMethod(
                "onProgress",
                mapOf("segmentId" to segmentId)
            )
        }
    }

    private fun openDirectory(path: String): Boolean {
        if (path.isBlank()) {
            return false
        }

        val directory = File(path)
        if (!directory.exists()) {
            return false
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(directory.toURI().toString()), "resource/folder")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        return try {
            startActivity(Intent.createChooser(intent, "Open folder"))
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Throwable) {
            false
        }
    }

    private fun pickResourceFile(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("PICK_IN_PROGRESS", "A file picker is already open.", null)
            return
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/x-sqlite3",
                    "application/vnd.sqlite3",
                    "application/epub+zip",
                    "application/pdf",
                    "text/plain",
                    "text/markdown",
                    "application/octet-stream"
                )
            )
        }

        try {
            pendingPickResult = result
            startActivityForResult(intent, PICK_RESOURCE_FILE_REQUEST)
        } catch (error: ActivityNotFoundException) {
            pendingPickResult = null
            result.error("NO_FILE_PICKER", error.message, null)
        }
    }

    private fun copyPickedResourceToCache(uri: Uri): Map<String, Any?> {
        val metadata = queryDisplayMetadata(uri)
        val name = metadata.first
        val mimeType = contentResolver.getType(uri)
        val importDirectory = File(cacheDir, "resource-imports").apply {
            mkdirs()
        }
        val target = uniqueCacheFile(importDirectory, name)

        contentResolver.openInputStream(uri).use { input ->
            if (input == null) {
                throw IllegalStateException("Unable to open selected file.")
            }
            FileOutputStream(target).use { output ->
                input.copyTo(output)
            }
        }

        return mapOf(
            "name" to name,
            "tempPath" to target.absolutePath,
            "size" to target.length(),
            "mimeType" to mimeType
        )
    }

    private fun queryDisplayMetadata(uri: Uri): Pair<String, Long> {
        contentResolver.query(uri, null, null, null, null).use { cursor ->
            if (cursor != null && cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                val name = if (nameIndex >= 0) {
                    cursor.getString(nameIndex)
                } else {
                    null
                }
                val size = if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                    cursor.getLong(sizeIndex)
                } else {
                    -1L
                }
                return Pair(name ?: "resource", size)
            }
        }

        return Pair(uri.lastPathSegment ?: "resource", -1L)
    }

    private fun uniqueCacheFile(directory: File, originalName: String): File {
        val sanitized = originalName.replace(Regex("""[\\/:*?"<>|]"""), "_")
        val safeName = if (sanitized.isBlank()) "resource" else sanitized
        val dotIndex = safeName.lastIndexOf('.')
        val baseName = if (dotIndex > 0) safeName.substring(0, dotIndex) else safeName
        val extension = if (dotIndex > 0) safeName.substring(dotIndex) else ""
        var candidate = File(directory, safeName)
        var index = 2
        while (candidate.exists()) {
            candidate = File(directory, "$baseName-$index$extension")
            index++
        }
        return candidate
    }

    override fun onDestroy() {
        pendingPickResult?.success(null)
        pendingPickResult = null
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
}
