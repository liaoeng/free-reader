package com.example.free_reader

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var ttsChannel: MethodChannel? = null

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
                "openDirectory" -> {
                    val path = call.argument<String>("path").orEmpty()
                    result.success(openDirectory(path))
                }
                else -> result.notImplemented()
            }
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

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
}
