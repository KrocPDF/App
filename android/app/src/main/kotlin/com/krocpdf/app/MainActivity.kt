package com.krocpdf.app

import android.content.Intent
import android.net.Uri
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.krocpdf.app/demo_uninstall")
            .setMethodCallHandler { call, result ->
                if (call.method == "uninstallApp") {
                    try {
                        val intent = Intent(Intent.ACTION_DELETE).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNINSTALL_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
