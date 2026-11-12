package com.krocpdf.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
