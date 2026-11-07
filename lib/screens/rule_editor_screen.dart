import 'package:flutter/material.dart';
import '../models/webhook_rule.dart';
import '../services/app_localizations.dart';
import '../services/native_bridge.dart';

class RuleEditorScreen extends StatefulWidget {
  final WebhookRule? rule;
  final Function(WebhookRule) onSave;

  const RuleEditorScreen({super.key, this.rule, required this.onSave});

  @override
  State<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<RuleEditorScreen> {
  final NativeBridge _bridge = NativeBridge();

  late final TextEditingController _nameController;
  late final TextEditingController _packageController;
  late final TextEditingController _regexController;
  late final TextEditingController _urlController;
  late final TextEditingController _secretKeyController;
  late final TextEditingController _customPayloadController;
  late final TextEditingController _testSampleController;

  String _httpMethod = 'POST';
  bool _regexIgnoreCase = true;
  bool _sendOnlyIfMatched = false;
  int _maxRetries = 3;
  bool _ignoreGroupSummary = true;
  bool _deduplicateMessages = true;
  bool _ignoreOngoing = true;
  int _cooldownSeconds = 0;

  bool _isTesting = false;
  String? _testResultText;

  bool _isRegexMatch = false;
  String _regexMatchMessage = '';
  List<String> _matchedGroups = [];
  Map<String, String> _matchedNamedGroups = {};

  @override
  void initState() {
    super.initState();
    final i18n = I18n(appLocaleNotifier.locale);
    final r = widget.rule;
    _nameController = TextEditingController(text: r?.name ?? i18n.defaultRuleName);
    _packageController = TextEditingController(text: r?.packageName ?? '*');
    _regexController = TextEditingController(text: r?.regexPattern ?? '');
    _urlController = TextEditingController(text: r?.webhookUrl ?? '');
    _secretKeyController = TextEditingController(text: r?.secretKey ?? '');
    _customPayloadController = TextEditingController(text: r?.customPayload ?? '');
    _testSampleController = TextEditingController(text: i18n.defaultSampleText);

    _httpMethod = r?.httpMethod ?? 'POST';
    _regexIgnoreCase = r?.regexIgnoreCase ?? true;
    _sendOnlyIfMatched = r?.sendOnlyIfMatched ?? false;
    _maxRetries = r?.maxRetries ?? 3;
    _ignoreGroupSummary = r?.ignoreGroupSummary ?? true;
    _deduplicateMessages = r?.deduplicateMessages ?? true;
    _ignoreOngoing = r?.ignoreOngoing ?? true;
    _cooldownSeconds = r?.cooldownSeconds ?? 0;

    _evaluateRegex();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _packageController.dispose();
    _regexController.dispose();
    _urlController.dispose();
    _secretKeyController.dispose();
    _customPayloadController.dispose();
    _testSampleController.dispose();
    super.dispose();
  }

  void _applyPreset(WebhookRulePreset preset) {
    setState(() {
      _nameController.text = preset.title;
      _packageController.text = preset.packageName;
      _regexController.text = preset.regexPattern;
      _testSampleController.text = preset.sampleText;
      _sendOnlyIfMatched = preset.regexPattern.isNotEmpty;
    });
    _evaluateRegex();
  }

  void _evaluateRegex() {
    final i18n = I18n(appLocaleNotifier.locale);
    final pattern = _regexController.text.trim();
    final sample = _testSampleController.text;

    if (pattern.isEmpty) {
      setState(() {
        _isRegexMatch = true;
        _regexMatchMessage = i18n.regexMatchAll;
        _matchedGroups = [];
        _matchedNamedGroups = {};
      });
      return;
    }

    try {
      final reg = RegExp(pattern, caseSensitive: !_regexIgnoreCase, multiLine: true);
      final match = reg.firstMatch(sample);
      if (match != null) {
        final groups = <String>[];
        for (int i = 1; i <= match.groupCount; i++) {
          groups.add(match.group(i) ?? '');
        }
        final named = <String, String>{};
        for (final gName in match.groupNames) {
          final val = match.namedGroup(gName);
          if (val != null) {
            named[gName] = val;
          }
        }
        setState(() {
          _isRegexMatch = true;
          _regexMatchMessage = i18n.regexMatchedCount(match.groupCount);
          _matchedGroups = groups;
          _matchedNamedGroups = named;
        });
      } else {
        setState(() {
          _isRegexMatch = false;
          _regexMatchMessage = i18n.regexNotMatched;
          _matchedGroups = [];
          _matchedNamedGroups = {};
        });
      }
    } catch (e) {
      setState(() {
        _isRegexMatch = false;
        _regexMatchMessage = i18n.regexInvalidError(e);
        _matchedGroups = [];
        _matchedNamedGroups = {};
      });
    }
  }

  Future<void> _pickInstalledApp() async {
    final apps = await _bridge.getInstalledApps();
    if (!mounted) return;
    final i18n = I18n(appLocaleNotifier.locale);

    final selected = await showDialog<InstalledApp>(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = apps.where((a) {
              return a.appName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  a.packageName.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              title: Text(i18n.dialogPickAppTitle),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: i18n.searchAppHint,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => setDialogState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final app = filtered[i];
                          return ListTile(
                            dense: true,
                            title: Text(app.appName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(app.packageName, style: const TextStyle(fontSize: 11)),
                            onTap: () => Navigator.pop(ctx, app),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(i18n.btnCancel),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        if (_packageController.text.trim().isEmpty || _packageController.text.trim() == '*') {
          _packageController.text = selected.packageName;
        } else {
          _packageController.text = '${_packageController.text}, ${selected.packageName}';
        }
      });
    }
  }

  Future<void> _runEndpointTest() async {
    final i18n = I18n(appLocaleNotifier.locale);
    if (_urlController.text.trim().isEmpty) {
      setState(() => _testResultText = i18n.errWebhookUrlRequired);
      return;
    }

    setState(() {
      _isTesting = true;
      _testResultText = i18n.sendingTestRequest(_urlController.text.trim());
    });

    final tempRule = WebhookRule(
      id: 'temp_test',
      name: _nameController.text.trim(),
      packageName: _packageController.text.trim(),
      regexPattern: _regexController.text.trim(),
      regexIgnoreCase: _regexIgnoreCase,
      webhookUrl: _urlController.text.trim(),
      httpMethod: _httpMethod,
      customPayload: _customPayloadController.text.trim(),
      sendOnlyIfMatched: _sendOnlyIfMatched,
      secretKey: _secretKeyController.text.trim(),
      maxRetries: _maxRetries,
      ignoreGroupSummary: _ignoreGroupSummary,
      deduplicateMessages: _deduplicateMessages,
      ignoreOngoing: _ignoreOngoing,
      cooldownSeconds: _cooldownSeconds,
    );

    final res = await _bridge.testWebhook(
      rule: tempRule,
      sampleTitle: i18n.testSampleGatewayTitle,
      sampleText: _testSampleController.text.trim(),
    );

    setState(() {
      _isTesting = false;
      final success = res['success'] == true;
      final code = res['statusCode'] ?? 0;
      final msg = res['message'] ?? '';
      _testResultText = success
          ? i18n.testSuccessResult(code, msg)
          : i18n.testFailedResult(code, msg);
    });
  }

  void _save() {
    final i18n = I18n(appLocaleNotifier.locale);
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.errRuleNameRequired)),
      );
      return;
    }
    if (_urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.errWebhookUrlRequired)),
      );
      return;
    }

    final newRule = WebhookRule(
      id: widget.rule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      enabled: widget.rule?.enabled ?? true,
      packageName: _packageController.text.trim(),
      regexPattern: _regexController.text.trim(),
      regexIgnoreCase: _regexIgnoreCase,
      webhookUrl: _urlController.text.trim(),
      httpMethod: _httpMethod,
      customPayload: _customPayloadController.text.trim(),
      sendOnlyIfMatched: _sendOnlyIfMatched,
      secretKey: _secretKeyController.text.trim(),
      maxRetries: _maxRetries,
      ignoreGroupSummary: _ignoreGroupSummary,
      deduplicateMessages: _deduplicateMessages,
      ignoreOngoing: _ignoreOngoing,
      cooldownSeconds: _cooldownSeconds,
    );

    widget.onSave(newRule);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.rule == null ? i18n.editorTitleAdd : i18n.editorTitleEdit,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _save,
            style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade800),
            icon: const Icon(Icons.check, size: 18),
            label: Text(i18n.btnSave),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Presets
          Text(i18n.presetsTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: i18n.currentPresets.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.bolt, size: 16, color: Colors.teal),
                    label: Text(p.title),
                    onPressed: () => _applyPreset(p),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 18),

          // Rule Name
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: i18n.ruleNameLabel,
              hintText: i18n.ruleNameHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.label_outline),
            ),
          ),

          const SizedBox(height: 16),

          // Package Filter
          TextField(
            controller: _packageController,
            decoration: InputDecoration(
              labelText: i18n.sourceAppLabel,
              hintText: i18n.sourceAppHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.apps_outlined),
              suffixIcon: IconButton(
                icon: const Icon(Icons.list_alt),
                tooltip: i18n.btnPickApp,
                onPressed: _pickInstalledApp,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.all_inclusive, size: 14),
                label: Text(i18n.chipAll, style: const TextStyle(fontSize: 11)),
                onPressed: () => setState(() => _packageController.text = '*'),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.app_registration, size: 14),
                label: Text(i18n.btnPickApp, style: const TextStyle(fontSize: 11)),
                onPressed: _pickInstalledApp,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Anti-Spam, Ongoing Filter, Group Summary & Cooldown Controls
          Card(
            elevation: 0,
            color: Colors.teal.shade50.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.teal.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _ignoreGroupSummary,
                    activeThumbColor: Colors.teal.shade700,
                    title: Text(
                      i18n.groupSummaryTitle,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      i18n.groupSummarySubtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                    onChanged: (val) => setState(() => _ignoreGroupSummary = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _ignoreOngoing,
                    activeThumbColor: Colors.teal.shade700,
                    title: Text(
                      i18n.isId
                          ? 'Abaikan Notifikasi Berjalan (Ongoing / Progress)'
                          : 'Ignore Ongoing / Progress Notifications',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      i18n.isId
                          ? 'Menyaring pemutar musik, unduhan berjalan, dan layanan aktif agar tidak memicu spam webhook.'
                          : 'Filters media players, active downloads, and foreground services from triggering webhooks.',
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                    onChanged: (val) => setState(() => _ignoreOngoing = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _deduplicateMessages,
                    activeThumbColor: Colors.teal.shade700,
                    title: Text(
                      i18n.deduplicateTitle,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      i18n.deduplicateSubtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                    onChanged: (val) => setState(() => _deduplicateMessages = val),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: DropdownButtonFormField<int>(
                      initialValue: _cooldownSeconds,
                      decoration: InputDecoration(
                        labelText: i18n.isId
                            ? 'Jeda Anti-Spam per Aturan (Cooldown)'
                            : 'Per-Rule Anti-Spam Cooldown',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(value: 0, child: Text(i18n.isId ? 'Tanpa Cooldown (Real-time)' : 'No Cooldown (Real-time)')),
                        DropdownMenuItem(value: 5, child: Text(i18n.isId ? '5 Detik' : '5 Seconds')),
                        DropdownMenuItem(value: 15, child: Text(i18n.isId ? '15 Detik' : '15 Seconds')),
                        DropdownMenuItem(value: 30, child: Text(i18n.isId ? '30 Detik' : '30 Seconds')),
                        DropdownMenuItem(value: 60, child: Text(i18n.isId ? '60 Detik (1 Menit)' : '60 Seconds (1 Minute)')),
                      ],
                      onChanged: (val) => setState(() => _cooldownSeconds = val ?? 0),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Regex Pattern
          TextField(
            controller: _regexController,
            decoration: InputDecoration(
              labelText: i18n.regexLabel,
              hintText: i18n.regexHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.data_object),
            ),
            onChanged: (_) => _evaluateRegex(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Checkbox(
                value: _regexIgnoreCase,
                onChanged: (val) {
                  setState(() => _regexIgnoreCase = val ?? true);
                  _evaluateRegex();
                },
              ),
              Text(i18n.regexIgnoreCase, style: const TextStyle(fontSize: 12)),
            ],
          ),

          // Live Regex Sandbox
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.regexSandboxTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _testSampleController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: i18n.sampleNotifTextHint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _evaluateRegex(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _isRegexMatch ? Icons.check_circle : Icons.error_outline,
                      size: 16,
                      color: _isRegexMatch ? Colors.teal : Colors.deepOrange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _regexMatchMessage,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isRegexMatch ? Colors.teal : Colors.deepOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_matchedGroups.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ..._matchedGroups.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final val = entry.value;
                    return Text(
                      i18n.groupLabel(idx, val),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.blueAccent),
                    );
                  }),
                ],
                if (_matchedNamedGroups.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ..._matchedNamedGroups.entries.map((entry) {
                    return Text(
                      '• Named ({{${entry.key}}}): "${entry.value}"',
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                    );
                  }),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Webhook Endpoint Configuration
          Text(i18n.targetWebhookSection, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),

          Row(
            children: [
              SizedBox(
                width: 105,
                child: DropdownButtonFormField<String>(
                  initialValue: _httpMethod,
                  decoration: InputDecoration(
                    labelText: i18n.httpMethodLabel,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'POST', child: Text('POST')),
                    DropdownMenuItem(value: 'GET', child: Text('GET')),
                    DropdownMenuItem(value: 'PUT', child: Text('PUT')),
                  ],
                  onChanged: (val) => setState(() => _httpMethod = val ?? 'POST'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: i18n.webhookUrlLabel,
                    hintText: 'https://your-domain.com/webhook',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.http),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Secret Key (Optional HMAC-SHA256 signature)
          TextField(
            controller: _secretKeyController,
            decoration: InputDecoration(
              labelText: i18n.secretKeyLabel,
              hintText: i18n.secretKeyHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key),
            ),
          ),

          const SizedBox(height: 12),

          // Retry count
          DropdownButtonFormField<int>(
            initialValue: _maxRetries,
            decoration: InputDecoration(
              labelText: i18n.maxRetriesLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(value: 1, child: Text(i18n.retryOption1)),
              DropdownMenuItem(value: 3, child: Text(i18n.retryOption3)),
              DropdownMenuItem(value: 5, child: Text(i18n.retryOption5)),
            ],
            onChanged: (val) => setState(() => _maxRetries = val ?? 3),
          ),

          const SizedBox(height: 14),

          // Test Webhook Button
          OutlinedButton.icon(
            onPressed: _isTesting ? null : _runEndpointTest,
            icon: _isTesting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(i18n.btnTestWebhook),
          ),

          if (_testResultText != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _testResultText!.contains('SUKSES') || _testResultText!.contains('SUCCESS')
                    ? Colors.teal.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _testResultText!.contains('SUKSES') || _testResultText!.contains('SUCCESS')
                      ? Colors.teal.shade200
                      : Colors.red.shade200,
                ),
              ),
              child: Text(
                _testResultText!,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: _testResultText!.contains('SUKSES') || _testResultText!.contains('SUCCESS')
                      ? Colors.teal.shade900
                      : Colors.red.shade900,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Custom Payload (Optional)
          ExpansionTile(
            title: Text(i18n.customPayloadTitle, style: const TextStyle(fontSize: 13)),
            children: [
              Text(
                i18n.customPayloadDesc,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customPayloadController,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{\n  "app": "{{app_name}}",\n  "title": "{{title}}",\n  "message": "{{text}}",\n  "otp": "{{otp}}",\n  "datetime": "{{datetime}}"\n}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
