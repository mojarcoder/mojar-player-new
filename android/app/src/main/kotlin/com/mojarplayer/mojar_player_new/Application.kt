package com.mojarplayer.mojar_player_pro

import androidx.multidex.MultiDexApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Custom Application class for Mojar Player
 * Extends MultiDexApplication to handle apps with large method counts
 */
class Application : MultiDexApplication() {
    
    companion object {
        const val FLUTTER_ENGINE_ID = "mojar_player_engine"
    }
    
    lateinit var flutterEngine: FlutterEngine
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize FlutterEngine
        flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        
        // Register all plugins
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // Cache the FlutterEngine for later use
        FlutterEngineCache.getInstance().put(FLUTTER_ENGINE_ID, flutterEngine)
    }
} 