package com.example.cpos

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity : FlutterActivity() {
    companion object {
        private const val VERSION_CHANNEL = "com.example.cpos/version"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Custom method channel — reads versionName / versionCode directly
        // from the APK manifest via PackageManager.
        // On Android < TIRAMISU use deprecated API (0 flag).
        // On Android >= P use longVersionCode, else versionCode.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VERSION_CHANNEL)
            .setMethodCallHandler(MethodCallHandler { call, result ->
                if (call.method != "getVersionInfo") {
                    result.notImplemented()
                    return@MethodCallHandler
                }

                try {
                    val pkgInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        packageManager.getPackageInfo(
                            packageName,
                            0,   // GET_META_DATA = 0; safe on all API levels
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        packageManager.getPackageInfo(packageName, 0)
                    }

                    @Suppress("DEPRECATION")
                    val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        pkgInfo.longVersionCode
                    } else {
                        pkgInfo.versionCode.toLong()
                    }

                    result.success(
                        mapOf(
                            "versionName" to (pkgInfo.versionName ?: ""),
                            "versionCode" to versionCode,
                        )
                    )
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", e.message, null)
                }
            })
    }
}
