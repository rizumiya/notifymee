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
    val deduplicateMessages: Boolean = true,
    val ignoreOngoing: Boolean = true,
    val cooldownSeconds: Int = 0
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
        obj.put("ignoreOngoing", ignoreOngoing)
        obj.put("cooldownSeconds", cooldownSeconds)
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
                deduplicateMessages = obj.optBoolean("deduplicateMessages", true),
                ignoreOngoing = obj.optBoolean("ignoreOngoing", true),
                cooldownSeconds = obj.optInt("cooldownSeconds", 0)
            )
        }
    }
}

object RuleStore {
    @Volatile
    private var cachedRules: List<WebhookRule>? = null

    fun getRules(context: Context): List<WebhookRule> {
        cachedRules?.let { return it }
        val db = AppDatabase.getInstance(context.applicationContext)
        val rules = db.getAllRules()
        if (rules.isEmpty()) {
            val defaultList = getDefaultRules()
            val array = JSONArray()
            for (r in defaultList) {
                array.put(r.toJson())
            }
            db.saveRulesJson(array.toString())
            cachedRules = defaultList
            return defaultList
        }
        cachedRules = rules
        return rules
    }

    fun getRulesJson(context: Context): String {
        val rules = getRules(context)
        val array = JSONArray()
        for (r in rules) {
            array.put(r.toJson())
        }
        return array.toString()
    }

    fun saveRulesJson(context: Context, jsonStr: String) {
        val db = AppDatabase.getInstance(context.applicationContext)
        db.saveRulesJson(jsonStr)
        cachedRules = db.getAllRules()
    }

    fun invalidateCache() {
        cachedRules = null
    }

    private fun getDefaultRules(): List<WebhookRule> {
        return listOf(
            WebhookRule(
                id = "rule_default_all",
                name = "Aturan Gateway Notifikasi",
                enabled = true,
                packageName = "*",
                regexPattern = "",
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
                deduplicateMessages = true,
                ignoreOngoing = true,
                cooldownSeconds = 0
            )
        )
    }
}
