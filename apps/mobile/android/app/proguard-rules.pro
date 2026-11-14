# Preserve Flutter PlatformView, Plugin, and MethodChannel interfaces accessed
# dynamically at runtime via JNI / PortProxyBuilder (java.lang.reflect.Proxy)
# by maplibre_android and jni_flutter in release (R8) builds.
-keep class io.flutter.plugin.platform.** { *; }
-keep interface io.flutter.plugin.platform.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep interface io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep interface io.flutter.plugin.common.** { *; }

# Preserve MapLibre Android plugin and JNI bridge classes
-keep class com.github.josxha.maplibre.** { *; }
-keep interface com.github.josxha.maplibre.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
-keep class org.maplibre.** { *; }
-keep class com.google.gson.** { *; }
