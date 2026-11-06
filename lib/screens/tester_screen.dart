import 'package:flutter/material.dart';
import '../models/webhook_rule.dart';
import '../services/native_bridge.dart';

class TesterScreen extends StatefulWidget {
  const TesterScreen({super.key});

  @override
  State<TesterScreen> createState() => _TesterScreenState();
}

class _TesterScreenState extends State<TesterScreen> {
  final NativeBridge _bridge = NativeBridge();

  late TextEditingController _packageController;
  late TextEditingController _titleController;
  late TextEditingController _textController;

  List<WebhookRule> _rules = [];
  WebhookRule? _selectedRule;
  bool _isLoading = true;
  bool _isSending = false;
  Map<String, dynamic>? _lastTestResult;

  final List<Map<String, String>> _scenarios = [
    {
      'name': 'Pesan Masuk Telegram',
      'package': 'org.telegram.messenger',
      'title': 'Budi Santoso',
      'text': 'Halo! Update aplikasi telah berhasil dikompilasi.',
    },
    {
      'name': 'Pesan Chat WhatsApp',
      'package': 'com.whatsapp',
      'title': 'Tim Developer',
      'text': 'Request webhook baru telah diterima oleh server.',
    },
    {
      'name': 'Kode OTP / SMS Verifikasi',
      'package': 'com.google.android.apps.messaging',
      'title': 'SMS OTP',
      'text': 'Kode rahasia verifikasi akun Anda adalah 492019.',
    },
    {
      'name': 'Alert Monitoring Sistem',
      'package': 'com.example.monitor',
      'title': 'Server Alert',
      'text': 'CRITICAL: High CPU load on database-primary-01.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _packageController = TextEditingController(text: _scenarios[0]['package']);
    _titleController = TextEditingController(text: _scenarios[0]['title']);
    _textController = TextEditingController(text: _scenarios[0]['text']);
    _loadRules();
  }

  @override
  void dispose() {
    _packageController.dispose();
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    final rules = await _bridge.getRules();
    if (mounted) {
      setState(() {
        _rules = rules;
        if (rules.isNotEmpty) {
          _selectedRule = rules.first;
        }
        _isLoading = false;
      });
    }
  }

  void _applyScenario(Map<String, String> sc) {
    setState(() {
      _packageController.text = sc['package'] ?? '';
      _titleController.text = sc['title'] ?? '';
      _textController.text = sc['text'] ?? '';
    });
  }

  Future<void> _triggerSimulation() async {
    setState(() {
      _isSending = true;
      _lastTestResult = null;
    });

    final pkg = _packageController.text.trim();
    final title = _titleController.text.trim();
    final text = _textController.text.trim();

    final success = await _bridge.simulateNotification(
      packageName: pkg,
      title: title,
      text: text,
    );

    if (mounted) {
      setState(() {
        _isSending = false;
        _lastTestResult = {
          'success': success,
          'message': success
              ? 'Simulasi notifikasi berhasil diproses oleh layanan latar belakang!'
              : 'Gagal memproses simulasi notifikasi.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMatched = false;
    List<String> groups = [];

    if (_selectedRule != null) {
      if (_selectedRule!.regexPattern.isEmpty) {
        isMatched = true;
      } else {
        try {
          final fullContent = '${_titleController.text} ${_textController.text}';
          final reg = RegExp(
            _selectedRule!.regexPattern,
            caseSensitive: !_selectedRule!.regexIgnoreCase,
            multiLine: true,
          );
          final match = reg.firstMatch(fullContent);
          if (match != null) {
            isMatched = true;
            for (int i = 1; i <= match.groupCount; i++) {
              groups.add(match.group(i) ?? '');
            }
          }
        } catch (_) {}
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulator Notifikasi Masuk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Quick Scenario Chips
                const Text('Pilih Contoh Skenario Cepat:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _scenarios.map((sc) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.play_circle_fill, size: 16, color: Colors.teal),
                          label: Text(sc['name']!),
                          onPressed: () => _applyScenario(sc),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Rule Selector for simulation
                if (_rules.isNotEmpty) ...[
                  const Text('Uji Terhadap Aturan Webhook:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<WebhookRule>(
                    initialValue: _selectedRule,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _rules.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text('${r.name} (${r.webhookUrl})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedRule = val),
                  ),
                  const SizedBox(height: 16),
                ],

                // Simulation Input Fields
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data Notifikasi Tiruan:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _packageController,
                          decoration: const InputDecoration(
                            labelText: 'Package Name atau Nama Aplikasi',
                            hintText: 'org.telegram.messenger',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Judul Notifikasi (Pengirim / Subjek)',
                            hintText: 'Budi Santoso',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _textController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Isi Teks Notifikasi',
                            hintText: 'Teks pesan yang ingin disimulasikan...',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Regex Extraction Preview Card
                Card(
                  color: isMatched ? Colors.teal.shade50 : Colors.amber.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isMatched ? Colors.teal.shade200 : Colors.amber.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isMatched ? Icons.check_circle : Icons.warning_amber,
                              color: isMatched ? Colors.teal : Colors.amber.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isMatched ? 'Aturan Cocok & Siap Dikirim' : 'Filter Aturan Belum Cocok',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isMatched ? Colors.teal.shade900 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_selectedRule != null)
                          Text(
                            _selectedRule!.regexPattern.isEmpty
                                ? 'Filter: Semua notifikasi (Tanpa Regex)'
                                : 'Pola Regex: ${_selectedRule!.regexPattern}',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          ),
                        if (groups.isNotEmpty) ...[
                          const Divider(height: 16),
                          ...groups.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            return Text(
                              '• Grup $idx ({{group$idx}}): "${entry.value}"',
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.blueAccent),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Trigger Button
                FilledButton.icon(
                  onPressed: _isSending ? null : _triggerSimulation,
                  icon: _isSending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.rocket_launch),
                  label: const Text('Jalankan Simulasi Webhook Penuh'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                if (_lastTestResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _lastTestResult!['success'] == true ? Colors.teal.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _lastTestResult!['success'] == true ? Colors.teal.shade300 : Colors.red.shade300,
                      ),
                    ),
                    child: Text(
                      _lastTestResult!['message'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _lastTestResult!['success'] == true ? Colors.teal.shade900 : Colors.red.shade900,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
