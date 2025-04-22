# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }

# Video Player rules
-keep class com.google.android.exoplayer2.** { *; }
-dontnote com.google.android.exoplayer2.**

# Just Audio rules
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media2.** { *; }

# Permissions plugins
-keep class com.baseflow.permissionhandler.** { *; }

# File picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Path provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep custom components
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
}

# Keep all model classes used in your app
-keep class com.mojarplayer.** { *; } 