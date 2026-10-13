package com.doctagri.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "doctagri/installations")
            .setMethodCallHandler { call, result ->
                if (call.method != "register") {
                    result.notImplemented()
                } else {
                    try {
                        InstallationRegistration.schedule(
                            applicationContext,
                            call.argument<String>("url") ?: "",
                            call.argument<String>("anonKey") ?: "",
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("registration_unavailable", "Enregistrement différé indisponible", null)
                    }
                }
            }
    }
}
