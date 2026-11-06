package com.rizumiya.notifymee

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        Log.i(TAG, "BootReceiver received action: ${intent?.action}. Ensuring NotificationService is active...")

        NotificationService.triggerRebind(context)

        try {
            val serviceIntent = Intent(context, NotificationService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start NotificationService from BootReceiver: ${e.message}")
        }
    }
}

