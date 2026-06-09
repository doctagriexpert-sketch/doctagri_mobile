# ── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── TensorFlow Lite (tflite_flutter) ─────────────────────────────────────────
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keepclassmembers class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.**

# ── Hive (local storage) ──────────────────────────────────────────────────────
# Hive adapters are referenced by generated code — keep them all
-keep class * extends com.google.flatbuffers.Table { *; }
-keep class com.doctagri.app.** { *; }

# ── Kotlin ───────────────────────────────────────────────────────────────────
-dontwarn kotlin.**
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ── Kotlin coroutines ─────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ── Supabase / Ktor / OkHttp ─────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keep class io.github.jan.supabase.** { *; }
-keepattributes RuntimeVisibleAnnotations

# ── Speech to text (speech_to_text) ──────────────────────────────────────────
-keep class com.csdcorp.speech_to_text.** { *; }

# ── Flutter TTS (flutter_tts) ─────────────────────────────────────────────────
-keep class com.tundralabs.fluttertts.** { *; }

# ── Camera plugin ─────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.camera.** { *; }

# ── Geolocator ────────────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }

# ── Permission handler ────────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ── Connectivity Plus ─────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ── Image picker ──────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }

# ── Shared Preferences / Hive Flutter ────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── Enums (referenced by name at runtime) ────────────────────────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ── Serialization (JSON / protobuf) ──────────────────────────────────────────
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ── Native methods ────────────────────────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── R8 / ProGuard optimisation ────────────────────────────────────────────────
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
