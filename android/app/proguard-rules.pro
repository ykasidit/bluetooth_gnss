# ============================================================================
# ProGuard/R8 rules for Bluetooth GNSS / BatRay
# ============================================================================

# --- JNI: Rust native methods (NativeParser) ---
# R8 must not rename or remove classes/methods called from native code via JNI
-keep class com.clearevo.libbluetooth_gnss_service.NativeParser {
    native <methods>;
    *;
}

# --- Keep all service library classes (referenced from manifest, callbacks, threads) ---
-keep class com.clearevo.libbluetooth_gnss_service.** { *; }

# --- Keep all app classes (MainActivity, BroadcastReceivers, Util) ---
-keep class com.clearevo.bluetooth_gnss.** { *; }

# --- Gson: uses reflection for serialization/deserialization ---
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
# Keep fields that Gson accesses via reflection (HashMap<String,Object> in Util)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}


# --- microg location services ---
-keep class org.microg.** { *; }

# --- Flutter ---
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# --- General: keep native method declarations ---
-keepclasseswithmembernames class * {
    native <methods>;
}
