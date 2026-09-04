package com.ffarena.ff_arena

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.ffarena.ff_arena/sms"
        const val SMS_PERMISSION_REQUEST = 7001
        var methodChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method != "requestSmsPermission") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val readGranted = ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
            val receiveGranted = ActivityCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
            if (readGranted && receiveGranted) {
                result.success(true)
            } else {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
                    SMS_PERMISSION_REQUEST
                )
                result.success(false)
            }
        }
    }
}
