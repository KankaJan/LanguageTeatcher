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
