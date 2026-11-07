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
import java.util.concurrent.ConcurrentHashMap
import java.util.regex.Pattern

class NotificationService : NotificationListenerService() {

    companion object {
        private const val TAG = "NotifWebhookService"

        @Volatile
        var isServiceRunning = false

        @Volatile
        var instance: NotificationService? = null

        // In-memory fast deduplication cache: key -> timestamp (ms)
        private val recentNotifications = ConcurrentHashMap<String, Long>()
        private const val DEDUP_WINDOW_MS = 3000L

        // Per-rule cooldown tracker: ruleId -> lastDispatchedTimestamp (ms)
        private val ruleCooldownTracker = ConcurrentHashMap<String, Long>()

        private const val FOREGROUND_CHANNEL_ID = "notifymee_gateway_channel"
        private const val FOREGROUND_NOTIFICATION_ID = 9001

        private fun isDuplicateInMemory(key: String, customWindowMs: Long = DEDUP_WINDOW_MS): Boolean {
            val now = System.currentTimeMillis()
            if (recentNotifications.size > 250) {
                val iterator = recentNotifications.entries.iterator()
                while (iterator.hasNext()) {
                    val entry = iterator.next()
                    if (now - entry.value > 60_000L) {
                        iterator.remove()
                    }
                }
            }

            val prevTime = recentNotifications.put(key, now)
            return prevTime != null && (now - prevTime) < customWindowMs
        }

        private fun isRuleInCooldown(ruleId: String, cooldownSeconds: Int): Boolean {
            if (cooldownSeconds <= 0) return false
            val now = System.currentTimeMillis()
            val cooldownMs = cooldownSeconds * 1000L
            val lastTime = ruleCooldownTracker[ruleId]
            if (lastTime != null && (now - lastTime) < cooldownMs) {
                return true
            }
            ruleCooldownTracker[ruleId] = now
            return false
        }

        fun startForegroundService(context: Context) {
            try {
                val appContext = context.applicationContext
                val serviceIntent = Intent(appContext, NotificationService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    appContext.startForegroundService(serviceIntent)
                } else {
                    appContext.startService(serviceIntent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to startForegroundService: ${e.message}")
            }
        }

        /**
         * Requests system rebind safely WITHOUT disabling the component if the service is alive.
         * Use this inside lifecycle callbacks (onTaskRemoved, onDestroy, BootReceiver).
         */
        fun requestSafeRebind(context: Context) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val component = ComponentName(context.applicationContext, NotificationService::class.java)
                    requestRebind(component)
                    Log.d(TAG, "requestSafeRebind requested successfully.")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed requestSafeRebind: ${e.message}")
            }
        }

        /**
         * Forces component state toggle ONLY when user explicitly triggers rebind or when listener is disconnected.
         */
        fun triggerRebind(context: Context, forceComponentToggle: Boolean = false) {
            try {
                val appContext = context.applicationContext
                val component = ComponentName(appContext, NotificationService::class.java)
                if (forceComponentToggle || !isServiceRunning) {
                    val pm = appContext.packageManager
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
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    requestRebind(component)
                }
                Log.d(TAG, "triggerRebind executed (forceToggle=$forceComponentToggle).")
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
                if (sbn.packageName == service.packageName) continue
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
        instance = this
        startForegroundNotification()
        if (!isServiceRunning) {
            requestSafeRebind(applicationContext)
        }
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.i(TAG, "onTaskRemoved: Task swiped from Recents. Keeping foreground gateway alive...")
        // 1. Re-assert foreground notification immediately
        startForegroundNotification()
        // 2. Request safe rebind WITHOUT disabling component (disabling kills the active binder!)
        requestSafeRebind(applicationContext)
        // 3. Schedule Doze-aware resurrection alarm in case OEM ROM kills the process post-swipe
        scheduleResurrectionAlarm(1500L)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) instance = null
        isServiceRunning = false
        Log.w(TAG, "NotificationService onDestroy called. Requesting safe rebind & resurrection...")
        requestSafeRebind(applicationContext)
        scheduleResurrectionAlarm(2000L)
    }

    private fun scheduleResurrectionAlarm(delayMs: Long) {
        try {
            val restartIntent = Intent(applicationContext, NotificationService::class.java).apply {
                setPackage(packageName)
            }
            val pendingFlags = PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            val pi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PendingIntent.getForegroundService(
                    applicationContext,
                    FOREGROUND_NOTIFICATION_ID,
                    restartIntent,
                    pendingFlags
                )
            } else {
                PendingIntent.getService(
                    applicationContext,
                    FOREGROUND_NOTIFICATION_ID,
                    restartIntent,
                    pendingFlags
                )
            }
            val am = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            val triggerAt = SystemClock.elapsedRealtime() + delayMs
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am?.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
            } else {
                am?.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
            }
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
                    description = "Menjaga gateway tetap aktif memantau notifikasi 24/7 di latar belakang"
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
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

            builder.setContentTitle("Notifymee aktif memantau webhook")
                .setContentText("Memantau notifikasi & meneruskan ke webhook 24/7")
                .setSmallIcon(R.drawable.ic_stat_notifyme)
                .setColor(0xFF00796B.toInt())
                .setLargeIcon(android.graphics.BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher))
                .setCategory(Notification.CATEGORY_SERVICE)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setAutoCancel(false)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            }

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
        } catch (e: Exception) {
            Log.e(TAG, "Failed to startForeground: ${e.message}")
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
        Log.w(TAG, "NotificationListenerService disconnected. Requesting safe rebind...")
        requestSafeRebind(applicationContext)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val incomingPkg = sbn.packageName ?: return

        // 1. Prevent infinite loop: strictly ignore notifications from NotifyMe itself or system UI summaries
        if (incomingPkg == applicationContext.packageName || incomingPkg == "android") return

        val notification = sbn.notification ?: return
        val flags = notification.flags
        val isGroupSummary = (flags and Notification.FLAG_GROUP_SUMMARY) != 0
        val isOngoing = sbn.isOngoing ||
            (flags and Notification.FLAG_ONGOING_EVENT) != 0 ||
            (flags and Notification.FLAG_FOREGROUND_SERVICE) != 0

        val extras = notification.extras ?: return

        // 2. Extract Title & Conversation Title
        val conversationTitle = (extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?: extras.getCharSequence("android.conversationTitle"))?.toString()
            ?.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "")?.trim() ?: ""

        var title = (extras.getCharSequence(Notification.EXTRA_TITLE)
            ?: extras.getCharSequence("android.title"))?.toString()
            ?.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "")?.trim() ?: ""

        if (title.isBlank() && conversationTitle.isNotBlank()) {
            title = conversationTitle
        }

        // 3. Extract Text & Variants
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

        // 4. Extract Text Lines (EXTRA_TEXT_LINES - WhatsApp / Telegram stacked messages)
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

        // 5. Extract MessagingStyle EXTRA_MESSAGES and EXTRA_HISTORIC_MESSAGES
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
                        @Suppress("DEPRECATION")
                        val person = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            msg.getParcelable("sender_person", android.app.Person::class.java)
                        } else {
                            msg.getParcelable("sender_person")
                        }
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
                    messagesList.add(
                        mapOf(
                            "sender" to cleanSender,
                            "text" to cleanBody,
                            "timestamp" to msgTime
                        )
                    )
                    if (cleanSender.isNotBlank()) messagingSb.append("$cleanSender: ")
                    messagingSb.append(cleanBody).append("\n")
                }
            }
        }

        extractMessagesFromAny(extras.get(Notification.EXTRA_HISTORIC_MESSAGES))
        extractMessagesFromAny(extras.get(Notification.EXTRA_MESSAGES))
        val messagingContent = messagingSb.toString().trim()

        val ticker = notification.tickerText?.toString()
            ?.replace("[\u200B-\u200F\u202A-\u202E]".toRegex(), "")?.trim() ?: ""

        val latestMessage = when {
            messagesList.isNotEmpty() -> messagesList.last()["text"] as? String ?: ""
            linesList.isNotEmpty() -> linesList.last()
            bigText.isNotBlank() -> bigText
            else -> text
        }

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

        // Ignore completely empty/placeholder notifications
        if (title.isBlank() && text.isBlank()) return

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

        val latestMsgTime = if (messagesList.isNotEmpty()) {
            messagesList.last()["timestamp"] as? Long ?: 0L
        } else 0L

        // Content-deterministic key (avoids postTime churn on notification updates)
        val notifKey = if (latestMsgTime > 0) {
            "${incomingPkg}_${title}_${latestMessage}_${latestMsgTime}"
        } else {
            "${incomingPkg}_${sbn.id}_${title}_${text.hashCode()}"
        }

        // Fast in-memory burst deduplication before touching SQLite
        if (isDuplicateInMemory("global|$incomingPkg|$title|$text|$isGroupSummary", 1500L)) {
            return
        }

        val db = AppDatabase.getInstance(applicationContext)

        // Check Package Blacklist / Exclude Engine
        val blacklistedPattern = db.checkBlacklisted(
            packageName = incomingPkg,
            title = title,
            text = text,
            fullContent = fullContent
        )
        if (blacklistedPattern != null) {
            Log.i(TAG, "Notification from $incomingPkg matches blacklist '$blacklistedPattern'. Skipping...")
            return
        }

        if (db.isNotificationProcessed(notifKey)) {
            Log.d(TAG, "Notification already processed in SQLite ($notifKey). Skipping.")
            return
        }

        val appName = getAppLabel(incomingPkg)
        val timestamp = sbn.postTime
        val rules = RuleStore.getRules(applicationContext)
        var anyRuleMatched = false

        for (rule in rules) {
            if (!rule.enabled) continue

            // 1. Package Name / App Name Filter Check
            if (!isPackageOrAppMatch(rule.packageName, incomingPkg, appName)) {
                continue
            }

            // 2. Ongoing Notification Filter (prevents music player / download progress bar spam)
            if (isOngoing && rule.ignoreOngoing) {
                anyRuleMatched = true
                continue
            }

            // 3. Group Summary Filter (prevents WhatsApp / Telegram duplicate group header triggers)
            if (isGroupSummary && rule.ignoreGroupSummary) {
                anyRuleMatched = true
                continue
            }

            // 4. Deduplication Check
            if (rule.deduplicateMessages) {
                val dedupKey = "${rule.id}|$incomingPkg|$title|$text"
                val isRecentDispatched = db.isRecentMessageProcessed(incomingPkg, title, text, 1_800_000L)
                if (isRecentDispatched || isDuplicateInMemory(dedupKey, DEDUP_WINDOW_MS)) {
                    Log.d(TAG, "Rule '${rule.name}' skipped duplicate message ($dedupKey)")
                    anyRuleMatched = true
                    continue
                }
            }

            // 5. Per-Rule Cooldown / Anti-Spam Check
            if (isRuleInCooldown(rule.id, rule.cooldownSeconds)) {
                Log.d(TAG, "Rule '${rule.name}' is in cooldown (${rule.cooldownSeconds}s). Skipping.")
                anyRuleMatched = true
                continue
            }

            // 6. Regex Filter & Named Group Extraction
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
                        val namedGroups = extractNamedGroups(regex, matcher)

                        WebhookDispatcher.dispatch(
                            context = applicationContext,
                            rule = rule,
                            packageName = incomingPkg,
                            appName = appName,
                            title = title,
                            text = text,
                            bigText = bigText,
                            subText = subText,
                            fullContent = fullContent,
                            timestamp = timestamp,
                            regexMatches = groups,
                            namedRegexMatches = namedGroups,
                            isGroupSummary = isGroupSummary,
                            notificationKey = notifKey,
                            lines = linesList,
                            messages = messagesList,
                            conversationTitle = conversationTitle,
                            latestMessage = latestMessage
                        )
                    } else if (!rule.sendOnlyIfMatched) {
                        anyRuleMatched = true
                        WebhookDispatcher.dispatch(
                            context = applicationContext,
                            rule = rule,
                            packageName = incomingPkg,
                            appName = appName,
                            title = title,
                            text = text,
                            bigText = bigText,
                            subText = subText,
                            fullContent = fullContent,
                            timestamp = timestamp,
                            regexMatches = emptyList(),
                            namedRegexMatches = emptyMap(),
                            isGroupSummary = isGroupSummary,
                            notificationKey = notifKey,
                            lines = linesList,
                            messages = messagesList,
                            conversationTitle = conversationTitle,
                            latestMessage = latestMessage
                        )
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Regex compile error in rule '${rule.name}': ${e.message}")
                }
            } else {
                anyRuleMatched = true
                WebhookDispatcher.dispatch(
                    context = applicationContext,
                    rule = rule,
                    packageName = incomingPkg,
                    appName = appName,
                    title = title,
                    text = text,
                    bigText = bigText,
                    subText = subText,
                    fullContent = fullContent,
                    timestamp = timestamp,
                    regexMatches = emptyList(),
                    namedRegexMatches = emptyMap(),
                    isGroupSummary = isGroupSummary,
                    notificationKey = notifKey,
                    lines = linesList,
                    messages = messagesList,
                    conversationTitle = conversationTitle,
                    latestMessage = latestMessage
                )
            }
        }

        // Only log non-summary, non-ongoing unhandled notifications to avoid polluting SQLite
        if (!anyRuleMatched && !isGroupSummary && !isOngoing) {
            val unhandledLog = NotificationLogStore.createLogEntry(
                packageName = incomingPkg,
                title = title,
                text = text.ifBlank { fullContent },
                matched = false,
                matchedRuleName = "-",
                webhookUrl = "-",
                httpStatus = 0,
                responseBody = "",
                errorMessage = "Dilewati: Tidak ada aturan filter yang cocok",
                latencyMs = 0,
                payloadSent = ""
            )
            NotificationLogStore.addLog(
                context = applicationContext,
                logItem = unhandledLog,
                notificationKey = notifKey,
                status = "SKIPPED",
                isGroupSummary = false
            )
            WebhookDispatcher.onLogUpdated?.invoke()
        }
    }

    private fun extractNamedGroups(regex: String, matcher: java.util.regex.Matcher): Map<String, String> {
        val result = mutableMapOf<String, String>()
        val nameMatcher = Pattern.compile("\\(\\?<([a-zA-Z][a-zA-Z0-9]*)>").matcher(regex)
        while (nameMatcher.find()) {
            val groupName = nameMatcher.group(1) ?: continue
            try {
                val value = matcher.group(groupName)
                if (value != null) {
                    result[groupName] = value
                }
            } catch (_: Exception) {}
        }
        return result
    }

    private fun isPackageOrAppMatch(rulePkg: String, incomingPkg: String, appLabel: String): Boolean {
        val target = rulePkg.trim()
        if (target.isBlank() || target == "*") return true

        val targets = target.split(",", ";").map { it.trim().lowercase() }.filter { it.isNotEmpty() }
        val incomingPkgLower = incomingPkg.lowercase()
        val appLabelLower = appLabel.lowercase()

        return targets.any { item ->
            incomingPkgLower == item ||
                incomingPkgLower.contains(item) ||
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
