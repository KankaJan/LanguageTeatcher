package cz.kankajan.otterly

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.util.concurrent.Executors

/**
 * Thin bridge to the Vosk engine: loads the downloaded model once and scores
 * one attempt recording (16 kHz mono PCM WAV) against a small grammar of
 * candidate words. All native work runs off the main thread.
 */
class VoskScorerChannel : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "otterly/vosk"
        private const val SAMPLE_RATE = 16000.0f
        private const val CHUNK_BYTES = 8000
    }

    private var model: Model? = null
    private var modelPath: String? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initModel" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "path missing", null)
                    return
                }
                executor.execute {
                    // Throwable, not Exception: the Vosk/JNA native bridge
                    // fails with Errors (UnsatisfiedLinkError, native aborts
                    // on a bad model) and an uncaught Error on this thread
                    // would kill the whole app. Any failure here must instead
                    // surface as a PlatformException, which the Dart side
                    // swallows — the attempt then simply stays parent-graded.
                    try {
                        // Switching language packs loads a different model.
                        if (model == null || modelPath != path) {
                            if (!looksLikeVoskModel(File(path))) {
                                throw IllegalStateException(
                                    "no Vosk model at $path")
                            }
                            model?.close()
                            model = null
                            modelPath = null
                            model = Model(path)
                            modelPath = path
                        }
                        mainHandler.post { result.success(true) }
                    } catch (e: Throwable) {
                        mainHandler.post { result.error("init_failed", e.message, null) }
                    }
                }
            }
            "scoreFile" -> {
                val path = call.argument<String>("path")
                val grammar = call.argument<String>("grammar")
                val loaded = model
                if (path == null || grammar == null) {
                    result.error("bad_args", "path or grammar missing", null)
                    return
                }
                if (loaded == null) {
                    result.error("no_model", "initModel must be called first", null)
                    return
                }
                executor.execute {
                    try {
                        val out = score(loaded, path, grammar)
                        mainHandler.post { result.success(out) }
                    } catch (e: Throwable) {
                        mainHandler.post { result.error("score_failed", e.message, null) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    /** A Vosk model directory contains an acoustic model and configs. */
    private fun looksLikeVoskModel(dir: File): Boolean {
        if (!dir.isDirectory) return false
        val entries = dir.list()?.toSet() ?: return false
        return "am" in entries || "conf" in entries || "mfcc.conf" in entries ||
            "final.mdl" in entries
    }

    private fun score(model: Model, path: String, grammar: String): Map<String, Any> {
        val pcm = stripWavHeader(File(path).readBytes())
        val recognizer = Recognizer(model, SAMPLE_RATE, grammar)
        try {
            recognizer.setWords(true)
            var offset = 0
            while (offset < pcm.size) {
                val len = minOf(CHUNK_BYTES, pcm.size - offset)
                recognizer.acceptWaveForm(pcm.copyOfRange(offset, offset + len), len)
                offset += len
            }
            val json = JSONObject(recognizer.finalResult)
            val text = json.optString("text", "")
            val words = json.optJSONArray("result")
            var confidence = 0.0
            if (words != null && words.length() > 0) {
                var sum = 0.0
                for (i in 0 until words.length()) {
                    sum += words.getJSONObject(i).optDouble("conf", 0.0)
                }
                confidence = sum / words.length()
            }
            return mapOf("text" to text, "confidence" to confidence)
        } finally {
            recognizer.close()
        }
    }

    /** Returns the PCM payload of a RIFF/WAV file (the "data" chunk). */
    private fun stripWavHeader(bytes: ByteArray): ByteArray {
        var i = 12
        while (i + 8 <= bytes.size) {
            val id = String(bytes, i, 4, Charsets.US_ASCII)
            val size = (bytes[i + 4].toInt() and 0xFF) or
                ((bytes[i + 5].toInt() and 0xFF) shl 8) or
                ((bytes[i + 6].toInt() and 0xFF) shl 16) or
                ((bytes[i + 7].toInt() and 0xFF) shl 24)
            if (id == "data") {
                val start = i + 8
                return bytes.copyOfRange(start, minOf(bytes.size, start + size))
            }
            i += 8 + size + (size and 1)
        }
        // Not a well-formed RIFF: assume the canonical 44-byte header.
        return if (bytes.size > 44) bytes.copyOfRange(44, bytes.size) else ByteArray(0)
    }
}
