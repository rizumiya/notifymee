import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/webhook_rule.dart';
import '../models/notification_log.dart';
import '../services/native_bridge.dart';
import '../services/app_localizations.dart';
import 'setup_guide_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;
  const DashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final NativeBridge _bridge = NativeBridge();

  bool _isPermissionGranted = false;
  bool _isBatteryIgnored = false;
  bool _areAppNotificationsEnabled = true;
  bool _isLoading = true;
  bool _hasCheckedInitialSetup = false;
  List<WebhookRule> _rules = [];
  List<NotificationLog> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAll();
    _bridge.addLogListener(_onLogUpdated);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptSetupGuide();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bridge.removeLogListener(_onLogUpdated);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  void _onLogUpdated() {
    if (mounted) {
      _loadLogs();
    }
  }

  Future<void> _checkAndPromptSetupGuide() async {
    if (_hasCheckedInitialSetup || !mounted) return;
    _hasCheckedInitialSetup = true;

    final isPermGranted = await _bridge.checkNotificationPermission();
    if (!isPermGranted && mounted) {
      SetupGuideDialog.showIfNeeded(context, force: true);
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _checkPermissions(),
      _loadRules(),
      _loadLogs(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPermissions() async {
    final perm = await _bridge.checkNotificationPermission();
    final batt = await _bridge.checkBatteryOptimization();
    final notifEnabled = await _bridge.areAppNotificationsEnabled();
    if (mounted) {
      setState(() {
        _isPermissionGranted = perm;
        _isBatteryIgnored = batt;
        _areAppNotificationsEnabled = notifEnabled;
      });
    }
  }

  Future<void> _loadRules() async {
    final rules = await _bridge.getRules();
    if (mounted) {
      setState(() => _rules = rules);
    }
  }

  Future<void> _loadLogs() async {
    final logs = await _bridge.getLogs();
    if (mounted) {
      setState(() => _logs = logs);
    }
  }

  Future<void> _toggleRule(WebhookRule rule, bool val) async {
    final updated = _rules.map((r) => r.id == rule.id ? r.copyWith(enabled: val) : r).toList();
    setState(() => _rules = updated);
    await _bridge.saveRules(updated);
  }

  Future<void> _rebindListener() async {
    final i18n = I18n.of(context);
    final success = await _bridge.rebindNotificationListener();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? i18n.rebindSuccess : i18n.rebindFailed),
          backgroundColor: success ? Colors.teal : Colors.red,
        ),
      );
    }
  }

  Future<void> _runQuickSimulation(String pkg, String title, String text) async {
    final i18n = I18n.of(context);
    final success = await _bridge.simulateNotification(
      packageName: pkg,
      title: title,
      text: text,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal,
            content: Text(i18n.simSuccess),
          ),
        );
        _loadLogs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(i18n.simFailed),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final totalLogs = _logs.length;
    final successCount = _logs.where((l) => l.isSuccess).length;
    final failedCount = _logs.where((l) => l.isFailed).length;
    final activeRulesCount = _rules.where((r) => r.enabled).length;
    final isConfigured = _isPermissionGranted && _isBatteryIgnored;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Prominent Warning Banner if App Notifications are turned off in Android settings
                if (!_areAppNotificationsEnabled)
                  Card(
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.red.shade400, width: 1.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notifications_off_rounded, color: Colors.red.shade800, size: 26),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  i18n.appNotifDisabledTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            i18n.appNotifDisabledDesc,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber.shade900),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    i18n.appNotifDisabledTip,
                                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                await _bridge.openAppNotificationSettings();
                                _checkPermissions();
                              },
                              icon: const Icon(Icons.settings, size: 18),
                              label: Text(i18n.btnOpenAppNotifSettings),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (!_areAppNotificationsEnabled) const SizedBox(height: 14),

                // Prominent Warning Banner if settings are not complete
                if (!isConfigured)
                  Card(
                    color: Colors.deepOrange.shade50,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.deepOrange.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.deepOrange.shade800, size: 26),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  i18n.gatewayStatusInactive,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.deepOrange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            i18n.gatewayInactiveDesc,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => SetupGuideDialog.showIfNeeded(context, force: true),
                              icon: const Icon(Icons.settings_suggest, size: 18),
                              label: Text(i18n.btnSetupGuide),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.deepOrange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (!isConfigured) const SizedBox(height: 14),

                // Main Service Status Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: isConfigured
                            ? [Colors.teal.shade700, Colors.teal.shade900]
                            : [Colors.orange.shade700, Colors.deepOrange.shade900],
                      ),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isConfigured ? Icons.check_circle : Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isConfigured ? i18n.gatewayStatusActive : i18n.gatewayStatusInactive,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isConfigured ? i18n.gatewayActiveDesc : i18n.gatewayInactiveDesc,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => SetupGuideDialog.showIfNeeded(context, force: true),
                              icon: const Icon(Icons.menu_book, size: 18),
                              label: Text(i18n.btnSetupGuide),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.teal.shade900,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: i18n.btnRebind,
                              icon: const Icon(Icons.sync, color: Colors.white),
                              onPressed: _rebindListener,
                            ),
                            IconButton(
                              tooltip: i18n.btnRefresh,
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              onPressed: _refreshAll,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Statistics Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: i18n.statReceived,
                        value: totalLogs.toString(),
                        icon: Icons.notifications_active_outlined,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        title: i18n.statDispatched,
                        value: successCount.toString(),
                        icon: Icons.check_circle_outline,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        title: i18n.statFailed,
                        value: failedCount.toString(),
                        icon: Icons.error_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        title: i18n.statTotalRules,
                        value: '$activeRulesCount/${_rules.length}',
                        icon: Icons.filter_alt_outlined,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Quick Simulation Card (Only in Debug Mode, removed in Production)
                if (kDebugMode) ...[
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flash_on, color: Colors.amber),
                              const SizedBox(width: 8),
                              Text(
                                i18n.quickSimTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => widget.onNavigateTab(2),
                                icon: const Icon(Icons.tune, size: 16),
                                label: Text(i18n.customAction),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            i18n.quickSimDesc,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.blue),
                                label: Text(i18n.simChatTitle),
                                onPressed: () => _runQuickSimulation(
                                  'com.example.chat',
                                  'Sample Sender',
                                  'Hello, this is a simulated gateway notification.',
                                ),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.sms_outlined, size: 16, color: Colors.deepPurple),
                                label: Text(i18n.simOtpTitle),
                                onPressed: () => _runQuickSimulation(
                                  'com.example.sms',
                                  'Security Code',
                                  'Your verification code is 829103.',
                                ),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.warning_amber_outlined, size: 16, color: Colors.red),
                                label: Text(i18n.simAlertTitle),
                                onPressed: () => _runQuickSimulation(
                                  'com.example.monitor',
                                  'Server Alert 01',
                                  'CRITICAL: Host connection restored.',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Active Rules List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      i18n.rulesTitle,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigateTab(1),
                      child: Text(i18n.btnManageAll),
                    ),
                  ],
                ),

                if (_rules.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(i18n.noRulesYet),
                      ),
                    ),
                  )
                else
                  ..._rules.map((rule) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: rule.enabled ? Colors.teal.shade100 : Colors.grey.shade200,
                          child: Icon(
                            Icons.webhook,
                            color: rule.enabled ? Colors.teal.shade900 : Colors.grey,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          rule.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: rule.enabled ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          rule.webhookUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Switch(
                          value: rule.enabled,
                          activeThumbColor: Colors.teal.shade700,
                          onChanged: (val) => _toggleRule(rule, val),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 16),

                // Recent Activity Preview
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      i18n.recentActivity,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigateTab(2),
                      child: Text(i18n.btnViewAll),
                    ),
                  ],
                ),

                if (_logs.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          i18n.noLogsYet,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  ..._logs.take(3).map((log) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          log.isSuccess
                              ? Icons.check_circle
                              : log.isFailed
                                  ? Icons.error
                                  : Icons.remove_circle_outline,
                          color: log.isSuccess
                              ? Colors.teal
                              : log.isFailed
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                        title: Text(
                          log.title.isNotEmpty ? log.title : log.packageName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          log.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          log.isSuccess
                              ? '${log.httpStatus} (${log.latencyMs}ms)'
                              : log.isFailed
                                  ? i18n.statFailed
                                  : i18n.filterSkipped,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: log.isSuccess ? Colors.teal : Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
