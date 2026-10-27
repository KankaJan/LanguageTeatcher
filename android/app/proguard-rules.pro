# Flutter's Gradle plugin runs R8 on release builds. Vosk talks to libvosk.so
# through JNA direct mapping (Native.register): the Java method names ARE the
# native symbol names, so renaming or stripping either side breaks the
# bridge at runtime (UnsatisfiedLinkError / NoClassDefFoundError
# "org.vosk.LibVosk") while the build stays green.
-keep class org.vosk.** { *; }
-keep class com.sun.jna.** { *; }
-keep class * extends com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }
-dontwarn com.sun.jna.**
# JNA references desktop-only classes that do not exist on Android.
-dontwarn java.awt.**

# ML Kit discovers its components at startup (MlKitInitProvider) by reading
# registrar class names from manifest metadata and instantiating them through
# their no-argument constructor. R8 in full mode keeps a class name but drops
# an unreferenced <init>(), so the registrars survive and still cannot be
# instantiated: logcat shows "ComponentDiscovery: Could not instantiate
# ...NaturalLanguageTranslateRegistrar / NoSuchMethodException <init> []",
# followed by "GeneratedPluginRegistrant: Error registering plugin
# google_mlkit_translation" (NullPointerException), and every call on the
# translation channel then fails with MissingPluginException.
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-keep class com.google.mlkit.** implements com.google.firebase.components.ComponentRegistrar { <init>(); }

# Release builds: drop verbose/debug logging app-wide. ML Kit's Firebase
# installation client prints its installation id, refresh token and auth
# token at debug level, and the remote-config client prints whole responses;
# none of that belongs in a logcat a parent might paste into a bug report.
# Our own diagnostics use Log.w / Log.e and are kept.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
}
