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
