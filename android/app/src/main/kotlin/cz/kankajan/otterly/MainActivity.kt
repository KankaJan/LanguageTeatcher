package cz.kankajan.otterly

import android.content.Context
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
                flutterEngine.plugins.add(GoogleMlKitTranslationPlugin())
            }
        } catch (_: Throwable) {
            // Translation stays unavailable; the app copes (pack creation
            // shows an error, everything else works).
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
        } catch (_: Throwable) {
            // Already initialized, or this ML Kit version handles it itself.
        }
    }
}
