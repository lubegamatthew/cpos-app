package com.example.cpos

import android.content.Context
import android.content.pm.PackageInfo
import dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.shim.ShimPluginRegistry
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val VERSION_CHANNEL = "com.example.cpos/version"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // 1. Manually register package_info_plus (FlutterPlugin v2)
        //    super.configureFlutterEngine() doesn't auto-register plugins
        //    when configureFlutterEngine is overridden in older toolchains.
        PackageInfoPlugin().apply {
            onAttachedToEngine(flutterEngine)
        }

        // 2. Custom method channel — reads versionName / versionCode
        //    directly from the installed APK's PackageInfo (0-plugin fallback).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VERSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getVersionInfo" -> {
                        try {
                            val pkgInfo: PackageInfo =
                                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                                    packageManager.getPackageInfo(
                                        packageName,
                                        PackageInfo.PackageInfoFlags.of(0),
                                    )
                                } else {
                                    @Suppress("DEPRECATION")
                                    packageManager.getPackageInfo(packageName, 0)
                                }

                            val versionCode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                                pkgInfo.longVersionCode
                            } else {
                                @Suppress("DEPRECATION")
                                pkgInfo.versionCode.toLong()
                            }

                            result.success(
                                mapOf(
                                    "versionName"  to (pkgInfo.versionName ?: ""),
                                    "versionCode"  to versionCode,
                                )
                            )
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
