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
                    val floatT = intent?.getFloatExtra("t", -1f) ?: -1f
                    if (floatT >= 0f) {
                        result.success(floatT.toDouble())
                    } else {
                        val doubleT = intent?.getDoubleExtra("t", -1.0) ?: -1.0
                        if (doubleT >= 0.0) {
                            result.success(doubleT)
                        } else {
                            val strT = intent?.getStringExtra("t")?.toDoubleOrNull()
                            if (strT != null && strT >= 0.0) {
                                result.success(strT)
                            } else {
                                result.success(null)
                            }
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
