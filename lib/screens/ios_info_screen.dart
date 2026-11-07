import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_localizations.dart';
import 'setup_guide_dialog.dart';

class IosInfoScreen extends StatelessWidget {
  const IosInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.guideTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Android Setup Quick Action
          Card(
            color: Colors.teal.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.teal.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone_android, color: Colors.teal, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          i18n.guideAndroidTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.guideAndroidDesc,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => SetupGuideDialog.showIfNeeded(context, force: true),
                      icon: const Icon(Icons.settings, size: 18),
                      label: Text(i18n.btnSetupGuide),
                      style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Card: Panduan Kunci Aplikasi di Recent Apps
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.blueGrey.shade200),
            ),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.lock_outline, color: Colors.blueGrey.shade800, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i18n.guideKeepAliveTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blueGrey.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              i18n.guideKeepAliveSubtitle,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildLockStep('1', i18n.guideLockStep1),
                  _buildLockStep('2', i18n.guideLockStep2),
                  _buildLockStep('3', i18n.guideLockStep3),
                  _buildLockStep('4', i18n.guideLockStep4, isSuccess: true),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates_outlined, color: Colors.teal.shade800, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            i18n.guideKeepAliveAltNote,
                            style: TextStyle(fontSize: 11.5, color: Colors.teal.shade900, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Alert Card: Mengapa iOS berbeda?
          Card(
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.amber.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, color: Colors.amber, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          i18n.guideAppleTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    i18n.guideAppleDesc,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Alternatif Khusus SMS di iOS: Apple Shortcuts
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.indigo),
                      const SizedBox(width: 8),
                      Text(
                        i18n.guideShortcutsTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.guideShortcutsDesc,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Format Payload JSON Universal
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.guidePayloadTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i18n.guidePayloadDesc,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      _jsonSchema,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.lightGreenAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Contoh Kode Server Webhook Handler
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        i18n.guideNodeTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: Text(i18n.btnCopy, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: _nodeCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(i18n.copiedToClipboard)),
                          );
                        },
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      _nodeCode,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.lightGreenAccent),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        i18n.guidePhpTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: Text(i18n.btnCopy, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: _phpCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(i18n.copiedToClipboard)),
                          );
                        },
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      _phpCode,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.lightGreenAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLockStep(String number, String text, {bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSuccess ? Colors.teal : Colors.blueGrey.shade100,
              shape: BoxShape.circle,
            ),
            child: isSuccess
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : Text(
                    number,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSuccess ? FontWeight.w600 : FontWeight.normal,
                color: isSuccess ? Colors.teal.shade900 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const String _jsonSchema = r'''{
  "event": "notification_received",
  "timestamp": 1730900000000,
  "datetime": "2026-11-06T18:20:00.000+0700",
  "app": {
    "package_name": "com.example.app",
    "app_name": "App Name"
  },
  "notification": {
    "title": "Sender Name",
    "text": "Message content",
    "big_text": "Detailed message content",
    "sub_text": "",
    "full_content": "Sender Name Message content"
  },
  "rule": {
    "id": "rule_default_01",
    "name": "Notification Rule"
  },
  "matches": {
    "has_regex": false,
    "regex_pattern": "",
    "groups": []
  }
}''';

  static const String _nodeCode = r'''// webhook-handler.js (Node.js Express)
const express = require('express');
const app = express();
app.use(express.json());

app.post('/api/webhook', (req, res) => {
  const { event, app: sourceApp, notification, rule, matches } = req.body;
  
  console.log("=== INCOMING NOTIFICATION ===");
  console.log("App:", sourceApp.app_name, `(${sourceApp.package_name})`);
  console.log("Title / Sender:", notification.title);
  console.log("Message:", notification.text);
  console.log("Rule:", rule.name);

  res.status(200).json({ status: 'success', message: 'Webhook received' });
});

app.listen(3000, () => console.log('Webhook server running on port 3000'));''';

  static const String _phpCode = r'''<?php
// webhook-handler.php
header('Content-Type: application/json');

$rawInput = file_get_contents('php://input');
$data = json_decode($rawInput, true);

if (!$data) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid JSON']);
    exit;
}

$appName = $data['app']['app_name'] ?? 'Unknown';
$title   = $data['notification']['title'] ?? '';
$text    = $data['notification']['text'] ?? '';

file_put_contents('webhook_logs.txt', date('Y-m-d H:i:s') . " - [$appName] $title: $text\n", FILE_APPEND);

echo json_encode(['status' => 'success']);
''';
}
