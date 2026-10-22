package cz.kankajan.otterly

import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google_mlkit_translation.GoogleMlKitTranslationPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // The ML Kit translation plugin's registration constructs
        // RemoteModelManager eagerly; on devices where ML Kit's automatic
        // init provider did not run, that throws, Flutter skips the plugin,
        // and every call on its channel fails with MissingPluginException.
        // Initialize ML Kit explicitly first (reflection: the class lives in
        // an sdkinternal package and must not break the build if it moves).
        initializeMlKit(applicationContext)

        super.configureFlutterEngine(flutterEngine)

        // If the automatic registration still failed, retry it now that
        // ML Kit is initialized.
        try {
            if (!flutterEngine.plugins.has(GoogleMlKitTranslationPlugin::class.java)) {
                Log.w(TAG, "ML Kit translation plugin was not registered automatically; retrying")
                flutterEngine.plugins.add(GoogleMlKitTranslationPlugin())
            }
        } catch (t: Throwable) {
            // Translation stays unavailable; the app copes (pack creation
            // shows an error, everything else works). Log the reason — this
            // is the only place the registration failure is visible.
            Log.e(TAG, "ML Kit translation plugin registration failed: "
                + VoskScorerChannel.describe(t), t)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VoskScorerChannel.NAME,
        ).setMethodCallHandler(VoskScorerChannel())
    }

    private fun initializeMlKit(context: Context) {
        try {
            val clazz = Class.forName("com.google.mlkit.common.sdkinternal.MlKitContext")
            val method = try {
                clazz.getMethod("initializeIfNeeded", Context::class.java)
            } catch (_: NoSuchMethodException) {
                clazz.getMethod("initialize", Context::class.java)
            }
            method.invoke(null, context)
        } catch (t: Throwable) {
            // Already initialized, or this ML Kit version handles it itself.
            // Logged at warn level because a ClassNotFoundException here means
            // the reflection target moved and the self-heal is a no-op.
            Log.w(TAG, "ML Kit explicit init skipped: " + VoskScorerChannel.describe(t))
        }
    }

    companion object {
        private const val TAG = "Otterly"
    }
}
