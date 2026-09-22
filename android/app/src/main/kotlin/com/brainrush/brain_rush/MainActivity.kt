package com.brainrush.brain_rush

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "brain_rush/sound_effects"
    private var tone: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            if (call.method != "play") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val cue = call.arguments as? String ?: "tap"
            val kind = when (cue) {
                "incorrect", "timeUp" -> ToneGenerator.TONE_PROP_NACK
                "streak", "achievement", "levelUp" -> ToneGenerator.TONE_PROP_ACK
                "fast" -> ToneGenerator.TONE_DTMF_9
                "countdown" -> ToneGenerator.TONE_DTMF_1
                else -> ToneGenerator.TONE_PROP_BEEP
            }
            val duration = when (cue) {
                "levelUp", "achievement" -> 180
                "streak" -> 130
                "timeUp" -> 170
                else -> 75
            }
            if (tone == null) tone = ToneGenerator(AudioManager.STREAM_MUSIC, 20)
            tone?.stopTone()
            tone?.startTone(kind, duration)
            result.success(null)
        }
    }

    override fun onDestroy() {
        tone?.release()
        tone = null
        super.onDestroy()
    }
}
