# ⭐️ 最關鍵的 Flutter 核心保護 (你原本漏掉的)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.** { *; }

# Google Play Core
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Google ML Kit & GMS
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.android.gms.**

# Flutter deferred components
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# 通用安全規則
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception