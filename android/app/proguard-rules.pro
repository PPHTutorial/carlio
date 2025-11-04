# Flutter wrapper (v2 embedding)
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.util.**  { *; }

# Preserve line number information for stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Flutter engine
-keep class io.flutter.embedding.** { *; }

# Keep plugin classes
-keep class * implements io.flutter.plugin.common.PluginRegistry { *; }
-keep class * extends io.flutter.plugin.common.PluginRegistry { *; }

# Keep all public classes in your app package
-keep public class com.codeink.stsl.carcollection.** { *; }

# Keep custom views and widgets
-keepclassmembers class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Preserve annotations
-keepattributes *Annotation*

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Keep data classes for JSON serialization
-keep class * implements java.io.Serializable { *; }
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep all Flutter/Dart classes that might be referenced
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Image processing (image package - Dart)
-dontwarn img.**

# Cache Manager and Storage
-dontwarn com.github.tekartik.sqflite.**
-dontwarn com.tekartik.sqflite.**
-dontwarn com.baseflow.fluttercachemanager.**

# HTTP and networking
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn retrofit2.**

# Shared Preferences - Android system class, already kept
-dontwarn android.content.SharedPreferences

# Path Provider
-dontwarn io.flutter.plugins.pathprovider.**

# SQLite
-dontwarn io.flutter.plugins.flutter_sqflite.**
-dontwarn com.tekartik.sqflite.**
-dontwarn android.database.**

# Provider - Dart package, no Java code
-dontwarn provider.**

# HTML parsing - Dart package
-dontwarn html.**

# Crypto - Dart package
-dontwarn crypto.**

# Photo View
-dontwarn com.renancarvalho.photo_view.**

# Carousel Slider
-dontwarn com.serenadercarousel.**

# Google Fonts - Dart package
-dontwarn fonts.**

# Cached Network Image
-dontwarn com.cached_network_image.**

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep classes that are referenced only via reflection
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Preserve JavaScript interface for WebView if used
-keepattributes JavascriptInterface
-keepattributes *JavascriptInterface*

# Keep annotation default values
-keepattributes AnnotationDefault

# Keep inner classes
-keepattributes InnerClasses
-keepclassmembers class * {
    *** *$*;
}

# Prevent R8 from removing classes/methods that might be needed
-dontoptimize
-dontpreverify

# Keep generic signatures for reflection
-keepattributes Signature
-keepattributes Exceptions

# Keep classes with main methods
-keepclasseswithmembers class * {
    public static void main(java.lang.String[]);
}

# Keep all constructors
-keepclassmembers class * {
    public <init>();
}

# Keep classes referenced in AndroidManifest
-keep class * extends android.app.Activity
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver
-keep class * extends android.content.ContentProvider

# Keep names of classes/methods/fields that might be accessed via reflection
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
}

# Additional R8 compatibility
-allowaccessmodification
-dontskipnonpubliclibraryclasses

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Authentication
-keep class com.google.firebase.auth.** { *; }
-dontwarn com.google.firebase.auth.**

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-dontwarn com.google.firebase.firestore.**

# Firebase Core
-keep class com.google.firebase.core.** { *; }
-dontwarn com.google.firebase.core.**

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.ads.**

# Keep AdMob classes
-keep class * extends com.google.android.gms.ads.** { *; }
-keep class * implements com.google.android.gms.ads.** { *; }

# Google Play Services
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.common.**
-dontwarn com.google.android.gms.tasks.**

# In-App Purchase
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Audio Players
-dontwarn xyz.luan.audioplayers.**

# WebView
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String);
}
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep MainActivity
-keep class com.codeink.stsl.carcollection.MainActivity { *; }

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep R class
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Gson (if used by Firebase)
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer