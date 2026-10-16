package com.example.movetraq

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "movetraq/calls"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "dialPhone" -> {
                    val phone = call.argument<String>("phone").orEmpty().trim()
                    if (phone.isBlank()) {
                        result.error("missing_phone", "No phone number is available.", null)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))
                    if (intent.resolveActivity(packageManager) == null) {
                        result.error("dialer_unavailable", "No phone app is available on this device.", null)
                        return@setMethodCallHandler
                    }
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

}
