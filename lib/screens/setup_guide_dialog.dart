import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/native_bridge.dart';
import '../services/app_localizations.dart';

class SetupGuideDialog extends StatefulWidget {
  final VoidCallback? onDismissed;
  const SetupGuideDialog({super.key, this.onDismissed});

  static Future<void> showIfNeeded(BuildContext context, {bool force = false}) async {
    final bridge = NativeBridge();
    final perm = await bridge.checkNotificationPermission();
    final battery = await bridge.checkBatteryOptimization();

    // If permission or battery optimization is not configured, or force is requested, show dialog
    if (force || !perm || !battery) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const SetupGuideDialog(),
      );
    }
  }

  @override
  State<SetupGuideDialog> createState() => _SetupGuideDialogState();
}

class _SetupGuideDialogState extends State<SetupGuideDialog> with WidgetsBindingObserver {
  final NativeBridge _bridge = NativeBridge();
  bool _isPermissionGranted = false;
  bool _isBatteryIgnored = false;
  bool _areAppNotificationsEnabled = true;
  bool _isRebinding = false;
  String? _rebindMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check permissions automatically when returning from Settings screen
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final perm = await _bridge.checkNotificationPermission();
    final battery = await _bridge.checkBatteryOptimization();
    final notifEnabled = await _bridge.areAppNotificationsEnabled();
    if (mounted) {
      setState(() {
        _isPermissionGranted = perm;
        _isBatteryIgnored = battery;
        _areAppNotificationsEnabled = notifEnabled;
      });
    }
  }

  Future<void> _rebindListener() async {
    final i18n = I18n.of(context);
    setState(() {
      _isRebinding = true;
      _rebindMessage = null;
    });

    final success = await _bridge.rebindNotificationListener();
    await Future.delayed(const Duration(milliseconds: 600));
    await _checkStatus();

    if (mounted) {
      setState(() {
        _isRebinding = false;
        _rebindMessage = success ? i18n.rebindSuccessNotice : i18n.rebindFailedNotice;
      });
    }
  }

  void _exitApplication() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final isAllReady = _isPermissionGranted && _isBatteryIgnored;

    return PopScope(
      canPop: _isPermissionGranted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _exitApplication();
        }
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 720),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isAllReady ? Colors.teal.shade700 : Colors.deepOrange.shade800,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAllReady ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAllReady ? i18n.setupCompleteTitle : i18n.wizardTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAllReady
                                ? i18n.setupCompleteDesc
                                : i18n.wizardSubtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _isPermissionGranted ? i18n.btnContinue : i18n.btnExitApp,
                      icon: Icon(
                        _isPermissionGranted ? Icons.close : Icons.power_settings_new,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (!_isPermissionGranted) {
                          _exitApplication();
                        } else {
                          Navigator.pop(context);
                          widget.onDismissed?.call();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Scrollable Content Steps
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Mandatory Permission Warning Card
                    if (!_isPermissionGranted)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade300, width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, color: Colors.red.shade800, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    i18n.wizardMandatoryWarningTitle,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    i18n.wizardMandatoryWarningDesc,
                                    style: TextStyle(fontSize: 11, height: 1.35, color: Colors.red.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!_areAppNotificationsEnabled)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade300, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.notifications_off_rounded, size: 20, color: Colors.red.shade800),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    i18n.appNotifDisabledTitle,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              i18n.appNotifDisabledDesc,
                              style: TextStyle(fontSize: 11, height: 1.35, color: Colors.red.shade900),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade900,
                                  side: BorderSide(color: Colors.red.shade400),
                                ),
                                onPressed: () => _bridge.openAppNotificationSettings(),
                                icon: const Icon(Icons.settings, size: 15),
                                label: Text(i18n.btnOpenAppNotifSettings, style: const TextStyle(fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Step 1: Notification Access (Mandatory)
                    _buildStepCard(
                      stepNumber: '1',
                      title: i18n.notifAccessTitle,
                      isDone: _isPermissionGranted,
                      description: i18n.notifAccessStepDesc,
                      actionButton: FilledButton.icon(
                        onPressed: () async {
                          await _bridge.openNotificationSettings();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _isPermissionGranted ? Colors.teal : Colors.deepOrange.shade800,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(_isPermissionGranted ? i18n.checkSettingsAction : i18n.btnOpenSettings),
                      ),
                      extraContent: Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          border: Border.all(color: Colors.amber.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    i18n.restrictedSettingsHeader,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.brown),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              i18n.restrictedSettingsAndroidDesc,
                              style: const TextStyle(fontSize: 11, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Step 2: Battery Optimization
                    _buildStepCard(
                      stepNumber: '2',
                      title: i18n.batteryTitle,
                      isDone: _isBatteryIgnored,
                      description: i18n.batteryStepDesc,
                      actionButton: OutlinedButton.icon(
                        onPressed: () async {
                          await _bridge.requestIgnoreBatteryOptimization();
                        },
                        icon: const Icon(Icons.battery_saver, size: 16),
                        label: Text(_isBatteryIgnored ? i18n.statusUnrestricted : i18n.btnGrantBattery),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Step 3: Rebind Listener
                    _buildStepCard(
                      stepNumber: '3',
                      title: i18n.btnRebind,
                      isDone: _isPermissionGranted,
                      description: i18n.rebindStepDesc,
                      actionButton: OutlinedButton.icon(
                        onPressed: _isRebinding ? null : _rebindListener,
                        icon: _isRebinding
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.sync, size: 16),
                        label: Text(i18n.btnRebind),
                      ),
                      extraContent: _rebindMessage != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _rebindMessage!,
                                style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold),
                              ),
                            )
                          : null,
                    ),

                    const SizedBox(height: 14),

                    // App Lock Warning
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_person_outlined, size: 20, color: Colors.red.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i18n.appLockWarningTitle,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  i18n.appLockWarningDesc,
                                  style: TextStyle(fontSize: 11, height: 1.35, color: Colors.red.shade900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Step 4: Vendor specifics
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      expandedAlignment: Alignment.centerLeft,
                      title: Text(
                        i18n.vendorSettingTitle,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      children: [
                        _buildVendorRow('Xiaomi / Redmi / POCO (MIUI/HyperOS):', i18n.vendorXiaomiDesc),
                        _buildVendorRow('Samsung (OneUI):', i18n.vendorSamsungDesc),
                        _buildVendorRow('Oppo / Realme (ColorOS):', i18n.vendorOppoDesc),
                        _buildVendorRow('Vivo (FuntouchOS):', i18n.vendorVivoDesc),
                      ],
                    ),
                  ],
                ),
              ),

              // Footer Action Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _checkStatus,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(i18n.btnRefresh),
                    ),
                    const Spacer(),
                    if (!_isPermissionGranted)
                      FilledButton.icon(
                        onPressed: _exitApplication,
                        icon: const Icon(Icons.power_settings_new, size: 16),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
                        label: Text(i18n.btnExitApp),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDismissed?.call();
                        },
                        icon: const Icon(Icons.check, size: 16),
                        style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                        label: Text(i18n.btnContinue),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required bool isDone,
    required String description,
    required Widget actionButton,
    Widget? extraContent,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDone ? Colors.teal.shade300 : Colors.grey.shade300),
      ),
      color: isDone ? Colors.teal.shade50.withValues(alpha: 0.3) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isDone ? Colors.teal : Colors.deepOrange,
                  child: Text(
                    stepNumber,
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Icon(
                  isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isDone ? Colors.teal : Colors.grey,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 12, color: Colors.black87)),
            const SizedBox(height: 10),
            actionButton,
            ?extraContent,
          ],
        ),
      ),
    );
  }

  Widget _buildVendorRow(String vendor, String instructions) {
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(vendor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
          const SizedBox(height: 2),
          Text(instructions, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }
}
