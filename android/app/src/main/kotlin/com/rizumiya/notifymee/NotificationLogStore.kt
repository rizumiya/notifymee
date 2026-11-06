package com.rizumiya.notifymee

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object NotificationLogStore {

    @Synchronized
    fun addLog(
        context: Context,
        logItem: JSONObject,
        notificationKey: String = "",
        status: String = "SUCCESS",
        isGroupSummary: Boolean = false
    ) {
        try {
            val db = AppDatabase.getInstance(context)
            val key = notificationKey.ifBlank {
                logItem.optString("packageName") + "|" + logItem.optString("title") + "|" + logItem.optString("text")
            }
            db.insertOrUpdateLog(
                id = logItem.optString("id", System.currentTimeMillis().toString()),
                notificationKey = key,
                timestamp = logItem.optLong("timestamp", System.currentTimeMillis()),
                datetime = logItem.optString("datetime", ""),
                packageName = logItem.optString("packageName", ""),
                title = logItem.optString("title", ""),
                text = logItem.optString("text", ""),
                matched = logItem.optBoolean("matched", false),
                matchedRuleName = logItem.optString("matchedRuleName", "-"),
                webhookUrl = logItem.optString("webhookUrl", "-"),
                httpStatus = logItem.optInt("httpStatus", 0),
                responseBody = logItem.optString("responseBody", ""),
                errorMessage = logItem.optString("errorMessage", ""),
                latencyMs = logItem.optLong("latencyMs", 0),
                payloadSent = logItem.optString("payloadSent", ""),
                status = status,
                isGroupSummary = isGroupSummary
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    @Synchronized
    fun getLogsJson(context: Context): String {
        return AppDatabase.getInstance(context).getLogsJson(250)
    }

    @Synchronized
    fun clearLogs(context: Context) {
        AppDatabase.getInstance(context).clearLogs()
    }

    fun createLogEntry(
        id: String = System.currentTimeMillis().toString(),
        timestamp: Long = System.currentTimeMillis(),
        packageName: String,
        title: String,
        text: String,
        matched: Boolean,
        matchedRuleName: String = "",
        webhookUrl: String = "",
        httpStatus: Int = 0,
        responseBody: String = "",
        errorMessage: String = "",
        latencyMs: Long = 0,
        payloadSent: String = ""
    ): JSONObject {
        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", Locale.getDefault())
        val obj = JSONObject()
        obj.put("id", id)
        obj.put("timestamp", timestamp)
        obj.put("datetime", isoFormat.format(Date(timestamp)))
        obj.put("packageName", packageName)
        obj.put("title", title)
        obj.put("text", text)
        obj.put("matched", matched)
        obj.put("matchedRuleName", matchedRuleName)
        obj.put("webhookUrl", webhookUrl)
        obj.put("httpStatus", httpStatus)
        obj.put("responseBody", responseBody)
        obj.put("errorMessage", errorMessage)
        obj.put("latencyMs", latencyMs)
        obj.put("payloadSent", payloadSent)
        return obj
    }
}

