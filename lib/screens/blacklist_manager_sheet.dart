import 'package:flutter/material.dart';
import '../services/app_localizations.dart';
import '../services/native_bridge.dart';

class BlacklistManagerSheet extends StatefulWidget {
  final String? initialPackageFilter;

  const BlacklistManagerSheet({super.key, this.initialPackageFilter});

  static Future<void> show(BuildContext context, {String? initialPackageFilter}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlacklistManagerSheet(initialPackageFilter: initialPackageFilter),
    );
  }

  @override
  State<BlacklistManagerSheet> createState() => _BlacklistManagerSheetState();
}

class _BlacklistManagerSheetState extends State<BlacklistManagerSheet> {
  final NativeBridge _bridge = NativeBridge();
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadBlacklist();
  }

  Future<void> _loadBlacklist() async {
    setState(() => _isLoading = true);
    final all = await _bridge.getAllBlacklist();
    if (mounted) {
      setState(() {
        if (widget.initialPackageFilter != null && widget.initialPackageFilter!.isNotEmpty) {
          _items = all.where((item) => item['package_name'] == widget.initialPackageFilter).toList();
        } else {
          _items = all;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final i18n = I18n.of(context);
    final id = item['id']?.toString() ?? '';
    final pattern = item['pattern']?.toString() ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.confirmDeleteBlacklist),
        content: Text('"$pattern" (${item['package_name']})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(i18n.btnCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(i18n.btnDelete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _bridge.deletePackageBlacklist(id);
      if (success) {
        await _loadBlacklist();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.teal.shade800,
              content: Text(i18n.blacklistDeleted),
            ),
          );
        }
      }
    }
  }

  Future<void> _showAddManualDialog() async {
    final i18n = I18n.of(context);
    final pkgController = TextEditingController(text: widget.initialPackageFilter ?? '');
    final patternController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.btnAddNewBlacklist),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pkgController,
              decoration: InputDecoration(
                labelText: i18n.fieldAppPackage,
                hintText: 'Misal: com.whatsapp',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: patternController,
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(i18n.btnCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange.shade800),
            onPressed: () async {
              final pkg = pkgController.text.trim();
              final pat = patternController.text.trim();
              if (pkg.isNotEmpty && pat.isNotEmpty) {
                await _bridge.addPackageBlacklist(pkg, pat);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadBlacklist();
              }
            },
            child: Text(i18n.btnAddToBlacklist),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);

    // Group items by package_name
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in _items) {
      final pkg = item['package_name']?.toString() ?? 'unknown';
      grouped.putIfAbsent(pkg, () => []).add(item);
    }

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
                const Icon(Icons.block, color: Colors.deepOrange, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i18n.blacklistAllAppsTitle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        i18n.blacklistAllAppsSubtitle,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: i18n.btnAddNewBlacklist,
                  icon: const Icon(Icons.add_circle_outline, color: Colors.deepOrange),
                  onPressed: _showAddManualDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.filter_list_off, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                i18n.blacklistEmptyTotal,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, height: 1.45, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: _showAddManualDialog,
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(i18n.btnAddNewBlacklist),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: grouped.keys.length,
                        itemBuilder: (ctx, index) {
                          final pkg = grouped.keys.elementAt(index);
                          final pkgItems = grouped[pkg]!;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            elevation: 0.5,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.deepOrange.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          pkg,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange.shade900,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${pkgItems.length} pola',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  ...pkgItems.map((item) {
                                    final pattern = item['pattern']?.toString() ?? '';
                                    final createdAt = item['created_at'];
                                    String dateStr = '';
                                    if (createdAt != null) {
                                      final dt = DateTime.fromMillisecondsSinceEpoch((createdAt as num).toInt());
                                      dateStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}';
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.remove_circle_outline, size: 16, color: Colors.deepOrange),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  pattern,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (dateStr.isNotEmpty)
                                                  Text(
                                                    'Ditambahkan: $dateStr',
                                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: i18n.btnDelete,
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            onPressed: () => _deleteItem(item),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
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
}
