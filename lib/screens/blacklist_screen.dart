import 'package:flutter/material.dart';
import '../services/app_localizations.dart';
import '../services/native_bridge.dart';

class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  final NativeBridge _bridge = NativeBridge();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allItems = [];
  String _searchQuery = '';
  String _selectedPkgFilter = 'ALL';

  static const List<Map<String, String>> _quickSpamTemplates = [
    {'pkg': 'com.whatsapp', 'pattern': 'Memeriksa pesan baru'},
    {'pkg': 'com.whatsapp', 'pattern': 'Checking for new messages'},
    {'pkg': 'com.whatsapp', 'pattern': 'WhatsApp Web sedang aktif'},
    {'pkg': 'com.whatsapp', 'pattern': 'Mencadangkan pesan'},
    {'pkg': 'org.telegram.messenger', 'pattern': 'Updating...'},
    {'pkg': '*', 'pattern': 'Berjalan di latar belakang'},
  ];

  @override
  void initState() {
    super.initState();
    _loadBlacklist();
  }

  String _getItemPackage(Map<String, dynamic> item) {
    return item['packageName']?.toString() ?? item['package_name']?.toString() ?? '*';
  }

  String _getItemPattern(Map<String, dynamic> item) {
    return item['pattern']?.toString() ?? '';
  }

  String _getItemId(Map<String, dynamic> item) {
    return item['id']?.toString() ?? '';
  }

  Future<void> _loadBlacklist() async {
    setState(() => _isLoading = true);
    final all = await _bridge.getAllBlacklist();
    if (mounted) {
      setState(() {
        _allItems = all;
        _isLoading = false;
      });
    }
  }

  Future<void> _addQuickTemplate(String pkg, String pattern) async {
    final i18n = I18n.of(context);
    await _bridge.addPackageBlacklist(pkg, pattern);
    await _loadBlacklist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00695C),
          content: Text('${i18n.blacklistSuccess} ($pattern)'),
        ),
      );
    }
  }

  Future<void> _showAddDialog() async {
    final i18n = I18n.of(context);
    final pkgController = TextEditingController(text: '*');
    final patternController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.block_flipped, color: Color(0xFF00695C), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                i18n.btnAddNewBlacklist,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pkgController,
              decoration: InputDecoration(
                labelText: i18n.fieldAppPackage,
                hintText: 'com.whatsapp atau * untuk semua',
                filled: true,
                fillColor: const Color(0xFFF4FAF9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB2DFDB)),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: patternController,
              decoration: InputDecoration(
                labelText: i18n.blacklistPatternLabel,
                hintText: i18n.blacklistPatternHint,
                filled: true,
                fillColor: const Color(0xFFF4FAF9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB2DFDB)),
                ),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(i18n.btnCancel, style: const TextStyle(color: Colors.grey)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00695C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final pkg = pkgController.text.trim().isEmpty ? '*' : pkgController.text.trim();
              final pat = patternController.text.trim();
              if (pat.isNotEmpty) {
                await _bridge.addPackageBlacklist(pkg, pat);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadBlacklist();
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(i18n.btnAddToBlacklist),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final i18n = I18n.of(context);
    final id = _getItemId(item);
    final pattern = _getItemPattern(item);
    final pkg = _getItemPackage(item);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(i18n.confirmDeleteBlacklist),
        content: Text('"$pattern"\n($pkg)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(i18n.btnCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(i18n.btnDelete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _bridge.deletePackageBlacklist(id);
      await _loadBlacklist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00695C),
            content: Text(i18n.blacklistDeleted),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final packages = <String>{'ALL'};
    for (final item in _allItems) {
      packages.add(_getItemPackage(item));
    }

    final filtered = _allItems.where((item) {
      final pkg = _getItemPackage(item);
      final pat = _getItemPattern(item);
      final matchPkg = _selectedPkgFilter == 'ALL' || pkg == _selectedPkgFilter;
      final matchSearch = _searchQuery.isEmpty ||
          pat.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          pkg.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchPkg && matchSearch;
    }).toList();

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in filtered) {
      final pkg = _getItemPackage(item);
      grouped.putIfAbsent(pkg, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF9),
      appBar: AppBar(
        title: Text(
          i18n.blacklistAllAppsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F2926)),
        ),
        actions: [
          IconButton(
            tooltip: i18n.btnRefresh,
            icon: const Icon(Icons.refresh, color: Color(0xFF00695C)),
            onPressed: _loadBlacklist,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(i18n.btnAddNewBlacklist, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBlacklist,
        color: const Color(0xFF00695C),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            // Soft Pastel Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0F2F1), Color(0xFFFFF3E0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFB2DFDB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF00695C), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.blacklistTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF004D40),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          i18n.blacklistDialogDesc,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF37474F), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Quick Anti-Spam Templates
            Text(
              i18n.isId ? 'Template Filter Spam Sistem (1-Ketuk):' : '1-Tap System Spam Filters:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF455A64)),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickSpamTemplates.map((tpl) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: const Color(0xFFFFF8E1),
                      side: const BorderSide(color: Color(0xFFFFE082)),
                      avatar: const Icon(Icons.add_circle_outline, size: 15, color: Color(0xFFE65100)),
                      label: Text(
                        tpl['pattern']!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF5D4037), fontWeight: FontWeight.w500),
                      ),
                      onPressed: () => _addQuickTemplate(tpl['pkg']!, tpl['pattern']!),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // Search Field
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: i18n.isId ? 'Cari kata kunci atau nama paket...' : 'Search keyword or package...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00796B)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD6E6E3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD6E6E3)),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Package Filter Chips
            if (packages.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: packages.map((pkg) {
                    final selected = _selectedPkgFilter == pkg;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: selected,
                        selectedColor: const Color(0xFFB2DFDB),
                        backgroundColor: Colors.white,
                        label: Text(
                          pkg == 'ALL' ? (i18n.isId ? 'Semua Aplikasi' : 'All Apps') : pkg,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: const Color(0xFF004D40),
                          ),
                        ),
                        onSelected: (_) => setState(() => _selectedPkgFilter = pkg),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 12),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (grouped.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE0ECEA)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF80CBC4)),
                    const SizedBox(height: 12),
                    Text(
                      i18n.blacklistEmptyTotal,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF607D8B), height: 1.45),
                    ),
                  ],
                ),
              )
            else
              ...grouped.entries.map((entry) {
                final pkg = entry.key;
                final items = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDCEBE8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                pkg == '*' ? (i18n.isId ? 'Semua Aplikasi (*)' : 'All Apps (*)') : pkg,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00695C),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${items.length} pola',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE65100),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0xFFEDF4F3)),
                        ...items.map((item) {
                          final pattern = _getItemPattern(item);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(Icons.block, size: 18, color: Color(0xFFEF6C00)),
                            title: Text(
                              pattern,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                              onPressed: () => _deleteItem(item),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
