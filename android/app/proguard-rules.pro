# SQLCipher — preserve native symbols required for encrypted database
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-dontwarn net.sqlcipher.**
-keep,includedescriptorclasses class org.sqlite.** { *; }
-keep,includedescriptorclasses class org.sqlite.database.** { *; }

# JNI — preserve native method declarations and JNI bridge
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class * extends java.lang.NativeLong {
    <fields>;
}

# Kotlin coroutines and serialization
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Connectivity Plus — network callback classes
-keep class * implements android.net.ConnectivityManager$NetworkCallback { *; }

# Flutter embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
