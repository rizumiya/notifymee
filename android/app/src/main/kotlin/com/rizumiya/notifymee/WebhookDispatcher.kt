package com.rizumiya.notifymee

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

object WebhookDispatcher {
    private val executor = Executors.newCachedThreadPool()
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
        isGroupSummary: Boolean = false,
        notificationKey: String = "",
        lines: List<String> = emptyList(),
        messages: List<Map<String, Any>> = emptyList(),
        conversationTitle: String = "",
        latestMessage: String = "",
        onComplete: ((Boolean, Int, String) -> Unit)? = null
    ) {
        executor.execute {
            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", Locale.getDefault())
            val dateStr = isoFormat.format(Date(timestamp))

            // Build payload (Universal & Global Format)
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
                    isGroupSummary = isGroupSummary,
                    lines = lines,
                    messages = messages,
                    conversationTitle = conversationTitle,
                    latestMessage = latestMessage
                )
            }

            // HTTP Request with Retry Mechanism
            val maxAttempts = if (rule.maxRetries > 0) rule.maxRetries else 1
            var attempt = 0
            var isSuccess = false
            var httpStatus = 0
            var responseBody = ""
            var errorMessage = ""
            val startTime = System.currentTimeMillis()

            while (attempt < maxAttempts && !isSuccess) {
                attempt++
                try {
                    val url = URL(rule.webhookUrl)
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = rule.httpMethod.uppercase(Locale.US)
                    conn.connectTimeout = 12000
                    conn.readTimeout = 12000
                    conn.instanceFollowRedirects = true

                    // Apply user headers
                    for ((key, value) in rule.headers) {
                        conn.setRequestProperty(key, value)
                    }

                    // Optional HMAC-SHA256 Signature Header
                    if (rule.secretKey.isNotBlank()) {
                        val signature = calculateHmacSha256(payloadString, rule.secretKey)
                        conn.setRequestProperty("X-Webhook-Signature", "sha256=$signature")
                    }

                    if (rule.httpMethod.equals("POST", ignoreCase = true) || 
                        rule.httpMethod.equals("PUT", ignoreCase = true)) {
                        conn.doOutput = true
                        if (!rule.headers.containsKey("Content-Type")) {
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
                    } else {
                        errorMessage = "Server merespons HTTP $httpStatus"
                        if (attempt < maxAttempts) {
                            Thread.sleep(2000L * attempt) // Exponential backoff
                        }
                    }
                } catch (e: Exception) {
                    errorMessage = e.message ?: e.javaClass.simpleName
                    if (attempt < maxAttempts) {
                        try {
                            Thread.sleep(2000L * attempt)
                        } catch (_: InterruptedException) {}
                    }
                }
            }

            val latencyMs = System.currentTimeMillis() - startTime
            if (!isSuccess && maxAttempts > 1) {
                errorMessage = "$errorMessage ($attempt percobaan gagal)"
            }

            // Save log to SQLite via NotificationLogStore
            val logEntry = NotificationLogStore.createLogEntry(
                packageName = packageName,
                title = title,
                text = text.ifBlank { fullContent },
                matched = true,
                matchedRuleName = rule.name,
                webhookUrl = rule.webhookUrl,
                httpStatus = httpStatus,
                responseBody = responseBody,
                errorMessage = errorMessage,
                latencyMs = latencyMs,
                payloadSent = payloadString
            )
            val logStatus = if (isSuccess) "SUCCESS" else "FAILED"
            NotificationLogStore.addLog(
                context = context,
                logItem = logEntry,
                notificationKey = notificationKey,
                status = logStatus,
                isGroupSummary = isGroupSummary
            )

            // Notify UI
            mainHandler.post {
                onLogUpdated?.invoke()
                onComplete?.invoke(isSuccess, httpStatus, if (isSuccess) responseBody else errorMessage)
            }
        }
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
        isGroupSummary: Boolean = false,
        lines: List<String> = emptyList(),
        messages: List<Map<String, Any>> = emptyList(),
        conversationTitle: String = "",
        latestMessage: String = ""
    ): String {
        var result = template
            .replace("{{rule_id}}", rule.id)
            .replace("{{rule_name}}", rule.name)
            .replace("{{package_name}}", packageName)
            .replace("{{app_name}}", appName.ifBlank { packageName })
            .replace("{{title}}", escapeJsonString(title))
            .replace("{{text}}", escapeJsonString(text))
            .replace("{{latest_message}}", escapeJsonString(latestMessage))
            .replace("{{conversation_title}}", escapeJsonString(conversationTitle))
            .replace("{{big_text}}", escapeJsonString(bigText))
            .replace("{{sub_text}}", escapeJsonString(subText))
            .replace("{{full_content}}", escapeJsonString(fullContent))
            .replace("{{is_group_summary}}", isGroupSummary.toString())
            .replace("{{timestamp}}", timestamp.toString())
            .replace("{{datetime}}", dateStr)

        for (i in regexMatches.indices) {
            result = result.replace("{{group${i + 1}}}", escapeJsonString(regexMatches[i]))
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
            val sb = StringBuilder()
            for (b in bytes) {
                sb.append(String.format("%02x", b))
            }
            sb.toString()
        } catch (e: Exception) {
            ""
        }
    }
}
