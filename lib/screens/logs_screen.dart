import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/notification_log.dart';
import '../services/app_localizations.dart';
import '../services/native_bridge.dart';
import 'blacklist_manager_sheet.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final NativeBridge _bridge = NativeBridge();
  List<NotificationLog> _logs = [];
  bool _isLoading = true;
  bool _isBatchRetrying = false;
  String _filter = 'ALL'; // ALL, SUCCESS, FAILED, SKIPPED
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _bridge.addLogListener(_onLogUpdated);
  }

  @override
  void dispose() {
    _bridge.removeLogListener(_onLogUpdated);
    super.dispose();
  }

  void _onLogUpdated() {
    if (mounted) {
      _loadLogs();
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _bridge.getLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _retryAllFailed() async {
    final i18n = I18n.of(context);
    setState(() => _isBatchRetrying = true);
    final stats = await _bridge.retryAllFailedLogs();
    await _loadLogs();
    if (mounted) {
      setState(() => _isBatchRetrying = false);
      final ok = stats['successCount'] ?? 0;
      final total = stats['totalTried'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok > 0 ? Colors.teal.shade800 : Colors.orange.shade800,
          content: Text(
            i18n.isId
                ? 'Kirim ulang selesai: $ok/$total log gagal berhasil terkirim!'
                : 'Batch retry finished: $ok/$total failed logs succeeded!',
          ),
        ),
      );
    }
  }

  Future<void> _clearLogs() async {
    final i18n = I18n.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.btnClearLogs),
        content: Text(i18n.clearLogsConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(i18n.btnCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(i18n.btnDelete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _bridge.clearLogs();
      _loadLogs();
    }
  }

  void _showLogDetail(NotificationLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LogDetailSheet(log: log, onRefreshLogs: _loadLogs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final failedCount = _logs.where((l) => l.isFailed).length;

    final filtered = _logs.where((l) {
      if (_filter == 'SUCCESS' && !l.isSuccess) return false;
      if (_filter == 'FAILED' && !l.isFailed) return false;
      if (_filter == 'SKIPPED' && !l.isSkipped) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = l.title.toLowerCase().contains(q) ||
            l.text.toLowerCase().contains(q) ||
            l.packageName.toLowerCase().contains(q) ||
            l.matchedRuleName.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.logsTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (failedCount > 0)
            IconButton(
              tooltip: i18n.isId ? 'Kirim Ulang Semua Log Gagal ($failedCount)' : 'Retry All Failed Logs ($failedCount)',
              icon: _isBatchRetrying
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.replay_circle_filled, color: Colors.teal),
              onPressed: _isBatchRetrying ? null : _retryAllFailed,
            ),
          IconButton(
            tooltip: i18n.btnManageBlacklist,
            icon: const Icon(Icons.block_outlined, color: Colors.deepOrange),
            onPressed: () => BlacklistManagerSheet.show(context),
          ),
          IconButton(
            tooltip: i18n.btnRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          IconButton(
            tooltip: i18n.btnClearLogs,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _logs.isEmpty ? null : _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: i18n.searchLogsHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('${i18n.filterAll} (${_logs.length})', 'ALL'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  '${i18n.filterSuccess} (${_logs.where((l) => l.isSuccess).length})',
                  'SUCCESS',
                  color: Colors.teal,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  '${i18n.filterFailed} ($failedCount)',
                  'FAILED',
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  '${i18n.filterSkipped} (${_logs.where((l) => l.isSkipped).length})',
                  'SKIPPED',
                  color: Colors.grey,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Log List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty ? i18n.noLogsYet : i18n.noMatchingLogs,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final log = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showLogDetail(log),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStatusIcon(log),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  log.title.isNotEmpty ? log.title : log.packageName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                _formatTime(log.datetime),
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            log.text,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  log.matchedRuleName.isNotEmpty && log.matchedRuleName != '-'
                                                      ? log.matchedRuleName
                                                      : log.packageName,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              _buildStatusBadge(log, i18n),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(NotificationLog log, I18n i18n) {
    if (log.isSuccess) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.teal.shade300),
        ),
        child: Text(
          '${i18n.statusProcessed} (HTTP ${log.httpStatus})',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
        ),
      );
    } else if (log.isFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Text(
          log.httpStatus > 0 ? '${i18n.statusFailedBadge} (${log.httpStatus})' : i18n.statusFailedBadge,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          i18n.statusSkippedBadge,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      );
    }
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: (color ?? Colors.teal).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? (color ?? Colors.teal.shade900) : Colors.black87,
      ),
    );
  }

  Widget _buildStatusIcon(NotificationLog log) {
    if (log.isSuccess) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 18, color: Colors.teal),
      );
    } else if (log.isFailed) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
        child: const Icon(Icons.priority_high, size: 18, color: Colors.red),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
        child: const Icon(Icons.filter_list_off, size: 18, color: Colors.grey),
      );
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}

class LogDetailSheet extends StatefulWidget {
  final NotificationLog log;
  final VoidCallback onRefreshLogs;

  const LogDetailSheet({super.key, required this.log, required this.onRefreshLogs});

  @override
  State<LogDetailSheet> createState() => _LogDetailSheetState();
}

class _LogDetailSheetState extends State<LogDetailSheet> {
  final NativeBridge _bridge = NativeBridge();
  bool _isRetrying = false;
  String? _retryResult;
  bool _retrySucceeded = false;
  String? _blacklistFeedback;

  Future<void> _retryWebhook() async {
    final webhookUrl = widget.log.webhookUrl;
    if (webhookUrl.isEmpty || webhookUrl == '-') {
      setState(() => _retryResult = 'No webhook URL to resend.');
      return;
    }

    setState(() {
      _isRetrying = true;
      _retryResult = null;
    });

    // Execute retry via Native Android engine (preserves HMAC signature, custom headers, and updates SQLite status)
    final res = await _bridge.retryWebhookLog(widget.log.id);
    final success = res['success'] == true;
    final code = res['statusCode'] ?? 0;
    final msg = res['message']?.toString() ?? '';

    if (mounted) {
      setState(() {
        _isRetrying = false;
        _retrySucceeded = success;
        _retryResult = success
            ? 'Sukses dikirim ulang! (HTTP $code)\nResponse: $msg'
            : 'Gagal mengirim ulang (HTTP $code): $msg';
      });
      widget.onRefreshLogs();
    }
  }

  void _showBlacklistDialog(I18n i18n) {
    final initialText = widget.log.text.isNotEmpty ? widget.log.text : widget.log.title;
    final controller = TextEditingController(text: initialText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.deepOrange, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${i18n.blacklistDialogTitle} ${widget.log.packageName}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n.blacklistDialogDesc,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: i18n.blacklistPatternLabel,
                hintText: i18n.blacklistPatternHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(i18n.btnCancel),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange.shade800),
            onPressed: () async {
              final pattern = controller.text.trim();
              if (pattern.isNotEmpty) {
                final ok = await NativeBridge().addPackageBlacklist(widget.log.packageName, pattern);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted && ok) {
                  setState(() {
                    _blacklistFeedback = '${i18n.blacklistSuccess}\n"$pattern"';
                  });
                  widget.onRefreshLogs();
                }
              }
            },
            icon: const Icon(Icons.check, size: 16),
            label: Text(i18n.btnAddToBlacklist),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final i18n = I18n.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.teal),
                const SizedBox(width: 8),
                Text(i18n.modalPayloadDetail, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status Alert
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (log.isSuccess || _retrySucceeded)
                        ? Colors.teal.shade50
                        : log.isFailed
                            ? Colors.red.shade50
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (log.isSuccess || _retrySucceeded)
                          ? Colors.teal.shade200
                          : log.isFailed
                              ? Colors.red.shade200
                              : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (log.isSuccess || _retrySucceeded)
                            ? Icons.check_circle
                            : log.isFailed
                                ? Icons.error
                                : Icons.info_outline,
                        color: (log.isSuccess || _retrySucceeded)
                            ? Colors.teal
                            : log.isFailed
                                ? Colors.red
                                : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (log.isSuccess || _retrySucceeded)
                                  ? i18n.dispatchedSuccess(log.httpStatus > 0 ? log.httpStatus : 200)
                                  : log.isFailed
                                      ? i18n.dispatchFailed
                                      : i18n.notificationSkipped,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (log.latencyMs > 0)
                              Text(i18n.latencyLabel(log.latencyMs), style: const TextStyle(fontSize: 11)),
                            if (log.errorMessage.isNotEmpty && !_retrySucceeded)
                              Text(i18n.errorMessageLabel(log.errorMessage), style: const TextStyle(fontSize: 11, color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Source Info
                _buildSectionTitle(i18n.sectionIncomingInfo),
                _buildField(i18n.fieldAppPackage, log.packageName),
                _buildField(i18n.fieldTitle, log.title.isEmpty ? i18n.fieldEmpty : log.title),
                _buildField(i18n.fieldMessageContent, log.text),
                _buildField(i18n.fieldReceivedTime, log.datetime),

                const SizedBox(height: 16),

                // Rule & Webhook Info
                _buildSectionTitle(i18n.sectionRuleWebhook),
                _buildField(i18n.fieldMatchedRule, log.matchedRuleName),
                _buildField('URL Webhook:', log.webhookUrl),

                // Action Buttons: Resend & Blacklist
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (log.webhookUrl.isNotEmpty && log.webhookUrl != '-')
                      OutlinedButton.icon(
                        onPressed: _isRetrying ? null : _retryWebhook,
                        icon: _isRetrying
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.replay),
                        label: Text(i18n.btnResend),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _showBlacklistDialog(i18n),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepOrange.shade800,
                        side: BorderSide(color: Colors.deepOrange.shade300),
                      ),
                      icon: const Icon(Icons.block, size: 16),
                      label: Text(i18n.btnBlacklistThis),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        BlacklistManagerSheet.show(context, initialPackageFilter: log.packageName);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueGrey.shade700,
                        side: BorderSide(color: Colors.blueGrey.shade300),
                      ),
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: Text(i18n.btnManageBlacklist),
                    ),
                  ],
                ),
                if (_blacklistFeedback != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.teal.shade300, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 20, color: Colors.teal.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _blacklistFeedback!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          i18n.blacklistNoticeDesc,
                          style: TextStyle(fontSize: 11, color: Colors.teal.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_retryResult != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _retryResult!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _retrySucceeded ? Colors.teal : Colors.red,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Payload Sent
                _buildSectionTitle(i18n.sectionPayloadSent),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    log.payloadSent.isNotEmpty ? log.payloadSent : '{\n  "status": "not_dispatched"\n}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.lightGreenAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: log.payloadSent));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(i18n.copiedToClipboard)),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(i18n.btnCopy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
