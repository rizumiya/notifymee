package com.rizumiya.notifymee

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class WebhookRule(
    val id: String,
    val name: String,
    val enabled: Boolean,
    val packageName: String, // Empty or "*" means all apps
    val regexPattern: String,
    val regexIgnoreCase: Boolean = true,
    val webhookUrl: String,
    val httpMethod: String = "POST",
    val headers: Map<String, String> = mapOf("Content-Type" to "application/json"),
    val customPayload: String = "",
    val sendOnlyIfMatched: Boolean = true,
    val secretKey: String = "",
    val maxRetries: Int = 3,
    val ignoreGroupSummary: Boolean = true,
    val deduplicateMessages: Boolean = true
) {
    fun toJson(): JSONObject {
        val obj = JSONObject()
        obj.put("id", id)
        obj.put("name", name)
        obj.put("enabled", enabled)
        obj.put("packageName", packageName)
        obj.put("regexPattern", regexPattern)
        obj.put("regexIgnoreCase", regexIgnoreCase)
        obj.put("webhookUrl", webhookUrl)
        obj.put("httpMethod", httpMethod)
        
        val headersObj = JSONObject()
        for ((k, v) in headers) {
            headersObj.put(k, v)
        }
        obj.put("headers", headersObj)
        obj.put("customPayload", customPayload)
        obj.put("sendOnlyIfMatched", sendOnlyIfMatched)
        obj.put("secretKey", secretKey)
        obj.put("maxRetries", maxRetries)
        obj.put("ignoreGroupSummary", ignoreGroupSummary)
        obj.put("deduplicateMessages", deduplicateMessages)
        return obj
    }

    companion object {
        fun fromJson(obj: JSONObject): WebhookRule {
            val headersMap = mutableMapOf<String, String>()
            val headersObj = obj.optJSONObject("headers")
            if (headersObj != null) {
                val keys = headersObj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    headersMap[key] = headersObj.optString(key, "")
                }
            } else {
                headersMap["Content-Type"] = "application/json"
            }

            return WebhookRule(
                id = obj.optString("id", System.currentTimeMillis().toString()),
                name = obj.optString("name", "Untitled Rule"),
                enabled = obj.optBoolean("enabled", true),
                packageName = obj.optString("packageName", ""),
                regexPattern = obj.optString("regexPattern", ""),
                regexIgnoreCase = obj.optBoolean("regexIgnoreCase", true),
                webhookUrl = obj.optString("webhookUrl", ""),
                httpMethod = obj.optString("httpMethod", "POST"),
                headers = headersMap,
                customPayload = obj.optString("customPayload", ""),
                sendOnlyIfMatched = obj.optBoolean("sendOnlyIfMatched", true),
                secretKey = obj.optString("secretKey", ""),
                maxRetries = obj.optInt("maxRetries", 3),
                ignoreGroupSummary = obj.optBoolean("ignoreGroupSummary", true),
                deduplicateMessages = obj.optBoolean("deduplicateMessages", true)
            )
        }
    }
}

object RuleStore {
    fun getRules(context: Context): List<WebhookRule> {
        val db = AppDatabase.getInstance(context)
        val rules = db.getAllRules()
        if (rules.isEmpty()) {
            val defaultList = getDefaultRules()
            val array = JSONArray()
            for (r in defaultList) {
                array.put(r.toJson())
            }
            db.saveRulesJson(array.toString())
            return defaultList
        }
        return rules
    }

    fun getRulesJson(context: Context): String {
        val db = AppDatabase.getInstance(context)
        val jsonStr = db.getRulesJson()
        if (jsonStr != "[]") {
            return jsonStr
        }
        val defaultList = getDefaultRules()
        val array = JSONArray()
        for (r in defaultList) {
            array.put(r.toJson())
        }
        val defaultStr = array.toString()
        db.saveRulesJson(defaultStr)
        return defaultStr
    }

    fun saveRulesJson(context: Context, jsonStr: String) {
        AppDatabase.getInstance(context).saveRulesJson(jsonStr)
    }

    private fun getDefaultRules(): List<WebhookRule> {
        return listOf(
            WebhookRule(
                id = "rule_default_all",
                name = "Aturan Gateway Notifikasi",
                enabled = true,
                packageName = "*",
                regexPattern = "", // Empty = Match ALL messages
                regexIgnoreCase = true,
                webhookUrl = "https://your-domain.com/webhook/endpoint",
                httpMethod = "POST",
                headers = mapOf(
                    "Content-Type" to "application/json",
                    "X-Webhook-Source" to "Notifymee-Gateway"
                ),
                customPayload = "",
                sendOnlyIfMatched = false,
                secretKey = "",
                maxRetries = 3,
                ignoreGroupSummary = true,
                deduplicateMessages = true
            )
        )
    }
}

