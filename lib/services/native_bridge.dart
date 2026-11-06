import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/webhook_rule.dart';
import '../models/notification_log.dart';

class InstalledApp {
  final String appName;
  final String packageName;
  final bool isSystem;

  InstalledApp({
    required this.appName,
    required this.packageName,
    required this.isSystem,
  });

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) {
    return InstalledApp(
      appName: map['appName']?.toString() ?? '',
      packageName: map['packageName']?.toString() ?? '',
      isSystem: map['isSystem'] as bool? ?? false,
    );
  }
}

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.rizumiya.notifymee/channel');

  static final NativeBridge _instance = NativeBridge._internal();
  factory NativeBridge() => _instance;

  NativeBridge._internal() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final List<VoidCallback> _logListeners = [];

  void addLogListener(VoidCallback listener) {
    _logListeners.add(listener);
  }

  void removeLogListener(VoidCallback listener) {
    _logListeners.remove(listener);
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onNewLogEvent') {
      for (final listener in List.from(_logListeners)) {
        try {
          listener();
        } catch (e) {
          debugPrint('Error in log listener: $e');
        }
      }
    }
  }

  bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  Future<bool> checkNotificationPermission() async {
    if (!isAndroid) return false;
    try {
      final bool granted = await _channel.invokeMethod('checkNotificationPermission') ?? false;
      return granted;
    } catch (e) {
      debugPrint('checkNotificationPermission error: $e');
      return false;
    }
  }

  Future<bool> areAppNotificationsEnabled() async {
    if (!isAndroid) return true;
    try {
      final bool enabled = await _channel.invokeMethod('areAppNotificationsEnabled') ?? true;
      return enabled;
    } catch (e) {
      debugPrint('areAppNotificationsEnabled error: $e');
      return true;
    }
  }

  Future<bool> openAppNotificationSettings() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod('openAppNotificationSettings') ?? false;
    } catch (e) {
      debugPrint('openAppNotificationSettings error: $e');
      return false;
    }
  }

  Future<bool> addPackageBlacklist(String packageName, String pattern) async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod('addPackageBlacklist', {
        'packageName': packageName,
        'pattern': pattern,
      }) ?? false;
    } catch (e) {
      debugPrint('addPackageBlacklist error: $e');
      return false;
    }
  }

  Future<bool> deletePackageBlacklist(String id) async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod('deletePackageBlacklist', {'id': id}) ?? false;
    } catch (e) {
      debugPrint('deletePackageBlacklist error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPackageBlacklist(String packageName) async {
    if (!isAndroid) return [];
    try {
      final String? jsonStr = await _channel.invokeMethod('getPackageBlacklist', {'packageName': packageName});
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('getPackageBlacklist error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllBlacklist() async {
    if (!isAndroid) return [];
    try {
      final String? jsonStr = await _channel.invokeMethod('getAllBlacklist');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('getAllBlacklist error: $e');
      return [];
    }
  }

  Future<bool> openNotificationSettings() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod('openNotificationSettings') ?? false;
    } catch (e) {
      debugPrint('openNotificationSettings error: $e');
      return false;
    }
  }

  Future<bool> rebindNotificationListener() async {
    if (!isAndroid) return true;
    try {
      return await _channel.invokeMethod('rebindNotificationListener') ?? false;
    } catch (e) {
      debugPrint('rebindNotificationListener error: $e');
      return false;
    }
  }

  Future<int> processActiveNotifications() async {
    if (!isAndroid) return 0;
    try {
      final int count = await _channel.invokeMethod('processActiveNotifications') ?? 0;
      return count;
    } catch (e) {
      debugPrint('processActiveNotifications error: $e');
      return 0;
    }
  }

  Future<bool> checkBatteryOptimization() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod('checkBatteryOptimization') ?? false;
    } catch (e) {
      debugPrint('checkBatteryOptimization error: $e');
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimization() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod('requestIgnoreBatteryOptimization') ?? false;
    } catch (e) {
      debugPrint('requestIgnoreBatteryOptimization error: $e');
      return false;
    }
  }

  Future<List<WebhookRule>> getRules() async {
    if (!isAndroid) {
      // Fallback in-memory defaults for iOS / Web / Desktop preview
      return _fallbackRules;
    }
    try {
      final String? jsonStr = await _channel.invokeMethod('getRules');
      if (jsonStr == null || jsonStr.isEmpty) return _fallbackRules;
      final List decoded = jsonDecode(jsonStr);
      return decoded.map((e) => WebhookRule.fromJson(e)).toList();
    } catch (e) {
      debugPrint('getRules error: $e');
      return _fallbackRules;
    }
  }

  Future<bool> saveRules(List<WebhookRule> rules) async {
    final jsonStr = jsonEncode(rules.map((r) => r.toJson()).toList());
    if (!isAndroid) {
      _fallbackRules = rules;
      return true;
    }
    try {
      return await _channel.invokeMethod('saveRules', {'rulesJson': jsonStr}) ?? false;
    } catch (e) {
      debugPrint('saveRules error: $e');
      return false;
    }
  }

  Future<String> exportDatabaseJson() async {
    if (!isAndroid) {
      return jsonEncode({
        'version': 1,
        'exportedAt': DateTime.now().millisecondsSinceEpoch,
        'rules': _fallbackRules.map((r) => r.toJson()).toList(),
      });
    }
    try {
      final String? jsonStr = await _channel.invokeMethod('exportDatabaseJson');
      return jsonStr ?? '{}';
    } catch (e) {
      debugPrint('exportDatabaseJson error: $e');
      return '{}';
    }
  }

  Future<bool> importDatabaseJson(String jsonStr) async {
    if (!isAndroid) {
      try {
        final decoded = jsonDecode(jsonStr);
        final list = (decoded['rules'] ?? decoded) as List;
        _fallbackRules = list.map((e) => WebhookRule.fromJson(e)).toList();
        return true;
      } catch (e) {
        return false;
      }
    }
    try {
      return await _channel.invokeMethod('importDatabaseJson', {'jsonStr': jsonStr}) ?? false;
    } catch (e) {
      debugPrint('importDatabaseJson error: $e');
      return false;
    }
  }

  Future<List<NotificationLog>> getLogs() async {
    if (!isAndroid) {
      return _fallbackLogs;
    }
    try {
      final String? jsonStr = await _channel.invokeMethod('getLogs');
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List decoded = jsonDecode(jsonStr);
      return decoded.map((e) => NotificationLog.fromJson(e)).toList();
    } catch (e) {
      debugPrint('getLogs error: $e');
      return [];
    }
  }

  Future<bool> clearLogs() async {
    if (!isAndroid) {
      _fallbackLogs.clear();
      return true;
    }
    try {
      return await _channel.invokeMethod('clearLogs') ?? false;
    } catch (e) {
      debugPrint('clearLogs error: $e');
      return false;
    }
  }

  Future<List<InstalledApp>> getInstalledApps() async {
    if (!isAndroid) {
      return [
        InstalledApp(appName: 'GoPay / Gojek', packageName: 'com.gojek.app', isSystem: false),
        InstalledApp(appName: 'GoBiz Merchant Kasir', packageName: 'com.gojek.gobiz', isSystem: false),
        InstalledApp(appName: 'GoPay Standalone', packageName: 'com.gojek.gopay', isSystem: false),
        InstalledApp(appName: 'DANA Dompet Digital', packageName: 'id.dana', isSystem: false),
        InstalledApp(appName: 'OVO', packageName: 'ovo.id', isSystem: false),
        InstalledApp(appName: 'Google Messages (SMS)', packageName: 'com.google.android.apps.messaging', isSystem: false),
        InstalledApp(appName: 'BCA Mobile', packageName: 'com.bca', isSystem: false),
        InstalledApp(appName: 'Livin\' by Mandiri', packageName: 'id.bmri.livin', isSystem: false),
        InstalledApp(appName: 'BRImo BRI', packageName: 'id.co.bri.brimo', isSystem: false),
      ];
    }
    try {
      final List? list = await _channel.invokeMethod('getInstalledApps');
      if (list == null) return [];
      return list.map((e) => InstalledApp.fromMap(e as Map)).toList();
    } catch (e) {
      debugPrint('getInstalledApps error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> testWebhook({
    required WebhookRule rule,
    required String sampleTitle,
    required String sampleText,
  }) async {
    final ruleJson = jsonEncode(rule.toJson());
    if (!isAndroid) {
      return {
        'success': true,
        'statusCode': 200,
        'message': 'Simulasi Webhook Sukses (Non-Android Preview)'
      };
    }
    try {
      final res = await _channel.invokeMethod('testWebhook', {
        'ruleJson': ruleJson,
        'title': sampleTitle,
        'text': sampleText,
      });
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {
        'success': false,
        'statusCode': 0,
        'message': e.toString(),
      };
    }
  }

  Future<bool> simulateNotification({
    required String packageName,
    required String title,
    required String text,
  }) async {
    if (!isAndroid) {
      _fallbackLogs.insert(
        0,
        NotificationLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now().millisecondsSinceEpoch,
          datetime: DateTime.now().toIso8601String(),
          packageName: packageName,
          title: title,
          text: text,
          matched: true,
          matchedRuleName: 'Simulasi GoPay QRIS',
          webhookUrl: 'https://webhook.site/test',
          httpStatus: 200,
          responseBody: '{"status":"ok","received":true}',
          errorMessage: '',
          latencyMs: 120,
          payloadSent: '{\n  "event": "notification_received",\n  "title": "$title",\n  "text": "$text"\n}',
        ),
      );
      for (final l in _logListeners) {
        l();
      }
      return true;
    }
    try {
      return await _channel.invokeMethod('simulateNotification', {
        'packageName': packageName,
        'title': title,
        'text': text,
      }) ?? false;
    } catch (e) {
      debugPrint('simulateNotification error: $e');
      return false;
    }
  }

  // Fallback defaults for previewing UI
  List<WebhookRule> _fallbackRules = [
    WebhookRule(
      id: 'rule_default_all',
      name: 'Aturan Gateway Notifikasi',
      enabled: true,
      packageName: '*',
      regexPattern: '',
      webhookUrl: 'https://your-domain.com/webhook/endpoint',
      httpMethod: 'POST',
      headers: {'Content-Type': 'application/json', 'X-Webhook-Source': 'Notifymee-Gateway'},
      sendOnlyIfMatched: false,
      ignoreGroupSummary: true,
      deduplicateMessages: true,
    ),
  ];

  final List<NotificationLog> _fallbackLogs = [];
}

