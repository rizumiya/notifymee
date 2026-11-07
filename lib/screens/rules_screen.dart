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
    final jsonStr = await _bridge.exportDatabaseJson();
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.teal.shade800,
          content: Text(i18n.copiedToClipboard),
        ),
      );
    }
  }

  Future<void> _importRules() async {
    final i18n = I18n.of(context);
    final textController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.btnImportConfig),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i18n.importConfigPrompt,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{\n  "rules": [\n    ...\n  ]\n}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(i18n.btnCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(i18n.btnImportConfig)),
        ],
      ),
    );

    if (confirm == true && textController.text.trim().isNotEmpty) {
      final success = await _bridge.importDatabaseJson(textController.text.trim());
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
