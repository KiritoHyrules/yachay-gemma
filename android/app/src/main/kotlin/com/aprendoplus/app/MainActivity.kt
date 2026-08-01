package com.aprendoplus.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val KEYSTORE_CHANNEL = "keystore"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ---- keystore channel (Phase 1) ----
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KEYSTORE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getKey" -> {
                    result.notImplemented()
                }
                "storeKey" -> {
                    result.notImplemented()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
