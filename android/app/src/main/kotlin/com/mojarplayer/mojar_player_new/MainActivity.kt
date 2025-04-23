package com.mojarplayer.mojar_player_pro

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngineCache
import com.mojarplayer.mojar_player_pro.Application

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.mojarplayer.mojar_player_pro/system"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup method channel for native communication
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            // Handle method calls from Flutter
            when (call.method) {
                "keepScreenOn" -> {
                    try {
                        val enable = call.argument<Boolean>("enable") ?: false
                        keepScreenOn(enable)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SCREEN_ERROR", "Error toggling screen: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    // Keep screen on or off based on parameter
    private fun keepScreenOn(enable: Boolean) {
        if (enable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
    
    // Handle intent data if launched from another app
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Process any incoming intent
        processIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        // Process the new intent
        processIntent(intent)
    }
    
    private fun processIntent(intent: Intent) {
        // Process intent data (e.g., if opened with a media file)
        // This would be implemented to send file info to Flutter
    }
} 