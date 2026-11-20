package com.example.midiflow

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "midiflow/bridge",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startForegroundService(
                        Intent(this, BridgeForegroundService::class.java),
                    )
                    result.success(null)
                }
                "stopService" -> {
                    stopService(Intent(this, BridgeForegroundService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
