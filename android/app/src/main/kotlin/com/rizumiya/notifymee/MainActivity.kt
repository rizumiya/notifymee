package com.rizumiya.notifymee

import android.content.ComponentName
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
import org.json.JSONObject
import java.util.regex.Pattern

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rizumiya.notifymee/channel"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (isNotificationServiceEnabled()) {
            NotificationService.startForegroundService(this)
            if (!NotificationService.isServiceRunning) {
                NotificationService.triggerRebind(this)
            }
        }

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
                    val success = AppDatabase.getInstance(this).addBlacklist(pkg, pattern)
                    result.success(success)
                }
                "deletePackageBlacklist" -> {
                    val id = call.argument<String>("id") ?: ""
                    val success = AppDatabase.getInstance(this).deleteBlacklist(id)
                    result.success(success)
                }
                "getPackageBlacklist" -> {
                    val pkg = call.argument<String>("packageName") ?: ""
                    val list = AppDatabase.getInstance(this).getBlacklistForPackage(pkg)
                    val arr = org.json.JSONArray()
                    for (item in list) {
                        arr.put(org.json.JSONObject(item))
                    }
                    result.success(arr.toString())
                }
                "getAllBlacklist" -> {
                    val list = AppDatabase.getInstance(this).getAllBlacklist()
                    val arr = org.json.JSONArray()
                    for (item in list) {
                        arr.put(org.json.JSONObject(item))
                    }
                    result.success(arr.toString())
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "rebindNotificationListener" -> {
                    try {
                        val component = ComponentName(this, NotificationService::class.java)
                        packageManager.setComponentEnabledSetting(
                            component,
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                        packageManager.setComponentEnabledSetting(
                            component,
                            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                            PackageManager.DONT_KILL_APP
                        )
                        NotificationService.triggerRebind(this)
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
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isIgnoring = pm.isIgnoringBatteryOptimizations(packageName)
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimization" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getRules" -> {
                    val rulesJson = RuleStore.getRulesJson(this)
                    result.success(rulesJson)
                }
                "saveRules" -> {
                    val rulesJson = call.argument<String>("rulesJson") ?: "[]"
                    RuleStore.saveRulesJson(this, rulesJson)
                    result.success(true)
                }
                "exportDatabaseJson" -> {
                    val exportJson = AppDatabase.getInstance(this).exportFullConfigJson()
                    result.success(exportJson)
                }
                "importDatabaseJson" -> {
                    val jsonStr = call.argument<String>("jsonStr") ?: "{}"
                    val success = AppDatabase.getInstance(this).importFullConfigJson(jsonStr)
                    result.success(success)
                }
                "getLogs" -> {
                    val logsJson = NotificationLogStore.getLogsJson(this)
                    result.success(logsJson)
                }
                "clearLogs" -> {
                    NotificationLogStore.clearLogs(this)
                    result.success(true)
                }
                "getInstalledApps" -> {
                    val apps = getInstalledAppList()
                    result.success(apps)
                }
                "simulateNotification" -> {
                    val pkg = call.argument<String>("packageName") ?: "org.telegram.messenger"
                    val title = call.argument<String>("title") ?: "Pesan Baru"
                    val text = call.argument<String>("text") ?: "Halo, ini notifikasi uji coba gateway."
                    simulateNotificationProcessing(pkg, title, text)
                    result.success(true)
                }
                "testWebhook" -> {
                    val ruleJsonStr = call.argument<String>("ruleJson") ?: ""
                    val title = call.argument<String>("title") ?: "Test Notifikasi"
                    val text = call.argument<String>("text") ?: "Halo, ini pesan uji coba endpoint webhook."
                    
                    try {
                        val ruleObj = JSONObject(ruleJsonStr)
                        val rule = WebhookRule.fromJson(ruleObj)
                        
                        val groups = mutableListOf<String>()
                        if (rule.regexPattern.isNotBlank()) {
                            val flags = if (rule.regexIgnoreCase) Pattern.CASE_INSENSITIVE or Pattern.MULTILINE else Pattern.MULTILINE
                            val p = Pattern.compile(rule.regexPattern, flags)
                            val m = p.matcher("$title $text")
                            if (m.find()) {
                                for (i in 1..m.groupCount()) {
                                    groups.add(m.group(i) ?: "")
                                }
                            }
                        }

                        val targetPkg = rule.packageName.ifBlank { "com.example.app" }
                        val appLabel = getAppLabel(targetPkg)

                        WebhookDispatcher.dispatch(
                            context = this,
                            rule = rule,
                            packageName = targetPkg,
                            appName = appLabel,
                            title = title,
                            text = text,
                            bigText = text,
                            subText = "",
                            fullContent = "$title $text",
                            timestamp = System.currentTimeMillis(),
                            regexMatches = groups
                        ) { success, code, msg ->
                            val res = mapOf(
                                "success" to success,
                                "statusCode" to code,
                                "message" to msg
                            )
                            result.success(res)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Live notification update listener to notify Flutter UI immediately
        WebhookDispatcher.onLogUpdated = {
            runOnUiThread {
                methodChannel?.invokeMethod("onNewLogEvent", null)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (isNotificationServiceEnabled()) {
            NotificationService.startForegroundService(this)
            if (!NotificationService.isServiceRunning) {
                NotificationService.triggerRebind(this)
            }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(this)
        return enabledPackages.contains(packageName)
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

            list.add(mapOf(
                "appName" to appName,
                "packageName" to pkg,
                "isSystem" to isSystem
            ))
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
        val rules = RuleStore.getRules(this)
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
                        WebhookDispatcher.dispatch(
                            context = this,
                            rule = rule,
                            packageName = pkg,
                            appName = appName,
                            title = title,
                            text = text,
                            bigText = text,
                            subText = "",
                            fullContent = fullContent,
                            timestamp = timestamp,
                            regexMatches = groups
                        )
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            } else {
                anyMatched = true
                WebhookDispatcher.dispatch(
                    context = this,
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
            NotificationLogStore.addLog(this, unhandledLog)
            WebhookDispatcher.onLogUpdated?.invoke()
        }
    }
}
