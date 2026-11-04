package com.krocpdf.app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.krocpdf.app/launch_params")
            .setMethodCallHandler { call, result ->
                if (call.method == "getDebugT") {
                    try {
                        val raw = intent?.extras?.get("t")
                        val tVal = when (raw) {
                            is Number -> raw.toDouble()
                            is String -> raw.toDoubleOrNull()
                            else -> null
                        }
                        result.success(tVal)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
