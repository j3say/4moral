# Prevent R8 from removing KaraokeMediaHelper and related classes
-dontwarn com.google.**
-keep class com.google.** {*;}
-keep class **.zego.**  { *; }
-keep class **.**.zego_zpns.** { *; }
-keep class com.itgsa.opensdk.** { *; }
-keep class com.itgsa.opensdk.mediaunit.** { *; }
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
  public void onPayment*(...);
}

# Prevent R8 from removing Jackson classes
-keep class com.fasterxml.jackson.** { *; }
-keep class com.fasterxml.jackson.databind.ext.** { *; }

# Prevent R8 from removing Conscrypt
-keep class org.conscrypt.** { *; }

# Prevent R8 from removing DOM classes
-keep class org.w3c.dom.** { *; }
-keep class org.w3c.dom.bootstrap.** { *; }

# Avoid issues with java.beans package (not in Android)
-dontwarn java.beans.**
-dontwarn com.itgsa.opensdk.mediaunit.KaraokeMediaHelper
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.OpenSSLProvider
-dontwarn org.w3c.dom.bootstrap.DOMImplementationRegistry

# Keep ZEGOCLOUD classes and native interfaces
-keep class im.zego.** { *; }
-dontwarn im.zego.**

# Keep Flutter JNI
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.engine.**

# Needed for signaling plugin
-keep class com.zegocloud.** { *; }
-dontwarn com.zegocloud.**