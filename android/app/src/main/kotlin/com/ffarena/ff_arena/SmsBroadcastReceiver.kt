package com.ffarena.ff_arena

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Native Android BroadcastReceiver for incoming SMS.
 *
 * When a new SMS arrives on the admin's phone (even when the app is closed),
 * this receiver wakes up, extracts the sender and body, and forwards them
 * to the Flutter layer via [MainActivity.methodChannel].
 *
 * The Flutter SmsListenerService then parses the UPI payment details and
 * saves them to Firestore bank_receipts collection.
 */
class SmsBroadcastReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        // Group multi-part SMS by sender
        val grouped = mutableMapOf<String, StringBuilder>()
        for (msg in messages) {
            val sender = msg.originatingAddress ?: "UNKNOWN"
            grouped.getOrPut(sender) { StringBuilder() }.append(msg.messageBody)
        }

        // Forward each message to Flutter via MethodChannel
        for ((sender, bodyBuilder) in grouped) {
            val body = bodyBuilder.toString()
            android.util.Log.d("SmsBroadcastReceiver", "SMS from $sender: $body")

            // Post to main thread — MethodChannel requires it
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                MainActivity.methodChannel?.invokeMethod(
                    "onSmsReceived",
                    mapOf("sender" to sender, "body" to body)
                )
            }
        }
    }
}
