package com.rizumiya.notifymee

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.math.min
import kotlin.random.Random

object WebhookDispatcher {
    private const val TAG = "WebhookDispatcher"
    private const val WAKELOCK_TAG = "NotifyMe:WebhookWakeLock"

    // Bounded thread pool that stays alive across service restarts and avoids thread exhaustion
    private val executor = ThreadPoolExecutor(
        2,
        8,
        60L,
        TimeUnit.SECONDS,
        LinkedBlockingQueue(256),
        ThreadPoolExecutor.DiscardOldestPolicy()
    )
    private val mainHandler = Handler(Looper.getMainLooper())

    var onLogUpdated: (() -> Unit)? = null

    fun dispatch(
        context: Context,
        rule: WebhookRule,
        packageName: String,
        appName: String = "",
        title: String,
        text: String,
        bigText: String = "",
        subText: String = "",
        fullContent: String = "",
        timestamp: Long,
        regexMatches: List<String>,
        namedRegexMatches: Map<String, String> = emptyMap(),
        isGroupSummary: Boolean = false,
        notificationKey: String = "",
        lines: List<String> = emptyList(),
        messages: List<Map<String, Any>> = emptyList(),
        conversationTitle: String = "",
        latestMessage: String = "",
        existingLogId: String? = null,
        onComplete: ((Boolean, Int, String) -> Unit)? = null
    ) {
        val appContext = context.applicationContext
        val wakeLock = acquirePartialWakeLock(appContext, 65_000L)

        executor.execute {
            try {
                val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", Locale.getDefault())
                val dateStr = isoFormat.format(Date(timestamp))

                val payloadString = if (rule.customPayload.isNotBlank()) {
                    interpolateTemplate(
                        template = rule.customPayload,
                        rule = rule,
                        packageName = packageName,
                        appName = appName,
                        title = title,
                        text = text,
                        bigText = bigText,
                        subText = subText,
                        fullContent = fullContent,
                        timestamp = timestamp,
                        dateStr = dateStr,
                        regexMatches = regexMatches,
                        namedRegexMatches = namedRegexMatches,
                        isGroupSummary = isGroupSummary,
                        lines = lines,
                        messages = messages,
                        conversationTitle = conversationTitle,
                        latestMessage = latestMessage
                    )
                } else {
                    buildUniversalJsonPayload(
                        rule = rule,
                        packageName = packageName,
                        appName = appName,
                        title = title,
                        text = text,
                        bigText = bigText,
                        subText = subText,
                        fullContent = fullContent,
                        timestamp = timestamp,
                        dateStr = dateStr,
                        regexMatches = regexMatches,
                        namedRegexMatches = namedRegexMatches,
                        isGroupSummary = isGroupSummary,
                        lines = lines,
                        messages = messages,
                        conversationTitle = conversationTitle,
                        latestMessage = latestMessage
                    )
                }

                val result = executeHttpWithBackoff(
                    webhookUrl = rule.webhookUrl,
                    httpMethod = rule.httpMethod,
                    headers = rule.headers,
                    secretKey = rule.secretKey,
                    payloadString = payloadString,
                    maxRetries = rule.maxRetries
                )

                val logEntry = NotificationLogStore.createLogEntry(
                    id = existingLogId ?: "${System.currentTimeMillis()}_${Random.nextInt(1000, 9999)}",
                    timestamp = timestamp,
                    packageName = packageName,
                    title = title,
                    text = text.ifBlank { fullContent },
                    matched = true,
                    matchedRuleName = rule.name,
                    webhookUrl = rule.webhookUrl,
                    httpStatus = result.httpStatus,
                    responseBody = result.responseBody,
                    errorMessage = result.errorMessage,
                    latencyMs = result.latencyMs,
                    payloadSent = payloadString
                )
                val logStatus = if (result.isSuccess) "SUCCESS" else "FAILED"
                NotificationLogStore.addLog(
                    context = appContext,
                    logItem = logEntry,
                    notificationKey = notificationKey,
                    status = logStatus,
                    isGroupSummary = isGroupSummary
                )

                mainHandler.post {
                    onLogUpdated?.invoke()
                    onComplete?.invoke(
                        result.isSuccess,
                        result.httpStatus,
                        if (result.isSuccess) result.responseBody else result.errorMessage
                    )
                }
            } finally {
                releaseWakeLockSafely(wakeLock)
            }
        }
    }

    /**
     * Retries an existing log entry natively (preserving rule headers, HTTP method, HMAC signature,
     * and updating SQLite log status in place).
     */
    fun retryLogById(
        context: Context,
        logId: String,
        onComplete: (Boolean, Int, String) -> Unit
    ) {
        val appContext = context.applicationContext
        val wakeLock = acquirePartialWakeLock(appContext, 45_000L)

        executor.execute {
            try {
                val db = AppDatabase.getInstance(appContext)
                val logJson = db.getLogById(logId)
                if (logJson == null) {
                    mainHandler.post {
                        onComplete(false, 0, "Data log tidak ditemukan di SQLite.")
                    }
                    return@execute
                }

                val webhookUrl = logJson.optString("webhookUrl", "")
                if (webhookUrl.isBlank() || webhookUrl == "-") {
                    mainHandler.post {
                        onComplete(false, 0, "Log ini tidak memiliki URL webhook tujuan.")
                    }
                    return@execute
                }

                val matchedRuleName = logJson.optString("matchedRuleName", "")
                val matchedRule = RuleStore.getRules(appContext).find {
                    it.name.equals(matchedRuleName, ignoreCase = true) || it.webhookUrl == webhookUrl
                }

                val payloadSent = logJson.optString("payloadSent", "").ifBlank {
                    JSONObject().apply {
                        put("event", "notification_retry")
                        put("package_name", logJson.optString("packageName"))
                        put("title", logJson.optString("title"))
                        put("text", logJson.optString("text"))
                        put("timestamp", logJson.optLong("timestamp", System.currentTimeMillis()))
                    }.toString(2)
                }

                val result = executeHttpWithBackoff(
                    webhookUrl = webhookUrl,
                    httpMethod = matchedRule?.httpMethod ?: "POST",
                    headers = matchedRule?.headers ?: mapOf("Content-Type" to "application/json"),
                    secretKey = matchedRule?.secretKey ?: "",
                    payloadString = payloadSent,
                    maxRetries = matchedRule?.maxRetries ?: 2
                )

                db.insertOrUpdateLog(
                    id = logId,
                    notificationKey = logJson.optString("notificationKey", ""),
                    timestamp = logJson.optLong("timestamp", System.currentTimeMillis()),
                    datetime = logJson.optString("datetime", ""),
                    packageName = logJson.optString("packageName", ""),
                    title = logJson.optString("title", ""),
                    text = logJson.optString("text", ""),
                    matched = true,
                    matchedRuleName = matchedRuleName.ifBlank { "-" },
                    webhookUrl = webhookUrl,
                    httpStatus = result.httpStatus,
                    responseBody = result.responseBody,
                    errorMessage = if (result.isSuccess) "" else result.errorMessage,
                    latencyMs = result.latencyMs,
                    payloadSent = payloadSent,
                    status = if (result.isSuccess) "SUCCESS" else "FAILED",
                    isGroupSummary = logJson.optBoolean("isGroupSummary", false)
                )

                mainHandler.post {
                    onLogUpdated?.invoke()
                    onComplete(
                        result.isSuccess,
                        result.httpStatus,
                        if (result.isSuccess) result.responseBody else result.errorMessage
                    )
                }
            } finally {
                releaseWakeLockSafely(wakeLock)
            }
        }
    }

    /**
     * Retries all failed logs in SQLite in batch and returns count of newly succeeded webhooks.
     */
    fun retryAllFailedLogs(
        context: Context,
        onComplete: (Int, Int) -> Unit
    ) {
        val appContext = context.applicationContext
        val wakeLock = acquirePartialWakeLock(appContext, 90_000L)

        executor.execute {
            try {
                val db = AppDatabase.getInstance(appContext)
                val failedLogs = db.getFailedLogs(30)
                if (failedLogs.isEmpty()) {
                    mainHandler.post { onComplete(0, 0) }
                    return@execute
                }

                var successCount = 0
                val rules = RuleStore.getRules(appContext)

                for (logJson in failedLogs) {
                    val logId = logJson.optString("id")
                    val webhookUrl = logJson.optString("webhookUrl", "")
                    if (logId.isBlank() || webhookUrl.isBlank() || webhookUrl == "-") continue

                    val matchedRuleName = logJson.optString("matchedRuleName", "")
                    val matchedRule = rules.find {
                        it.name.equals(matchedRuleName, ignoreCase = true) || it.webhookUrl == webhookUrl
                    }

                    val payloadSent = logJson.optString("payloadSent", "")
                    val result = executeHttpWithBackoff(
                        webhookUrl = webhookUrl,
                        httpMethod = matchedRule?.httpMethod ?: "POST",
                        headers = matchedRule?.headers ?: mapOf("Content-Type" to "application/json"),
                        secretKey = matchedRule?.secretKey ?: "",
                        payloadString = payloadSent,
                        maxRetries = 1
                    )

                    if (result.isSuccess) successCount++

                    db.insertOrUpdateLog(
                        id = logId,
                        notificationKey = logJson.optString("notificationKey", ""),
                        timestamp = logJson.optLong("timestamp", System.currentTimeMillis()),
                        datetime = logJson.optString("datetime", ""),
                        packageName = logJson.optString("packageName", ""),
                        title = logJson.optString("title", ""),
                        text = logJson.optString("text", ""),
                        matched = true,
                        matchedRuleName = matchedRuleName,
                        webhookUrl = webhookUrl,
                        httpStatus = result.httpStatus,
                        responseBody = result.responseBody,
                        errorMessage = if (result.isSuccess) "" else result.errorMessage,
                        latencyMs = result.latencyMs,
                        payloadSent = payloadSent,
                        status = if (result.isSuccess) "SUCCESS" else "FAILED",
                        isGroupSummary = logJson.optBoolean("isGroupSummary", false)
                    )
                }

                val totalTried = failedLogs.size
                mainHandler.post {
                    onLogUpdated?.invoke()
                    onComplete(successCount, totalTried)
                }
            } finally {
                releaseWakeLockSafely(wakeLock)
            }
        }
    }

    private data class HttpDispatchResult(
        val isSuccess: Boolean,
        val httpStatus: Int,
        val responseBody: String,
        val errorMessage: String,
        val latencyMs: Long
    )

    private fun executeHttpWithBackoff(
        webhookUrl: String,
        httpMethod: String,
        headers: Map<String, String>,
        secretKey: String,
        payloadString: String,
        maxRetries: Int
    ): HttpDispatchResult {
        val maxAttempts = maxRetries.coerceIn(1, 6)
        var attempt = 0
        var isSuccess = false
        var httpStatus = 0
        var responseBody = ""
        var errorMessage = ""
        val startTime = System.currentTimeMillis()

        while (attempt < maxAttempts && !isSuccess) {
            attempt++
            var conn: HttpURLConnection? = null
            try {
                val url = URL(webhookUrl)
                conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = httpMethod.uppercase(Locale.US)
                    connectTimeout = 15_000
                    readTimeout = 15_000
                    instanceFollowRedirects = true
                    useCaches = false
                }

                var hasContentType = false
                for ((key, value) in headers) {
                    conn.setRequestProperty(key, value)
                    if (key.equals("Content-Type", ignoreCase = true)) {
                        hasContentType = true
                    }
                }
                conn.setRequestProperty("X-Webhook-Attempt", attempt.toString())

                if (secretKey.isNotBlank()) {
                    val signature = calculateHmacSha256(payloadString, secretKey)
                    conn.setRequestProperty("X-Webhook-Signature", "sha256=$signature")
                }

                if (httpMethod.equals("POST", ignoreCase = true) ||
                    httpMethod.equals("PUT", ignoreCase = true) ||
                    httpMethod.equals("PATCH", ignoreCase = true)
                ) {
                    conn.doOutput = true
                    if (!hasContentType) {
                        conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                    }
                    val outputBytes = payloadString.toByteArray(Charsets.UTF_8)
                    conn.outputStream.use { os ->
                        os.write(outputBytes)
                        os.flush()
                    }
                }

                httpStatus = conn.responseCode
                val stream = if (httpStatus in 200..299) {
                    conn.inputStream
                } else {
                    conn.errorStream ?: conn.inputStream
                }

                if (stream != null) {
                    BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { reader ->
                        val sb = StringBuilder()
                        var line: String?
                        while (reader.readLine().also { line = it } != null) {
                            if (sb.length < 2000) {
                                sb.append(line).append("\n")
                            }
                        }
                        responseBody = sb.toString().trim()
                    }
                }

                if (httpStatus in 200..299) {
                    isSuccess = true
                    errorMessage = ""
                } else {
                    errorMessage = "Server merespons HTTP $httpStatus"
                    val shouldRetryStatus = httpStatus == 408 || httpStatus == 429 || httpStatus in 500..599
                    if (!shouldRetryStatus) {
                        // Do not waste battery retrying permanent 4xx client errors (400, 401, 403, 404)
                        break
                    }
                    if (attempt < maxAttempts) {
                        sleepExponentialBackoff(attempt)
                    }
                }
            } catch (e: Exception) {
                errorMessage = e.message ?: e.javaClass.simpleName
                if (attempt < maxAttempts) {
                    sleepExponentialBackoff(attempt)
                }
            } finally {
                try {
                    conn?.disconnect()
                } catch (_: Exception) {}
            }
        }

        val latencyMs = System.currentTimeMillis() - startTime
        if (!isSuccess && attempt > 1) {
            errorMessage = "$errorMessage ($attempt percobaan gagal)"
        }
        return HttpDispatchResult(isSuccess, httpStatus, responseBody, errorMessage, latencyMs)
    }

    private fun sleepExponentialBackoff(attempt: Int) {
        try {
            // True exponential backoff: 1.5s, 3s, 6s, 12s, capped at 25s + random jitter
            val baseDelay = min(25_000L, 1500L * (1L shl (attempt - 1).coerceAtMost(4)))
            val jitter = Random.nextLong(100L, 600L)
            Thread.sleep(baseDelay + jitter)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
    }

    private fun acquirePartialWakeLock(context: Context, timeoutMs: Long): PowerManager.WakeLock? {
        return try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return null
            pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKELOCK_TAG).apply {
                setReferenceCounted(false)
                acquire(timeoutMs)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to acquire WakeLock: ${e.message}")
            null
        }
    }

    private fun releaseWakeLockSafely(wakeLock: PowerManager.WakeLock?) {
        try {
            if (wakeLock != null && wakeLock.isHeld) {
                wakeLock.release()
            }
        } catch (_: Exception) {}
    }

    private fun buildUniversalJsonPayload(
        rule: WebhookRule,
        packageName: String,
        appName: String,
        title: String,
        text: String,
        bigText: String,
        subText: String,
        fullContent: String,
        timestamp: Long,
        dateStr: String,
        regexMatches: List<String>,
        namedRegexMatches: Map<String, String> = emptyMap(),
        isGroupSummary: Boolean = false,
        lines: List<String> = emptyList(),
        messages: List<Map<String, Any>> = emptyList(),
        conversationTitle: String = "",
        latestMessage: String = ""
    ): String {
        val root = JSONObject()
        root.put("event", "notification_received")
        root.put("timestamp", timestamp)
        root.put("datetime", dateStr)

        val appObj = JSONObject()
        appObj.put("package_name", packageName)
        appObj.put("app_name", appName.ifBlank { packageName })
        root.put("app", appObj)

        val notifObj = JSONObject()
        notifObj.put("title", title)
        notifObj.put("text", text)
        if (latestMessage.isNotBlank()) {
            notifObj.put("latest_message", latestMessage)
        }
        if (conversationTitle.isNotBlank()) {
            notifObj.put("conversation_title", conversationTitle)
        }
        notifObj.put("big_text", bigText)
        notifObj.put("sub_text", subText)

        val linesArray = JSONArray()
        for (l in lines) {
            linesArray.put(l)
        }
        notifObj.put("lines", linesArray)

        val messagesArray = JSONArray()
        for (m in messages) {
            val mObj = JSONObject()
            mObj.put("sender", m["sender"] ?: "")
            mObj.put("text", m["text"] ?: "")
            mObj.put("timestamp", m["timestamp"] ?: 0L)
            messagesArray.put(mObj)
        }
        notifObj.put("messages", messagesArray)

        notifObj.put("full_content", fullContent)
        notifObj.put("is_group_summary", isGroupSummary)
        root.put("notification", notifObj)

        val ruleObj = JSONObject()
        ruleObj.put("id", rule.id)
        ruleObj.put("name", rule.name)
        root.put("rule", ruleObj)

        val matchesObj = JSONObject()
        matchesObj.put("has_regex", rule.regexPattern.isNotBlank())
        matchesObj.put("regex_pattern", rule.regexPattern)

        val groupsArray = JSONArray()
        for (i in regexMatches.indices) {
            groupsArray.put(regexMatches[i])
            matchesObj.put("group${i + 1}", regexMatches[i])
        }
        matchesObj.put("groups", groupsArray)

        if (namedRegexMatches.isNotEmpty()) {
            val namedObj = JSONObject()
            for ((k, v) in namedRegexMatches) {
                namedObj.put(k, v)
                matchesObj.put(k, v)
            }
            matchesObj.put("named_groups", namedObj)
        }

        root.put("matches", matchesObj)
        return root.toString(2)
    }

    private fun interpolateTemplate(
        template: String,
        rule: WebhookRule,
        packageName: String,
        appName: String,
        title: String,
        text: String,
        bigText: String,
        subText: String,
        fullContent: String,
        timestamp: Long,
        dateStr: String,
        regexMatches: List<String>,
        namedRegexMatches: Map<String, String> = emptyMap(),
        isGroupSummary: Boolean = false,
        lines: List<String> = emptyList(),
        messages: List<Map<String, Any>> = emptyList(),
        conversationTitle: String = "",
        latestMessage: String = ""
    ): String {
        var result = template
            .replace("{{rule_id}}", escapeJsonString(rule.id))
            .replace("{{rule_name}}", escapeJsonString(rule.name))
            .replace("{{package_name}}", escapeJsonString(packageName))
            .replace("{{app_name}}", escapeJsonString(appName.ifBlank { packageName }))
            .replace("{{title}}", escapeJsonString(title))
            .replace("{{text}}", escapeJsonString(text))
            .replace("{{latest_message}}", escapeJsonString(latestMessage))
            .replace("{{conversation_title}}", escapeJsonString(conversationTitle))
            .replace("{{big_text}}", escapeJsonString(bigText))
            .replace("{{sub_text}}", escapeJsonString(subText))
            .replace("{{full_content}}", escapeJsonString(fullContent))
            .replace("{{lines}}", escapeJsonString(lines.joinToString("\n")))
            .replace("{{messages_count}}", messages.size.toString())
            .replace("{{is_group_summary}}", isGroupSummary.toString())
            .replace("{{timestamp}}", timestamp.toString())
            .replace("{{datetime}}", escapeJsonString(dateStr))

        for (i in regexMatches.indices) {
            result = result.replace("{{group${i + 1}}}", escapeJsonString(regexMatches[i]))
        }
        for ((name, value) in namedRegexMatches) {
            result = result.replace("{{$name}}", escapeJsonString(value))
        }
        return result
    }

    private fun escapeJsonString(str: String): String {
        return JSONObject.quote(str).let {
            if (it.startsWith("\"") && it.endsWith("\"") && it.length >= 2) {
                it.substring(1, it.length - 1)
            } else it
        }
    }

    private fun calculateHmacSha256(data: String, key: String): String {
        return try {
            val algorithm = "HmacSHA256"
            val mac = Mac.getInstance(algorithm)
            val secretKeySpec = SecretKeySpec(key.toByteArray(Charsets.UTF_8), algorithm)
            mac.init(secretKeySpec)
            val bytes = mac.doFinal(data.toByteArray(Charsets.UTF_8))
            val sb = StringBuilder(bytes.size * 2)
            for (b in bytes) {
                sb.append(String.format("%02x", b))
            }
            sb.toString()
        } catch (e: Exception) {
            ""
        }
    }
}
