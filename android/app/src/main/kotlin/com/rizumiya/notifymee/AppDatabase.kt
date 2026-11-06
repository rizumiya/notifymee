package com.rizumiya.notifymee

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class AppDatabase private constructor(private val context: Context) :
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val TAG = "AppDatabase"
        const val DATABASE_NAME = "notif_webhook.db"
        const val DATABASE_VERSION = 1

        @Volatile
        private var instance: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase {
            return instance ?: synchronized(this) {
                instance ?: AppDatabase(context.applicationContext).also {
                    instance = it
                    it.migrateFromPreferencesIfNeeded()
                }
            }
        }

        // Table Rules
        const val TABLE_RULES = "rules"
        const val COL_RULE_ID = "id"
        const val COL_RULE_NAME = "name"
        const val COL_RULE_ENABLED = "enabled"
        const val COL_RULE_PACKAGE = "package_name"
        const val COL_RULE_REGEX = "regex_pattern"
        const val COL_RULE_IGNORE_CASE = "regex_ignore_case"
        const val COL_RULE_WEBHOOK_URL = "webhook_url"
        const val COL_RULE_HTTP_METHOD = "http_method"
        const val COL_RULE_HEADERS = "headers_json"
        const val COL_RULE_CUSTOM_PAYLOAD = "custom_payload"
        const val COL_RULE_SEND_ONLY_MATCHED = "send_only_if_matched"
        const val COL_RULE_SECRET_KEY = "secret_key"
        const val COL_RULE_MAX_RETRIES = "max_retries"
        const val COL_RULE_IGNORE_GROUP_SUMMARY = "ignore_group_summary"
        const val COL_RULE_DEDUPLICATE = "deduplicate_messages"
        const val COL_RULE_CREATED_AT = "created_at"

        // Table Notification Logs
        const val TABLE_LOGS = "notification_logs"
        const val COL_LOG_ID = "id"
        const val COL_LOG_KEY = "notification_key"
        const val COL_LOG_TIMESTAMP = "timestamp"
        const val COL_LOG_DATETIME = "datetime"
        const val COL_LOG_PACKAGE = "package_name"
        const val COL_LOG_TITLE = "title"
        const val COL_LOG_TEXT = "text"
        const val COL_LOG_MATCHED = "matched"
        const val COL_LOG_RULE_NAME = "matched_rule_name"
        const val COL_LOG_WEBHOOK_URL = "webhook_url"
        const val COL_LOG_HTTP_STATUS = "http_status"
        const val COL_LOG_RESPONSE = "response_body"
        const val COL_LOG_ERROR = "error_message"
        const val COL_LOG_LATENCY = "latency_ms"
        const val COL_LOG_PAYLOAD = "payload_sent"
        const val COL_LOG_STATUS = "status" // 'SUCCESS', 'FAILED', 'SKIPPED', 'PENDING'
        const val COL_LOG_IS_SUMMARY = "is_group_summary"

        // Table Package Blacklist / Exclude
        const val TABLE_BLACKLIST = "package_blacklist"
        const val COL_BL_ID = "id"
        const val COL_BL_PACKAGE = "package_name"
        const val COL_BL_PATTERN = "pattern"
        const val COL_BL_CREATED_AT = "created_at"
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createRulesSql = """
            CREATE TABLE IF NOT EXISTS $TABLE_RULES (
                $COL_RULE_ID TEXT PRIMARY KEY,
                $COL_RULE_NAME TEXT NOT NULL,
                $COL_RULE_ENABLED INTEGER NOT NULL DEFAULT 1,
                $COL_RULE_PACKAGE TEXT,
                $COL_RULE_REGEX TEXT,
                $COL_RULE_IGNORE_CASE INTEGER DEFAULT 1,
                $COL_RULE_WEBHOOK_URL TEXT NOT NULL,
                $COL_RULE_HTTP_METHOD TEXT DEFAULT 'POST',
                $COL_RULE_HEADERS TEXT,
                $COL_RULE_CUSTOM_PAYLOAD TEXT,
                $COL_RULE_SEND_ONLY_MATCHED INTEGER DEFAULT 1,
                $COL_RULE_SECRET_KEY TEXT,
                $COL_RULE_MAX_RETRIES INTEGER DEFAULT 3,
                $COL_RULE_IGNORE_GROUP_SUMMARY INTEGER DEFAULT 1,
                $COL_RULE_DEDUPLICATE INTEGER DEFAULT 1,
                $COL_RULE_CREATED_AT INTEGER
            );
        """.trimIndent()

        val createLogsSql = """
            CREATE TABLE IF NOT EXISTS $TABLE_LOGS (
                $COL_LOG_ID TEXT PRIMARY KEY,
                $COL_LOG_KEY TEXT,
                $COL_LOG_TIMESTAMP INTEGER,
                $COL_LOG_DATETIME TEXT,
                $COL_LOG_PACKAGE TEXT,
                $COL_LOG_TITLE TEXT,
                $COL_LOG_TEXT TEXT,
                $COL_LOG_MATCHED INTEGER DEFAULT 0,
                $COL_LOG_RULE_NAME TEXT,
                $COL_LOG_WEBHOOK_URL TEXT,
                $COL_LOG_HTTP_STATUS INTEGER DEFAULT 0,
                $COL_LOG_RESPONSE TEXT,
                $COL_LOG_ERROR TEXT,
                $COL_LOG_LATENCY INTEGER DEFAULT 0,
                $COL_LOG_PAYLOAD TEXT,
                $COL_LOG_STATUS TEXT DEFAULT 'PENDING',
                $COL_LOG_IS_SUMMARY INTEGER DEFAULT 0
            );
        """.trimIndent()

        val createBlacklistSql = """
            CREATE TABLE IF NOT EXISTS $TABLE_BLACKLIST (
                $COL_BL_ID TEXT PRIMARY KEY,
                $COL_BL_PACKAGE TEXT NOT NULL,
                $COL_BL_PATTERN TEXT NOT NULL,
                $COL_BL_CREATED_AT INTEGER NOT NULL
            );
        """.trimIndent()

        db.execSQL(createRulesSql)
        db.execSQL(createLogsSql)
        db.execSQL(createBlacklistSql)
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_logs_key ON $TABLE_LOGS($COL_LOG_KEY);")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON $TABLE_LOGS($COL_LOG_TIMESTAMP DESC);")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_bl_pkg ON $TABLE_BLACKLIST($COL_BL_PACKAGE);")
        Log.i(TAG, "SQLite database created with rules, logs, and blacklist tables.")
    }

    override fun onOpen(db: SQLiteDatabase) {
        super.onOpen(db)
        db.execSQL("""
            CREATE TABLE IF NOT EXISTS $TABLE_BLACKLIST (
                $COL_BL_ID TEXT PRIMARY KEY,
                $COL_BL_PACKAGE TEXT NOT NULL,
                $COL_BL_PATTERN TEXT NOT NULL,
                $COL_BL_CREATED_AT INTEGER NOT NULL
            );
        """.trimIndent())
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_bl_pkg ON $TABLE_BLACKLIST($COL_BL_PACKAGE);")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Future schema migrations
    }

    // ==========================================
    // NOTIFICATION PROCESSING TRACKER
    // ==========================================

    /**
     * Checks if a notification with the given key was already processed and successfully sent.
     */
    @Synchronized
    fun isNotificationProcessed(notificationKey: String): Boolean {
        if (notificationKey.isBlank()) return false
        val db = readableDatabase
        val cursor: Cursor = db.rawQuery(
            "SELECT 1 FROM $TABLE_LOGS WHERE $COL_LOG_KEY = ? AND $COL_LOG_STATUS = 'SUCCESS' LIMIT 1",
            arrayOf(notificationKey)
        )
        val exists = cursor.moveToFirst()
        cursor.close()
        return exists
    }

    /**
     * Checks if an identical message (same package, title, and text) was successfully dispatched recently.
     * Prevents duplicate webhooks when apps repost unread messages upon new incoming notifications.
     */
    @Synchronized
    fun isRecentMessageProcessed(packageName: String, title: String, text: String, windowMs: Long = 1800000L): Boolean {
        if (text.isBlank()) return false
        val db = readableDatabase
        val cutoff = System.currentTimeMillis() - windowMs
        val cursor: Cursor = db.rawQuery(
            "SELECT 1 FROM $TABLE_LOGS WHERE $COL_LOG_PACKAGE = ? AND $COL_LOG_TITLE = ? AND $COL_LOG_TEXT = ? AND $COL_LOG_STATUS = 'SUCCESS' AND $COL_LOG_TIMESTAMP >= ? LIMIT 1",
            arrayOf(packageName, title, text, cutoff.toString())
        )
        val exists = cursor.moveToFirst()
        cursor.close()
        return exists
    }

    /**
     * Checks whether a notification with this key has ever been captured in any state.
     */
    @Synchronized
    fun getNotificationStatus(notificationKey: String): String? {
        if (notificationKey.isBlank()) return null
        val db = readableDatabase
        val cursor: Cursor = db.rawQuery(
            "SELECT $COL_LOG_STATUS FROM $TABLE_LOGS WHERE $COL_LOG_KEY = ? ORDER BY $COL_LOG_TIMESTAMP DESC LIMIT 1",
            arrayOf(notificationKey)
        )
        var status: String? = null
        if (cursor.moveToFirst()) {
            status = cursor.getString(0)
        }
        cursor.close()
        return status
    }

    /**
     * Inserts or updates a log entry in SQLite.
     */
    @Synchronized
    fun insertOrUpdateLog(
        id: String,
        notificationKey: String,
        timestamp: Long,
        datetime: String,
        packageName: String,
        title: String,
        text: String,
        matched: Boolean,
        matchedRuleName: String,
        webhookUrl: String,
        httpStatus: Int,
        responseBody: String,
        errorMessage: String,
        latencyMs: Long,
        payloadSent: String,
        status: String,
        isGroupSummary: Boolean
    ) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COL_LOG_ID, id)
            put(COL_LOG_KEY, notificationKey)
            put(COL_LOG_TIMESTAMP, timestamp)
            put(COL_LOG_DATETIME, datetime)
            put(COL_LOG_PACKAGE, packageName)
            put(COL_LOG_TITLE, title)
            put(COL_LOG_TEXT, text)
            put(COL_LOG_MATCHED, if (matched) 1 else 0)
            put(COL_LOG_RULE_NAME, matchedRuleName)
            put(COL_LOG_WEBHOOK_URL, webhookUrl)
            put(COL_LOG_HTTP_STATUS, httpStatus)
            put(COL_LOG_RESPONSE, responseBody)
            put(COL_LOG_ERROR, errorMessage)
            put(COL_LOG_LATENCY, latencyMs)
            put(COL_LOG_PAYLOAD, payloadSent)
            put(COL_LOG_STATUS, status)
            put(COL_LOG_IS_SUMMARY, if (isGroupSummary) 1 else 0)
        }
        db.insertWithOnConflict(TABLE_LOGS, null, values, SQLiteDatabase.CONFLICT_REPLACE)

        // Keep maximum 300 logs
        db.execSQL(
            "DELETE FROM $TABLE_LOGS WHERE $COL_LOG_ID NOT IN (" +
                    "SELECT $COL_LOG_ID FROM $TABLE_LOGS ORDER BY $COL_LOG_TIMESTAMP DESC LIMIT 300)"
        )
    }

    @Synchronized
    fun getLogsJson(limit: Int = 200): String {
        val db = readableDatabase
        val cursor = db.rawQuery(
            "SELECT * FROM $TABLE_LOGS ORDER BY $COL_LOG_TIMESTAMP DESC LIMIT ?",
            arrayOf(limit.toString())
        )
        val array = JSONArray()
        while (cursor.moveToNext()) {
            val obj = JSONObject()
            obj.put("id", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_ID)))
            obj.put("notificationKey", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_KEY)))
            obj.put("timestamp", cursor.getLong(cursor.getColumnIndexOrThrow(COL_LOG_TIMESTAMP)))
            obj.put("datetime", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_DATETIME)))
            obj.put("packageName", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_PACKAGE)))
            obj.put("title", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_TITLE)))
            obj.put("text", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_TEXT)))
            obj.put("matched", cursor.getInt(cursor.getColumnIndexOrThrow(COL_LOG_MATCHED)) == 1)
            obj.put("matchedRuleName", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_RULE_NAME)))
            obj.put("webhookUrl", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_WEBHOOK_URL)))
            obj.put("httpStatus", cursor.getInt(cursor.getColumnIndexOrThrow(COL_LOG_HTTP_STATUS)))
            obj.put("responseBody", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_RESPONSE)))
            obj.put("errorMessage", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_ERROR)))
            obj.put("latencyMs", cursor.getLong(cursor.getColumnIndexOrThrow(COL_LOG_LATENCY)))
            obj.put("payloadSent", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_PAYLOAD)))
            obj.put("status", cursor.getString(cursor.getColumnIndexOrThrow(COL_LOG_STATUS)))
            obj.put("isGroupSummary", cursor.getInt(cursor.getColumnIndexOrThrow(COL_LOG_IS_SUMMARY)) == 1)
            array.put(obj)
        }
        cursor.close()
        return array.toString()
    }

    @Synchronized
    fun clearLogs() {
        val db = writableDatabase
        db.delete(TABLE_LOGS, null, null)
    }

    // ==========================================
    // RULES MANAGEMENT
    // ==========================================

    @Synchronized
    fun getAllRules(): List<WebhookRule> {
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT * FROM $TABLE_RULES ORDER BY $COL_RULE_CREATED_AT ASC", null)
        val list = mutableListOf<WebhookRule>()
        while (cursor.moveToNext()) {
            val headersJsonStr = cursor.getString(cursor.getColumnIndexOrThrow(COL_RULE_HEADERS)) ?: "{}"
            val headersMap = mutableMapOf<String, String>()
            try {
                val hObj = JSONObject(headersJsonStr)
                val it = hObj.keys()
                while (it.hasNext()) {
                    val k = it.next()
                    headersMap[k] = hObj.optString(k, "")
                }
            } catch (_: Exception) {}
            if (!headersMap.containsKey("Content-Type")) {
                headersMap["Content-Type"] = "application/json"
            }

            list.add(
                WebhookRule(
                    id = cursor.getString(cursor.getColumnIndexOrThrow(COL_RULE_ID)),
                    name = cursor.getString(cursor.getColumnIndexOrThrow(COL_RULE_NAME)),
                    enabled = cursor.getInt(cursor.getColumnIndexOrThrow(COL_RULE_ENABLED)) == 1,
                    packageName = cursor.getString(cursor.getColumnIndexOrThrow(COL_RULE_PACKAGE)) ?: "",
                    regexPattern = cursor.getString(cursor.getColumnIndexOrThrow(COL_RULE_REGEX)) ?: "",
                    regexIgnoreCase = cursor.getInt(cursor.getColumnIndexOrThrow(COL_RULE_IGNORE_CASE)) == 1,
                    webhookUrl = cursor.getString(cursor.getColumnIndexOrThrow(COL_RULE_WEBHOOK_URL)),
                    httpMethod = cursor.getString(cursor.getColumnIndexOrThrow(COL_RULE_HTTP_METHOD)) ?: "POST",
                    headers = headersMap,
                    customPayload = cursor.getString(cursor.getColumnIndexOrThrow(COL_RULE_CUSTOM_PAYLOAD)) ?: "",
                    sendOnlyIfMatched = cursor.getInt(cursor.getColumnIndexOrThrow(COL_RULE_SEND_ONLY_MATCHED)) == 1,
                    secretKey = cursor.getString(cursor.getColumnIndexOrThrow(COL_RULE_SECRET_KEY)) ?: "",
                    maxRetries = cursor.getInt(cursor.getColumnIndexOrThrow(COL_RULE_MAX_RETRIES)),
                    ignoreGroupSummary = cursor.getInt(cursor.getColumnIndexOrThrow(COL_RULE_IGNORE_GROUP_SUMMARY)) == 1,
                    deduplicateMessages = cursor.getInt(cursor.getColumnIndexOrThrow(COL_RULE_DEDUPLICATE)) == 1
                )
            )
        }
        cursor.close()
        return list
    }

    @Synchronized
    fun getRulesJson(): String {
        val rules = getAllRules()
        val array = JSONArray()
        for (r in rules) {
            array.put(r.toJson())
        }
        return array.toString()
    }

    @Synchronized
    fun saveRulesJson(jsonStr: String) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.delete(TABLE_RULES, null, null)
            val array = JSONArray(jsonStr)
            val now = System.currentTimeMillis()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val rule = WebhookRule.fromJson(obj)
                val values = ContentValues().apply {
                    put(COL_RULE_ID, rule.id)
                    put(COL_RULE_NAME, rule.name)
                    put(COL_RULE_ENABLED, if (rule.enabled) 1 else 0)
                    put(COL_RULE_PACKAGE, rule.packageName)
                    put(COL_RULE_REGEX, rule.regexPattern)
                    put(COL_RULE_IGNORE_CASE, if (rule.regexIgnoreCase) 1 else 0)
                    put(COL_RULE_WEBHOOK_URL, rule.webhookUrl)
                    put(COL_RULE_HTTP_METHOD, rule.httpMethod)
                    put(COL_RULE_HEADERS, JSONObject(rule.headers as Map<*, *>).toString())
                    put(COL_RULE_CUSTOM_PAYLOAD, rule.customPayload)
                    put(COL_RULE_SEND_ONLY_MATCHED, if (rule.sendOnlyIfMatched) 1 else 0)
                    put(COL_RULE_SECRET_KEY, rule.secretKey)
                    put(COL_RULE_MAX_RETRIES, rule.maxRetries)
                    put(COL_RULE_IGNORE_GROUP_SUMMARY, if (rule.ignoreGroupSummary) 1 else 0)
                    put(COL_RULE_DEDUPLICATE, if (rule.deduplicateMessages) 1 else 0)
                    put(COL_RULE_CREATED_AT, now + i)
                }
                db.insertWithOnConflict(TABLE_RULES, null, values, SQLiteDatabase.CONFLICT_REPLACE)
            }
            db.setTransactionSuccessful()
            Log.i(TAG, "Saved ${array.length()} rules to SQLite successfully.")
        } finally {
            db.endTransaction()
        }
    }

    // ==========================================
    // EXPORT & IMPORT FULL CONFIGURATION (JSON)
    // ==========================================

    @Synchronized
    fun exportFullConfigJson(): String {
        val root = JSONObject()
        root.put("version", 1)
        root.put("exportedAt", System.currentTimeMillis())
        root.put("rules", JSONArray(getRulesJson()))
        return root.toString(2)
    }

    @Synchronized
    fun importFullConfigJson(jsonStr: String): Boolean {
        return try {
            val root = JSONObject(jsonStr)
            val rulesArray = root.optJSONArray("rules") ?: JSONArray(jsonStr)
            saveRulesJson(rulesArray.toString())
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to import full config: ${e.message}")
            false
        }
    }

    // ==========================================
    // PACKAGE BLACKLIST / EXCLUDE ENGINE
    // ==========================================

    @Synchronized
    fun addBlacklist(packageName: String, pattern: String): Boolean {
        if (packageName.isBlank() || pattern.isBlank()) return false
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COL_BL_ID, "bl_${System.currentTimeMillis()}_${(1000..9999).random()}")
            put(COL_BL_PACKAGE, packageName.trim())
            put(COL_BL_PATTERN, pattern.trim())
            put(COL_BL_CREATED_AT, System.currentTimeMillis())
        }
        val res = db.insertWithOnConflict(TABLE_BLACKLIST, null, values, SQLiteDatabase.CONFLICT_REPLACE)
        return res != -1L
    }

    @Synchronized
    fun deleteBlacklist(id: String): Boolean {
        val db = writableDatabase
        return db.delete(TABLE_BLACKLIST, "$COL_BL_ID = ?", arrayOf(id)) > 0
    }

    @Synchronized
    fun getBlacklistForPackage(packageName: String): List<Map<String, String>> {
        val db = readableDatabase
        val cursor = db.rawQuery(
            "SELECT * FROM $TABLE_BLACKLIST WHERE $COL_BL_PACKAGE = ? OR $COL_BL_PACKAGE = '*' ORDER BY $COL_BL_CREATED_AT DESC",
            arrayOf(packageName)
        )
        val list = mutableListOf<Map<String, String>>()
        while (cursor.moveToNext()) {
            list.add(
                mapOf(
                    "id" to (cursor.getString(cursor.getColumnIndexOrThrow(COL_BL_ID)) ?: ""),
                    "packageName" to (cursor.getString(cursor.getColumnIndexOrThrow(COL_BL_PACKAGE)) ?: ""),
                    "pattern" to (cursor.getString(cursor.getColumnIndexOrThrow(COL_BL_PATTERN)) ?: ""),
                    "createdAt" to cursor.getLong(cursor.getColumnIndexOrThrow(COL_BL_CREATED_AT)).toString()
                )
            )
        }
        cursor.close()
        return list
    }

    @Synchronized
    fun getAllBlacklist(): List<Map<String, String>> {
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT * FROM $TABLE_BLACKLIST ORDER BY $COL_BL_CREATED_AT DESC", null)
        val list = mutableListOf<Map<String, String>>()
        while (cursor.moveToNext()) {
            list.add(
                mapOf(
                    "id" to (cursor.getString(cursor.getColumnIndexOrThrow(COL_BL_ID)) ?: ""),
                    "packageName" to (cursor.getString(cursor.getColumnIndexOrThrow(COL_BL_PACKAGE)) ?: ""),
                    "pattern" to (cursor.getString(cursor.getColumnIndexOrThrow(COL_BL_PATTERN)) ?: ""),
                    "createdAt" to cursor.getLong(cursor.getColumnIndexOrThrow(COL_BL_CREATED_AT)).toString()
                )
            )
        }
        cursor.close()
        return list
    }

    @Synchronized
    fun checkBlacklisted(packageName: String, title: String, text: String, fullContent: String): String? {
        val list = getBlacklistForPackage(packageName)
        for (item in list) {
            val pat = item["pattern"] ?: continue
            if (pat.isBlank()) continue
            try {
                if (text.contains(pat, ignoreCase = true) ||
                    title.contains(pat, ignoreCase = true) ||
                    fullContent.contains(pat, ignoreCase = true)) {
                    return pat
                }
                val regex = Regex(pat, RegexOption.IGNORE_CASE)
                if (regex.containsMatchIn(text) || regex.containsMatchIn(title) || regex.containsMatchIn(fullContent)) {
                    return pat
                }
            } catch (_: Exception) {}
        }
        return null
    }

    // ==========================================
    // AUTOMATIC MIGRATION FROM SHAREDPREFS
    // ==========================================

    private fun migrateFromPreferencesIfNeeded() {
        try {
            val db = readableDatabase
            val cursor = db.rawQuery("SELECT COUNT(*) FROM $TABLE_RULES", null)
            var ruleCount = 0
            if (cursor.moveToFirst()) {
                ruleCount = cursor.getInt(0)
            }
            cursor.close()

            if (ruleCount == 0) {
                // Check if old SharedPreferences has rules
                val prefs = context.getSharedPreferences("notif_webhook_prefs", Context.MODE_PRIVATE)
                val legacyRules = prefs.getString("saved_rules", null)
                if (!legacyRules.isNullOrBlank() && legacyRules != "[]") {
                    Log.i(TAG, "Migrating legacy rules from SharedPreferences to SQLite...")
                    saveRulesJson(legacyRules)
                }

                val legacyLogs = prefs.getString("notification_logs", null)
                if (!legacyLogs.isNullOrBlank() && legacyLogs != "[]") {
                    val arr = JSONArray(legacyLogs)
                    for (i in 0 until arr.length()) {
                        val obj = arr.getJSONObject(i)
                        insertOrUpdateLog(
                            id = obj.optString("id", System.currentTimeMillis().toString()),
                            notificationKey = obj.optString("packageName") + "|" + obj.optString("title") + "|" + obj.optString("text"),
                            timestamp = obj.optLong("timestamp", System.currentTimeMillis()),
                            datetime = obj.optString("datetime", ""),
                            packageName = obj.optString("packageName", ""),
                            title = obj.optString("title", ""),
                            text = obj.optString("text", ""),
                            matched = obj.optBoolean("matched", false),
                            matchedRuleName = obj.optString("matchedRuleName", "-"),
                            webhookUrl = obj.optString("webhookUrl", "-"),
                            httpStatus = obj.optInt("httpStatus", 0),
                            responseBody = obj.optString("responseBody", ""),
                            errorMessage = obj.optString("errorMessage", ""),
                            latencyMs = obj.optLong("latencyMs", 0),
                            payloadSent = obj.optString("payloadSent", ""),
                            status = if (obj.optInt("httpStatus") in 200..299) "SUCCESS" else if (obj.optBoolean("matched")) "FAILED" else "SKIPPED",
                            isGroupSummary = false
                        )
                    }
                    Log.i(TAG, "Migrated legacy logs from SharedPreferences to SQLite.")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Migration error: ${e.message}")
        }
    }
}
