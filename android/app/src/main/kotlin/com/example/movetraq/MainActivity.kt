package com.example.movetraq

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "movetraq/map_config"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGoogleMapsApiKeyConfigured" -> result.success(mapsApiKey().isNotBlank())
                "googleMapsDiagnostics" -> result.success(
                    mapOf(
                        "packageName" to packageName,
                        "sha1" to signingSha1(),
                        "keyConfigured" to mapsApiKey().isNotBlank(),
                    )
                )
                else -> result.notImplemented()
            }
        }

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

    private fun mapsApiKey(): String {
        val metadata = packageManager
            .getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            .metaData
        val key = metadata?.getString("com.google.android.geo.API_KEY").orEmpty()
        return if (key.contains("$")) "" else key
    }

    private fun signingSha1(): String {
        val signatures = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            packageManager
                .getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                .signingInfo
                ?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            packageManager
                .getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                .signatures
        } ?: return ""

        val cert = signatures.firstOrNull()?.toByteArray() ?: return ""
        val digest = MessageDigest.getInstance("SHA1").digest(cert)
        return digest.joinToString(":") { byte -> "%02X".format(byte) }
    }
}
