package com.rizumiya.notifymee

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.regex.Pattern

class NotificationService : NotificationListenerService() {

    companion object {
        private const val TAG = "NotifWebhookService"
        var isServiceRunning = false
        var instance: NotificationService? = null

        // Deduplication cache: key -> timestamp (ms) to avoid duplicate webhooks for the same message
        private val recentNotifications = java.util.concurrent.ConcurrentHashMap<String, Long>()
        private const val DEDUP_WINDOW_MS = 2500L

        private fun isDuplicate(key: String): Boolean {
            val now = System.currentTimeMillis()
            // Clean up entries older than 30 seconds
            val iterator = recentNotifications.entries.iterator()
            while (iterator.hasNext()) {
                val entry = iterator.next()
                if (now - entry.value > 30000L) {
                    iterator.remove()
                }
            }

            val lastTime = recentNotifications[key]
            if (lastTime != null && (now - lastTime) < DEDUP_WINDOW_MS) {
                return true
            }
            recentNotifications[key] = now
            return false
        }

        private const val FOREGROUND_CHANNEL_ID = "notifymee_gateway_channel"
        private const val FOREGROUND_NOTIFICATION_ID = 9001

        fun startForegroundService(context: Context) {
            try {
                val serviceIntent = Intent(context, NotificationService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to startForegroundService: ${e.message}")
            }
        }

        fun triggerRebind(context: Context) {
            try {
                val component = ComponentName(context, NotificationService::class.java)
                val pm = context.packageManager
                pm.setComponentEnabledSetting(
                    component,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
                pm.setComponentEnabledSetting(
                    component,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    requestRebind(component)
                }
                Log.d(TAG, "Full component toggle rebind requested successfully.")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to triggerRebind: ${e.message}")
            }
        }

        fun processActiveNotifications(): Int {
            val service = instance ?: return 0
            val activeNotifs = try {
                service.activeNotifications
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get active notifications: ${e.message}")
                null
            } ?: return 0

            Log.i(TAG, "Scanning ${activeNotifs.size} active notifications in status bar...")
            var count = 0
            for (sbn in activeNotifs) {
                service.onNotificationPosted(sbn)
                count++
            }
            return count
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.i(TAG, "NotificationService onCreate called.")
        startForegroundNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundNotification()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.i(TAG, "onTaskRemoved: Task swiped from recents. Keeping service alive...")
        startForegroundNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                requestRebind(ComponentName(applicationContext, NotificationService::class.java))
            }
        } catch (e: Exception) {
            Log.e(TAG, "onTaskRemoved requestRebind failed: ${e.message}")
        }
        triggerRebind(applicationContext)

        // Safety resurrection via AlarmManager
        try {
            val restartIntent = Intent(applicationContext, NotificationService::class.java).apply {
                setPackage(packageName)
            }
            val pi = PendingIntent.getService(
                applicationContext,
                FOREGROUND_NOTIFICATION_ID,
                restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val am = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            am?.set(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + 1000L,
                pi
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule resurrection alarm: ${e.message}")
        }
    }

    private fun startForegroundNotification() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    FOREGROUND_CHANNEL_ID,
                    "Layanan Gateway Notifikasi",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Menjaga gateway tetap aktif memantau notifikasi di latar belakang"
                    setShowBadge(false)
                }
                nm.createNotificationChannel(channel)
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            val pendingIntent = if (launchIntent != null) {
                PendingIntent.getActivity(
                    this,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            } else null

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, FOREGROUND_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }

            builder.setContentTitle("NotifyMe aktif memantau webhook")
                .setContentText("Memantau notifikasi & meneruskan ke webhook")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)
                .setAutoCancel(false)

            if (pendingIntent != null) {
                builder.setContentIntent(pendingIntent)
            }

            val notif = builder.build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    FOREGROUND_NOTIFICATION_ID,
                    notif,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    FOREGROUND_NOTIFICATION_ID,
                    notif,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(FOREGROUND_NOTIFICATION_ID, notif)
            }
            Log.i(TAG, "startForeground initialized successfully (ongoing foreground service).")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to startForeground: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) instance = null
        isServiceRunning = false
        Log.w(TAG, "NotificationService onDestroy called. Requesting rebind...")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                requestRebind(ComponentName(applicationContext, NotificationService::class.java))
            }
        } catch (e: Exception) {
            Log.e(TAG, "onDestroy requestRebind failed: ${e.message}")
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        isServiceRunning = true
        Log.i(TAG, "NotificationListenerService connected successfully.")
        startForegroundNotification()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isServiceRunning = false
        Log.w(TAG, "NotificationListenerService disconnected. Attempting auto-rebind...")
        triggerRebind(this)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        // Ignore notifications from ourselves to prevent infinite recursive trigger loops
        if (packageName == applicationContext.packageName) return

        val notification = sbn.notification ?: return
        val isGroupSummary = (notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0
        val extras = notification.extras ?: return

        // 1. Extract Title & Conversation Title
        val conversationTitle = (extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?: extras.getCharSequence("android.conversationTitle"))?.toString()
            ?.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "")?.trim() ?: ""

        var title = (extras.getCharSequence(Notification.EXTRA_TITLE)
            ?: extras.getCharSequence("android.title"))?.toString()
            ?.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "")?.trim() ?: ""

        if (title.isBlank() && conversationTitle.isNotBlank()) {
            title = conversationTitle
        }

        // 2. Extract Text & Variants
        var text = (extras.getCharSequence(Notification.EXTRA_TEXT)
            ?: extras.getCharSequence("android.text"))?.toString()
            ?.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "")?.trim() ?: ""

        val bigText = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence("android.bigText"))?.toString()
            ?.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "")?.trim() ?: ""

        val subText = (extras.getCharSequence(Notification.EXTRA_SUB_TEXT)
            ?: extras.getCharSequence("android.subText"))?.toString()
            ?.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "")?.trim() ?: ""

        val summaryText = (extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)
            ?: extras.getCharSequence("android.summaryText"))?.toString()
            ?.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "")?.trim() ?: ""

        // 3. Extract Text Lines (EXTRA_TEXT_LINES - used when multiple messages arrive in WhatsApp / Telegram)
        val textLinesRaw = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?: extras.getCharSequenceArrayList("android.textLines")?.toTypedArray()
        val linesList = mutableListOf<String>()
        if (textLinesRaw != null) {
            for (line in textLinesRaw) {
                val cleaned = line?.toString()?.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "")?.trim() ?: ""
                if (cleaned.isNotBlank()) linesList.add(cleaned)
            }
        }
        val linesContent = linesList.joinToString("\n")

        // 4. Extract MessagingStyle EXTRA_MESSAGES and EXTRA_HISTORIC_MESSAGES
        val messagesList = mutableListOf<Map<String, Any>>()
        val messagingSb = StringBuilder()

        fun extractMessagesFromAny(raw: Any?) {
            if (raw == null) return
            val bundles: List<Bundle> = when (raw) {
                is Array<*> -> raw.filterIsInstance<Bundle>()
                is Collection<*> -> raw.filterIsInstance<Bundle>()
                else -> emptyList()
            }
            for (msg in bundles) {
                var sender = msg.getCharSequence("sender")?.toString() ?: ""
                if (sender.isBlank() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    try {
                        val person = msg.getParcelable<android.app.Person>("sender_person")
                        if (person != null) {
                            sender = person.name?.toString() ?: ""
                        }
                    } catch (_: Exception) {}
                }
                val body = msg.getCharSequence("text")?.toString() ?: ""
                val msgTime = msg.getLong("time", 0L)

                val cleanSender = sender.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "").trim()
                val cleanBody = body.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "").trim()

                if (cleanBody.isNotBlank()) {
                    val map = mutableMapOf<String, Any>(
                        "sender" to cleanSender,
                        "text" to cleanBody,
                        "timestamp" to msgTime
                    )
                    messagesList.add(map)

                    if (cleanSender.isNotBlank()) messagingSb.append("$cleanSender: ")
                    messagingSb.append(cleanBody).append("\n")
                }
            }
        }

        extractMessagesFromAny(extras.get(Notification.EXTRA_HISTORIC_MESSAGES))
        extractMessagesFromAny(extras.get(Notification.EXTRA_MESSAGES))
        val messagingContent = messagingSb.toString().trim()

        val ticker = notification.tickerText?.toString()?.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "")?.trim() ?: ""

        // Resolve latest message
        val latestMessage = when {
            messagesList.isNotEmpty() -> messagesList.last()["text"] as? String ?: ""
            linesList.isNotEmpty() -> linesList.last()
            bigText.isNotBlank() -> bigText
            else -> text
        }

        // If primary text is blank, resolve from fallbacks
        if (text.isBlank()) {
            text = when {
                latestMessage.isNotBlank() -> latestMessage
                bigText.isNotBlank() -> bigText
                messagingContent.isNotBlank() -> messagingContent
                linesContent.isNotBlank() -> linesContent
                ticker.isNotBlank() -> ticker
                summaryText.isNotBlank() -> summaryText
                else -> ""
            }
        }

        // Full content for Regex searching
        val fullContent = buildString {
            if (title.isNotBlank()) append(title).append(" ")
            if (conversationTitle.isNotBlank() && conversationTitle != title) append(conversationTitle).append(" ")
            if (text.isNotBlank()) append(text).append(" ")
            if (latestMessage.isNotBlank() && latestMessage != text) append(latestMessage).append(" ")
            if (bigText.isNotBlank() && bigText != text && bigText != latestMessage) append(bigText).append(" ")
            if (linesContent.isNotBlank() && linesContent != text) append(linesContent).append(" ")
            if (messagingContent.isNotBlank() && messagingContent != linesContent && messagingContent != text) append(messagingContent).append(" ")
            if (subText.isNotBlank()) append(subText).append(" ")
            if (summaryText.isNotBlank()) append(summaryText)
        }.trim()

        // SQLite deduplication check: has this notification already been processed and dispatched?
        val latestMsgTime = if (messagesList.isNotEmpty()) {
            messagesList.last()["timestamp"] as? Long ?: 0L
        } else 0L

        val notifKey = if (latestMsgTime > 0) {
            "${packageName}_${title}_${text}_${latestMsgTime}"
        } else {
            "${sbn.key ?: (packageName + "_" + sbn.id)}_${sbn.postTime}"
        }

        // 0. Check Package Blacklist / Exclude Engine
        val blacklistedPattern = AppDatabase.getInstance(applicationContext).checkBlacklisted(
            packageName = packageName,
            title = title,
            text = text,
            fullContent = fullContent
        )
        if (blacklistedPattern != null) {
            Log.i(TAG, "Notification from $packageName matches blacklist pattern '$blacklistedPattern'. Skipping...")
            val blLog = NotificationLogStore.createLogEntry(
                packageName = packageName,
                title = title,
                text = text.ifBlank { fullContent },
                matched = false,
                matchedRuleName = "-",
                webhookUrl = "-",
                httpStatus = 0,
                responseBody = "",
                errorMessage = "Dilewati: Notifikasi cocok dengan Blacklist $packageName (\"$blacklistedPattern\")",
                latencyMs = 0,
                payloadSent = ""
            )
            NotificationLogStore.addLog(
                context = applicationContext,
                logItem = blLog,
                notificationKey = notifKey,
                status = "SKIPPED",
                isGroupSummary = isGroupSummary
            )
            return
        }

        if (AppDatabase.getInstance(applicationContext).isNotificationProcessed(notifKey)) {
            Log.d(TAG, "Notification already processed and sent to webhook in SQLite ($notifKey)")
            val dedupLog = NotificationLogStore.createLogEntry(
                packageName = packageName,
                title = title,
                text = text.ifBlank { fullContent },
                matched = true,
                matchedRuleName = "-",
                webhookUrl = "-",
                httpStatus = 0,
                responseBody = "",
                errorMessage = "Dilewati: Pesan ini sudah pernah berhasil dikirim ke webhook sebelumnya (Duplikat)",
                latencyMs = 0,
                payloadSent = ""
            )
            NotificationLogStore.addLog(
                context = applicationContext,
                logItem = dedupLog,
                notificationKey = notifKey,
                status = "SKIPPED",
                isGroupSummary = isGroupSummary
            )
            return
        }

        // Get readable app label (e.g. "Telegram", "WhatsApp", "Messages")
        val appName = getAppLabel(packageName)
        val timestamp = sbn.postTime

        Log.i(TAG, "Notification received from $appName ($packageName): Title='$title', Text='$text', Summary=$isGroupSummary")

        val rules = RuleStore.getRules(applicationContext)
        var anyRuleMatched = false

        for (rule in rules) {
            if (!rule.enabled) continue

            // 1. Package Name / App Name Filter Check
            if (!isPackageOrAppMatch(rule.packageName, packageName, appName)) {
                continue
            }

            // 2. Group Summary Check (User configurable per rule)
            if (isGroupSummary && rule.ignoreGroupSummary) {
                Log.d(TAG, "Rule '${rule.name}' ignores group summary notification from $packageName")
                anyRuleMatched = true
                val summaryLog = NotificationLogStore.createLogEntry(
                    packageName = packageName,
                    title = title,
                    text = text.ifBlank { fullContent },
                    matched = true,
                    matchedRuleName = rule.name,
                    webhookUrl = rule.webhookUrl,
                    httpStatus = 0,
                    responseBody = "",
                    errorMessage = "Dilewati: Ringkasan Notifikasi Grup (Group Summary) diabaikan oleh setelan aturan",
                    latencyMs = 0,
                    payloadSent = ""
                )
                NotificationLogStore.addLog(
                    context = applicationContext,
                    logItem = summaryLog,
                    notificationKey = notifKey,
                    status = "SKIPPED",
                    isGroupSummary = true
                )
                continue
            }

            // 3. Deduplication Check (User configurable per rule)
            if (rule.deduplicateMessages) {
                val isRecentDispatched = AppDatabase.getInstance(applicationContext).isRecentMessageProcessed(packageName, title, text, 1800000L)
                val dedupKey = if (latestMsgTime > 0) {
                    "${rule.id}|$packageName|$title|$text|$latestMsgTime"
                } else {
                    "${rule.id}|$packageName|$title|$text"
                }
                if (isRecentDispatched || isDuplicate(dedupKey)) {
                    Log.d(TAG, "Rule '${rule.name}' ignores duplicate notification update ($dedupKey)")
                    anyRuleMatched = true
                    val skipLog = NotificationLogStore.createLogEntry(
                        packageName = packageName,
                        title = title,
                        text = text.ifBlank { fullContent },
                        matched = true,
                        matchedRuleName = rule.name,
                        webhookUrl = rule.webhookUrl,
                        httpStatus = 0,
                        responseBody = "",
                        errorMessage = "Dilewati: Pesan ini sudah pernah berhasil dikirim dalam 30 menit terakhir (Duplikat)",
                        latencyMs = 0,
                        payloadSent = ""
                    )
                    NotificationLogStore.addLog(
                        context = applicationContext,
                        logItem = skipLog,
                        notificationKey = notifKey,
                        status = "SKIPPED",
                        isGroupSummary = isGroupSummary
                    )
                    continue
                }
            }

            // 4. Regex Filter Check
            val regex = rule.regexPattern.trim()
            if (regex.isNotBlank()) {
                val flags = if (rule.regexIgnoreCase) Pattern.CASE_INSENSITIVE or Pattern.MULTILINE else Pattern.MULTILINE
                try {
                    val pattern = Pattern.compile(regex, flags)
                    val matcher = pattern.matcher(fullContent)

                    if (matcher.find()) {
                        anyRuleMatched = true
                        val groups = mutableListOf<String>()
                        for (i in 1..matcher.groupCount()) {
                            groups.add(matcher.group(i) ?: "")
                        }

                        Log.i(TAG, "Rule matched: '${rule.name}' for pkg=$packageName. Groups=$groups")

                        WebhookDispatcher.dispatch(
                            context = applicationContext,
                            rule = rule,
                            packageName = packageName,
                            appName = appName,
                            title = title,
                            text = text,
                            bigText = bigText,
                            subText = subText,
                            fullContent = fullContent,
                            timestamp = timestamp,
                            regexMatches = groups,
                            isGroupSummary = isGroupSummary,
                            notificationKey = notifKey,
                            lines = linesList,
                            messages = messagesList,
                            conversationTitle = conversationTitle,
                            latestMessage = latestMessage
                        )
                    } else {
                        // Regex did not match
                        if (!rule.sendOnlyIfMatched) {
                            anyRuleMatched = true
                            WebhookDispatcher.dispatch(
                                context = applicationContext,
                                rule = rule,
                                packageName = packageName,
                                appName = appName,
                                title = title,
                                text = text,
                                bigText = bigText,
                                subText = subText,
                                fullContent = fullContent,
                                timestamp = timestamp,
                                regexMatches = emptyList(),
                                isGroupSummary = isGroupSummary,
                                notificationKey = notifKey,
                                lines = linesList,
                                messages = messagesList,
                                conversationTitle = conversationTitle,
                                latestMessage = latestMessage
                            )
                        } else {
                            anyRuleMatched = true
                            val regexSkipLog = NotificationLogStore.createLogEntry(
                                packageName = packageName,
                                title = title,
                                text = text.ifBlank { fullContent },
                                matched = false,
                                matchedRuleName = rule.name,
                                webhookUrl = rule.webhookUrl,
                                httpStatus = 0,
                                responseBody = "",
                                errorMessage = "Dilewati: Isi notifikasi tidak cocok dengan filter regex aturan '${rule.name}'",
                                latencyMs = 0,
                                payloadSent = ""
                            )
                            NotificationLogStore.addLog(
                                context = applicationContext,
                                logItem = regexSkipLog,
                                notificationKey = notifKey,
                                status = "SKIPPED",
                                isGroupSummary = isGroupSummary
                            )
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Regex compile error in rule '${rule.name}': ${e.message}")
                }
            } else {
                // No regex specified -> Match ALL notifications from this app/package
                anyRuleMatched = true
                Log.i(TAG, "Rule matched (No Regex): '${rule.name}' for pkg=$packageName")
                WebhookDispatcher.dispatch(
                    context = applicationContext,
                    rule = rule,
                    packageName = packageName,
                    appName = appName,
                    title = title,
                    text = text,
                    bigText = bigText,
                    subText = subText,
                    fullContent = fullContent,
                    timestamp = timestamp,
                    regexMatches = emptyList(),
                    isGroupSummary = isGroupSummary,
                    notificationKey = notifKey,
                    lines = linesList,
                    messages = messagesList,
                    conversationTitle = conversationTitle,
                    latestMessage = latestMessage
                )
            }
        }

        // Record log if no rule matched so user can see it in "Log Webhook"
        if (!anyRuleMatched) {
            val unhandledLog = NotificationLogStore.createLogEntry(
                packageName = packageName,
                title = title,
                text = text.ifBlank { fullContent },
                matched = false,
                matchedRuleName = "-",
                webhookUrl = "-",
                httpStatus = 0,
                responseBody = "",
                errorMessage = "Dilewati: Notifikasi diterima tetapi tidak ada aturan filter yang cocok",
                latencyMs = 0,
                payloadSent = ""
            )
            NotificationLogStore.addLog(
                context = applicationContext,
                logItem = unhandledLog,
                notificationKey = notifKey,
                status = "SKIPPED",
                isGroupSummary = isGroupSummary
            )
            WebhookDispatcher.onLogUpdated?.invoke()
        }
    }

    private fun isPackageOrAppMatch(rulePkg: String, incomingPkg: String, appLabel: String): Boolean {
        val target = rulePkg.trim()
        if (target.isBlank() || target == "*") return true

        val targets = target.split(",", ";").map { it.trim().lowercase() }.filter { it.isNotEmpty() }
        val incomingPkgLower = incomingPkg.lowercase()
        val appLabelLower = appLabel.lowercase()

        return targets.any { item ->
            // Match exact package or partial package (e.g. "telegram" matches "org.telegram.messenger")
            incomingPkgLower == item ||
            incomingPkgLower.contains(item) ||
            // Match app display name (e.g. "telegram" matches "Telegram")
            appLabelLower == item ||
            appLabelLower.contains(item)
        }
    }

    private fun getAppLabel(packageName: String): String {
        return try {
            val pm = applicationContext.packageManager
            val info = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            packageName
        }
    }
}
