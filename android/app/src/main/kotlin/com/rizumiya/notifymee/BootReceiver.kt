package com.rizumiya.notifymee

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
        private val ALLOWED_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.rizumiya.notifymee.ACTION_RESURRECT_SERVICE"
        )
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        val action = intent?.action ?: return
        if (action !in ALLOWED_ACTIONS) return

        val appContext = context.applicationContext
        val isListenerPermGranted = NotificationManagerCompat
            .getEnabledListenerPackages(appContext)
            .contains(appContext.packageName)

        if (!isListenerPermGranted) {
            Log.w(TAG, "BootReceiver ($action): Notification listener permission not granted yet.")
            return
        }

        Log.i(TAG, "BootReceiver received $action. Ensuring NotificationService is bound and foregrounded...")

        if (!NotificationService.isServiceRunning) {
            NotificationService.requestSafeRebind(appContext)
        }
        NotificationService.startForegroundService(appContext)
    }
}
