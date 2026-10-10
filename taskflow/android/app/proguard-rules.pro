# Mantener la información de tipos genéricos que Gson necesita en release.
# Sin esto, R8 rompe loadScheduledNotifications con
# PlatformException(error, Missing type parameter., ...).
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.** { *; }
