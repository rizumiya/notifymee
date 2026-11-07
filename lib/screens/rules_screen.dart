import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/webhook_rule.dart';
import '../services/app_localizations.dart';
import '../services/native_bridge.dart';
import 'rule_editor_screen.dart';
import 'blacklist_manager_sheet.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  final NativeBridge _bridge = NativeBridge();
  List<WebhookRule> _rules = [];
  bool _isLoading = true;

  static const List<Map<String, String>> _builtInPresets = [
    {
      'fileName': 'whatsapp_chat_dan_antispam.json',
      'title': 'WhatsApp Chat + Anti-Spam Lengkap',
      'packageName': 'com.whatsapp',
      'json': '''{
  "schema": "notifymee_package_bundle_v2",
  "export_name": "whatsapp_chat_dan_antispam.json",
  "package_filter": "com.whatsapp",
  "rules": [
    {
      "id": "preset_wa_chat_01",
      "name": "Forward Pesan WhatsApp (Tanpa Spam)",
      "enabled": true,
      "package_name": "com.whatsapp",
      "regex_pattern": "",
      "regex_ignore_case": true,
      "webhook_url": "https://httpbin.org/post",
      "http_method": "POST",
      "custom_payload": "",
      "send_only_if_matched": false,
      "secret_key": "",
      "max_retries": 3,
      "ignore_group_summary": true,
      "deduplicate_messages": true,
      "ignore_ongoing": true,
      "cooldown_seconds": 0
    }
  ],
  "blacklists": [
    { "package_name": "com.whatsapp", "pattern": "Memeriksa pesan baru" },
    { "package_name": "com.whatsapp", "pattern": "Checking for new messages" },
    { "package_name": "com.whatsapp", "pattern": "WhatsApp Web sedang aktif" },
    { "package_name": "com.whatsapp", "pattern": "Mencadangkan pesan" }
  ]
}'''
    },
    {
      'fileName': 'mutasi_qris_dana_bca_gopay.json',
      'title': 'Mutasi Pembayaran QRIS / Bank / E-Wallet',
      'packageName': 'id.dana, com.bca, com.gojek.app',
      'json': '''{
  "schema": "notifymee_package_bundle_v2",
  "export_name": "mutasi_qris_dana_bca_gopay.json",
  "package_filter": "id.dana, com.bca, com.gojek.app",
  "rules": [
    {
      "id": "preset_qris_mutasi_01",
      "name": "Mutasi Pembayaran QRIS & Transfer",
      "enabled": true,
      "package_name": "id.dana, com.bca, com.gojek.app, id.co.bri.brimo, com.livin.mandiri",
      "regex_pattern": "(?:Rp|IDR)[\\\\s.]*([0-9.,]+)",
      "regex_ignore_case": true,
      "webhook_url": "https://httpbin.org/post",
      "http_method": "POST",
      "custom_payload": "",
      "send_only_if_matched": true,
      "secret_key": "",
      "max_retries": 5,
      "ignore_group_summary": true,
      "deduplicate_messages": true,
      "ignore_ongoing": true,
      "cooldown_seconds": 0
    }
  ],
  "blacklists": [
    { "package_name": "id.dana", "pattern": "Promo" },
    { "package_name": "com.gojek.app", "pattern": "Diskon" }
  ]
}'''
    },
    {
      'fileName': 'otp_verifikasi_universal.json',
      'title': 'Ekstraktor Kode OTP Universal (4-8 Digit)',
      'packageName': '*',
      'json': '''{
  "schema": "notifymee_package_bundle_v2",
  "export_name": "otp_verifikasi_universal.json",
  "package_filter": "*",
  "rules": [
    {
      "id": "preset_otp_universal_01",
      "name": "Penerus Kode OTP Otomatis",
      "enabled": true,
      "package_name": "*",
      "regex_pattern": "(?:OTP|kode|code|verifikasi|verification)[^0-9]{0,25}([0-9]{4,8})",
      "regex_ignore_case": true,
      "webhook_url": "https://httpbin.org/post",
      "http_method": "POST",
      "custom_payload": "",
      "send_only_if_matched": true,
      "secret_key": "",
      "max_retries": 3,
      "ignore_group_summary": true,
      "deduplicate_messages": true,
      "ignore_ongoing": true,
      "cooldown_seconds": 0
    }
  ],
  "blacklists": []
}'''
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    final rules = await _bridge.getRules();
    if (mounted) {
      setState(() {
        _rules = rules;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRules(List<WebhookRule> updated) async {
    setState(() => _rules = updated);
    await _bridge.saveRules(updated);
  }

  Future<void> _toggleRule(WebhookRule rule, bool val) async {
    final updated = _rules.map((r) => r.id == rule.id ? r.copyWith(enabled: val) : r).toList();
    await _saveRules(updated);
  }

  Future<void> _deleteRule(WebhookRule rule) async {
    final i18n = I18n.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.deleteConfirmTitle),
        content: Text('${i18n.deleteConfirmDesc}\n"${rule.name}"'),
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
      final updated = _rules.where((r) => r.id != rule.id).toList();
      await _saveRules(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.ruleDeletedSuccess)),
        );
      }
    }
  }

  Future<void> _exportRules() async {
    final i18n = I18n.of(context);
    final rawDbJson = await _bridge.exportDatabaseJson();
    final blacklists = await _bridge.getAllBlacklist();
    final fileNameController = TextEditingController(text: 'notifymee_package_config.json');

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final safeName = fileNameController.text.trim().isEmpty
              ? 'notifymee_package_config.json'
              : (fileNameController.text.trim().endsWith('.json')
                  ? fileNameController.text.trim()
                  : '${fileNameController.text.trim()}.json');

          Map<String, dynamic> parsedDb = {};
          try {
            parsedDb = jsonDecode(rawDbJson) as Map<String, dynamic>;
          } catch (_) {}

          final bundle = {
            'schema': 'notifymee_package_bundle_v2',
            'export_name': safeName,
            'exported_at': DateTime.now().toIso8601String(),
            'rules': parsedDb['rules'] ?? _rules.map((r) => r.toMap()).toList(),
            'blacklists': blacklists,
          };
          final prettyJson = const JsonEncoder.withIndent('  ').convert(bundle);

          return AlertDialog(
            title: Text(
              i18n.isId ? 'Export Pengaturan Package' : 'Export Package Config',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: fileNameController,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: i18n.isId ? 'Nama File Export (.json)' : 'Export File Name (.json)',
                        hintText: 'whatsapp_config.json',
                        prefixIcon: const Icon(Icons.insert_drive_file_outlined),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      i18n.isId
                          ? 'Pratinjau JSON ($safeName):'
                          : 'JSON Preview ($safeName):',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 150,
                      width: double.maxFinite,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2926),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          prettyJson,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            color: Color(0xFF80CBC4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(i18n.btnCancel),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00695C)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: prettyJson));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF00695C),
                        content: Text('${i18n.copiedToClipboard} ($safeName)'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(i18n.isId ? 'Salin JSON ($safeName)' : 'Copy JSON ($safeName)'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _importRules() async {
    final i18n = I18n.of(context);
    final textController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            i18n.isId ? 'Import Pengaturan Package' : 'Import Package Config',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.isId
                        ? 'Koleksi Siap Import (Folder /presets GitHub):'
                        : 'Ready-to-Import Collection (/presets folder):',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00695C)),
                  ),
                  const SizedBox(height: 6),
                  ..._builtInPresets.map((preset) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      color: const Color(0xFFF4FAF9),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFB2DFDB)),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          preset['title']!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          preset['fileName']!,
                          style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () {
                            setDialogState(() {
                              textController.text = preset['json']!;
                            });
                          },
                          child: Text(i18n.isId ? 'Pilih' : 'Select', style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Text(
                    i18n.importConfigPrompt,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: textController,
                    maxLines: 7,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '{\n  "schema": "notifymee_package_bundle_v2",\n  "rules": [...],\n  "blacklists": [...]\n}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(i18n.btnCancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00695C)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(i18n.btnImportConfig),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && textController.text.trim().isNotEmpty) {
      final raw = textController.text.trim();
      final success = await _bridge.importDatabaseJson(raw);
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded['blacklists'] is List) {
          for (final item in (decoded['blacklists'] as List)) {
            if (item is Map) {
              final pkg = (item['package_name'] ?? item['packageName'] ?? '*').toString();
              final pat = (item['pattern'] ?? '').toString();
              if (pat.isNotEmpty) {
                await _bridge.addPackageBlacklist(pkg, pat);
              }
            }
          }
        }
      } catch (_) {}
      if (!mounted) return;
      if (success) {
        await _loadRules();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal.shade800,
            content: Text(i18n.importSuccess),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(i18n.importFailed)),
        );
      }
    }
  }

  void _openRuleEditor([WebhookRule? existingRule]) {
    final i18n = I18n.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => RuleEditorScreen(
          rule: existingRule,
          onSave: (savedRule) async {
            List<WebhookRule> updated;
            if (existingRule != null) {
              updated = _rules.map((r) => r.id == savedRule.id ? savedRule : r).toList();
            } else {
              updated = [..._rules, savedRule];
            }
            await _saveRules(updated);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(i18n.ruleSavedSuccess)),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.rulesTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: i18n.btnManageBlacklist,
            icon: const Icon(Icons.block_outlined, color: Colors.deepOrange),
            onPressed: () => BlacklistManagerSheet.show(context),
          ),
          IconButton(
            tooltip: i18n.btnExportConfig,
            icon: const Icon(Icons.copy_all),
            onPressed: _exportRules,
          ),
          IconButton(
            tooltip: i18n.btnImportConfig,
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _importRules,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rule_folder_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        i18n.noRulesYet,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          i18n.noRulesDesc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _openRuleEditor(),
                        icon: const Icon(Icons.add),
                        label: Text(i18n.btnAddRule),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rules.length,
                  itemBuilder: (ctx, index) {
                    final rule = _rules[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: rule.enabled ? Colors.teal.shade50 : Colors.grey.shade100,
                                  child: Icon(
                                    Icons.webhook,
                                    size: 20,
                                    color: rule.enabled ? Colors.teal : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rule.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          decoration: rule.enabled ? null : TextDecoration.lineThrough,
                                        ),
                                      ),
                                      Text(
                                        rule.packageName.isEmpty || rule.packageName == '*'
                                            ? i18n.chipAll
                                            : rule.packageName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: rule.enabled,
                                  activeThumbColor: Colors.teal.shade700,
                                  onChanged: (val) => _toggleRule(rule, val),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            // Details
                            _buildInfoRow(
                              icon: Icons.code,
                              label: i18n.filterLabel,
                              value: rule.regexPattern.isEmpty
                                  ? i18n.allNotifFilterDesc
                                  : rule.regexPattern,
                            ),
                            const SizedBox(height: 4),
                            _buildInfoRow(
                              icon: Icons.link,
                              label: '${rule.httpMethod}: ',
                              value: rule.webhookUrl,
                              color: Colors.blue.shade700,
                            ),
                            if (rule.secretKey.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _buildInfoRow(
                                icon: Icons.security,
                                label: 'Signature: ',
                                value: i18n.signatureActive,
                                color: Colors.teal.shade800,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _openRuleEditor(rule),
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: Text(i18n.btnEdit),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: i18n.btnDelete,
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => _deleteRule(rule),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRuleEditor(),
        icon: const Icon(Icons.add),
        label: Text(i18n.btnAddRule),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: color ?? Colors.black87),
          ),
        ),
      ],
    );
  }
}
