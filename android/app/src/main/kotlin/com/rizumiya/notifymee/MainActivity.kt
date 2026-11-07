package com.rizumiya.notifymee

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.regex.Pattern

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rizumiya.notifymee/channel"
    private var methodChannel: MethodChannel? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        ensureGatewayServiceRunning()

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNotificationPermission" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "areAppNotificationsEnabled" -> {
                    val enabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
                    result.success(enabled)
                }
                "openAppNotificationSettings" -> {
                    try {
                        val intent = Intent().apply {
                            when {
                                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                                    action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                }
                                else -> {
                                    action = "android.settings.APP_NOTIFICATION_SETTINGS"
                                    putExtra("app_package", packageName)
                                    putExtra("app_uid", applicationInfo.uid)
                                }
                            }
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "addPackageBlacklist" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    val pattern = call.argument<String>("pattern") ?: ""
                    ioExecutor.execute {
                        val success = AppDatabase.getInstance(applicationContext).addBlacklist(pkg, pattern)
                        runOnUiThread { result.success(success) }
                    }
                }
                "deletePackageBlacklist" -> {
                    val id = call.argument<String>("id") ?: ""
                    ioExecutor.execute {
                        val success = AppDatabase.getInstance(applicationContext).deleteBlacklist(id)
                        runOnUiThread { result.success(success) }
                    }
                }
                "getPackageBlacklist" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    ioExecutor.execute {
                        val list = AppDatabase.getInstance(applicationContext).getBlacklistForPackage(pkg)
                        val arr = JSONArray()
                        for (item in list) {
                            arr.put(JSONObject(item))
                        }
                        val json = arr.toString()
                        runOnUiThread { result.success(json) }
                    }
                }
                "getAllBlacklist" -> {
                    ioExecutor.execute {
                        val list = AppDatabase.getInstance(applicationContext).getAllBlacklist()
                        val arr = JSONArray()
                        for (item in list) {
                            arr.put(JSONObject(item))
                        }
                        val json = arr.toString()
                        runOnUiThread { result.success(json) }
                    }
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "rebindNotificationListener" -> {
                    try {
                        NotificationService.triggerRebind(applicationContext, forceComponentToggle = true)
                        NotificationService.startForegroundService(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "processActiveNotifications" -> {
                    try {
                        val count = NotificationService.processActiveNotifications()
                        result.success(count)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "checkBatteryOptimization" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestIgnoreBatteryOptimization" -> {
                    result.success(requestIgnoreBatteryOptimizationsSafely())
                }
                "getRules" -> {
                    ioExecutor.execute {
                        val rulesJson = RuleStore.getRulesJson(applicationContext)
                        runOnUiThread { result.success(rulesJson) }
                    }
                }
                "saveRules" -> {
                    val rulesJson = call.argument<String>("rulesJson") ?: "[]"
                    ioExecutor.execute {
                        RuleStore.saveRulesJson(applicationContext, rulesJson)
                        runOnUiThread { result.success(true) }
                    }
                }
                "exportDatabaseJson" -> {
                    ioExecutor.execute {
                        val exportJson = AppDatabase.getInstance(applicationContext).exportFullConfigJson()
                        runOnUiThread { result.success(exportJson) }
                    }
                }
                "importDatabaseJson" -> {
                    val jsonStr = call.argument<String>("jsonStr") ?: "{}"
                    ioExecutor.execute {
                        val success = AppDatabase.getInstance(applicationContext).importFullConfigJson(jsonStr)
                        runOnUiThread { result.success(success) }
                    }
                }
                "getLogs" -> {
                    ioExecutor.execute {
                        val logsJson = NotificationLogStore.getLogsJson(applicationContext)
                        runOnUiThread { result.success(logsJson) }
                    }
                }
                "clearLogs" -> {
                    ioExecutor.execute {
                        NotificationLogStore.clearLogs(applicationContext)
                        runOnUiThread { result.success(true) }
                    }
                }
                "retryWebhookLog" -> {
                    val logId = call.argument<String>("logId") ?: ""
                    WebhookDispatcher.retryLogById(applicationContext, logId) { success, statusCode, message ->
                        result.success(
                            mapOf(
                                "success" to success,
                                "statusCode" to statusCode,
                                "message" to message
                            )
                        )
                    }
                }
                "retryAllFailedLogs" -> {
                    WebhookDispatcher.retryAllFailedLogs(applicationContext) { successCount, totalTried ->
                        result.success(
                            mapOf(
                                "successCount" to successCount,
                                "totalTried" to totalTried
                            )
                        )
                    }
                }
                "getInstalledApps" -> {
                    ioExecutor.execute {
                        val apps = getInstalledAppList()
                        runOnUiThread { result.success(apps) }
                    }
                }
                "simulateNotification" -> {
                    val pkg = call.argument<String>("packageName") ?: "org.telegram.messenger"
                    val title = call.argument<String>("title") ?: "Pesan Baru"
                    val text = call.argument<String>("text") ?: "Halo, ini notifikasi uji coba gateway."
                    ioExecutor.execute {
                        simulateNotificationProcessing(pkg, title, text)
                        runOnUiThread { result.success(true) }
                    }
                }
                "testWebhook" -> {
                    val ruleJsonStr = call.argument<String>("ruleJson") ?: ""
                    val title = call.argument<String>("title") ?: "Test Notifikasi"
                    val text = call.argument<String>("text") ?: "Halo, ini pesan uji coba endpoint webhook."

                    try {
                        val ruleObj = JSONObject(ruleJsonStr)
                        val rule = WebhookRule.fromJson(ruleObj)

                        val groups = mutableListOf<String>()
                        val namedGroups = mutableMapOf<String, String>()
                        if (rule.regexPattern.isNotBlank()) {
                            val flags = if (rule.regexIgnoreCase) Pattern.CASE_INSENSITIVE or Pattern.MULTILINE else Pattern.MULTILINE
                            val p = Pattern.compile(rule.regexPattern, flags)
                            val m = p.matcher("$title $text")
                            if (m.find()) {
                                for (i in 1..m.groupCount()) {
                                    groups.add(m.group(i) ?: "")
                                }
                                val nameMatcher = Pattern.compile("\\(\\?<([a-zA-Z][a-zA-Z0-9]*)>").matcher(rule.regexPattern)
                                while (nameMatcher.find()) {
                                    val gName = nameMatcher.group(1) ?: continue
                                    try {
                                        val gVal = m.group(gName)
                                        if (gVal != null) namedGroups[gName] = gVal
                                    } catch (_: Exception) {}
                                }
                            }
                        }

                        val targetPkg = rule.packageName.ifBlank { "com.example.app" }
                        val appLabel = getAppLabel(targetPkg)

                        WebhookDispatcher.dispatch(
                            context = applicationContext,
                            rule = rule,
                            packageName = targetPkg,
                            appName = appLabel,
                            title = title,
                            text = text,
                            bigText = text,
                            subText = "",
                            fullContent = "$title $text",
                            timestamp = System.currentTimeMillis(),
                            regexMatches = groups,
                            namedRegexMatches = namedGroups
                        ) { success, code, msg ->
                            result.success(
                                mapOf(
                                    "success" to success,
                                    "statusCode" to code,
                                    "message" to msg
                                )
                            )
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        WebhookDispatcher.onLogUpdated = {
            runOnUiThread {
                methodChannel?.invokeMethod("onNewLogEvent", null)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        ensureGatewayServiceRunning()
    }

    override fun onDestroy() {
        if (WebhookDispatcher.onLogUpdated != null) {
            WebhookDispatcher.onLogUpdated = null
        }
        super.onDestroy()
    }

    private fun ensureGatewayServiceRunning() {
        if (isNotificationServiceEnabled()) {
            NotificationService.startForegroundService(applicationContext)
            if (!NotificationService.isServiceRunning) {
                NotificationService.requestSafeRebind(applicationContext)
            }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(this)
        return enabledPackages.contains(packageName)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizationsSafely(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (isIgnoringBatteryOptimizations()) return true

        return try {
            val directIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(directIntent)
            true
        } catch (e: Exception) {
            try {
                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallbackIntent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun getInstalledAppList(): List<Map<String, Any>> {
        val pm = packageManager
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val list = mutableListOf<Map<String, Any>>()

        for (appInfo in packages) {
            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val appName = pm.getApplicationLabel(appInfo).toString()
            val pkg = appInfo.packageName

            if (pkg == packageName) continue

            list.add(
                mapOf(
                    "appName" to appName,
                    "packageName" to pkg,
                    "isSystem" to isSystem
                )
            )
        }

        list.sortWith(compareBy({ it["isSystem"] as Boolean }, { (it["appName"] as String).lowercase() }))
        return list
    }

    private fun getAppLabel(pkg: String): String {
        return try {
            val info = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            pkg
        }
    }

    private fun simulateNotificationProcessing(pkg: String, title: String, text: String) {
        val appName = getAppLabel(pkg)
        val fullContent = "$title $text".trim()
        val timestamp = System.currentTimeMillis()
        val rules = RuleStore.getRules(applicationContext)
        var anyMatched = false

        for (rule in rules) {
            if (!rule.enabled) continue

            val rulePkg = rule.packageName.trim()
            val targets = rulePkg.split(",", ";").map { it.trim().lowercase() }.filter { it.isNotEmpty() }
            val pkgLower = pkg.lowercase()
            val appLower = appName.lowercase()

            val pkgMatch = rulePkg.isBlank() || rulePkg == "*" ||
                targets.any { it == pkgLower || pkgLower.contains(it) || it == appLower || appLower.contains(it) }

            if (!pkgMatch) continue

            val regex = rule.regexPattern.trim()
            if (regex.isNotBlank()) {
                val flags = if (rule.regexIgnoreCase) Pattern.CASE_INSENSITIVE or Pattern.MULTILINE else Pattern.MULTILINE
                try {
                    val pattern = Pattern.compile(regex, flags)
                    val matcher = pattern.matcher(fullContent)
                    if (matcher.find()) {
                        anyMatched = true
                        val groups = mutableListOf<String>()
                        for (i in 1..matcher.groupCount()) {
                            groups.add(matcher.group(i) ?: "")
                        }
                        val namedGroups = mutableMapOf<String, String>()
                        val nameMatcher = Pattern.compile("\\(\\?<([a-zA-Z][a-zA-Z0-9]*)>").matcher(regex)
                        while (nameMatcher.find()) {
                            val gName = nameMatcher.group(1) ?: continue
                            try {
                                val gVal = matcher.group(gName)
                                if (gVal != null) namedGroups[gName] = gVal
                            } catch (_: Exception) {}
                        }
                        WebhookDispatcher.dispatch(
                            context = applicationContext,
                            rule = rule,
                            packageName = pkg,
                            appName = appName,
                            title = title,
                            text = text,
                            bigText = text,
                            subText = "",
                            fullContent = fullContent,
                            timestamp = timestamp,
                            regexMatches = groups,
                            namedRegexMatches = namedGroups
                        )
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            } else {
                anyMatched = true
                WebhookDispatcher.dispatch(
                    context = applicationContext,
                    rule = rule,
                    packageName = pkg,
                    appName = appName,
                    title = title,
                    text = text,
                    bigText = text,
                    subText = "",
                    fullContent = fullContent,
                    timestamp = timestamp,
                    regexMatches = emptyList()
                )
            }
        }

        if (!anyMatched) {
            val unhandledLog = NotificationLogStore.createLogEntry(
                packageName = pkg,
                title = title,
                text = text,
                matched = false,
                matchedRuleName = "-",
                webhookUrl = "-",
                httpStatus = 0,
                responseBody = "",
                errorMessage = "Dilewati: Tidak ada aturan filter yang cocok",
                latencyMs = 0,
                payloadSent = ""
            )
            NotificationLogStore.addLog(applicationContext, unhandledLog, status = "SKIPPED")
            WebhookDispatcher.onLogUpdated?.invoke()
        }
    }
}
