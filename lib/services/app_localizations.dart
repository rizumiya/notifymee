import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/webhook_rule.dart';

class AppLocaleNotifier extends ChangeNotifier {
  static const String _prefKey = 'selected_language';
  Locale _locale = const Locale('id');

  Locale get locale => _locale;
  bool get isIndonesian => _locale.languageCode == 'id';

  AppLocaleNotifier() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString(_prefKey) ?? 'id';
      _locale = Locale(lang);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLocale(String languageCode) async {
    if (_locale.languageCode == languageCode) return;
    _locale = Locale(languageCode);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, languageCode);
    } catch (_) {}
  }

  void toggleLanguage() {
    setLocale(isIndonesian ? 'en' : 'id');
  }
}

final AppLocaleNotifier appLocaleNotifier = AppLocaleNotifier();

class I18n {
  final Locale locale;
  I18n(this.locale);

  static I18n of(BuildContext context) {
    return I18n(appLocaleNotifier.locale);
  }

  bool get isId => locale.languageCode == 'id';

  // Navigation & General
  String get appTitle => isId ? 'Gateway Webhook Notifikasi' : 'Notification Webhook Gateway';
  String get tabDashboard => 'Dashboard';
  String get tabRules => isId ? 'Aturan Webhook' : 'Webhook Rules';
  String get tabLogs => isId ? 'Log Webhook' : 'Webhook Logs';
  String get tabGuide => isId ? 'Panduan Sistem' : 'System Guide';

  // Common Actions
  String get btnCancel => isId ? 'Batal' : 'Cancel';
  String get btnDelete => isId ? 'Hapus' : 'Delete';
  String get btnSave => isId ? 'Simpan' : 'Save';
  String get btnEdit => isId ? 'Ubah' : 'Edit';
  String get btnCopy => isId ? 'Salin' : 'Copy';
  String get btnRefresh => isId ? 'Segarkan' : 'Refresh';
  String get btnManageAll => isId ? 'Kelola Semua' : 'Manage All';
  String get btnViewAll => isId ? 'Lihat Semua Log' : 'View All Logs';
  String get customAction => isId ? 'Kustom' : 'Custom';
  String get copiedToClipboard => isId ? 'Disalin ke clipboard!' : 'Copied to clipboard!';

  // Dashboard
  String get gatewayStatusActive => isId ? 'Gateway Aktif & Memantau' : 'Gateway Active & Monitoring';
  String get gatewayStatusInactive => isId ? 'Gateway Belum Dikonfigurasi' : 'Gateway Not Configured';
  String get gatewayActiveDesc => isId
      ? 'Layanan mendengarkan notifikasi secara real-time 24/7 di latar belakang.'
      : 'Service is actively listening to notifications 24/7 in background.';
  String get gatewayInactiveDesc => isId
      ? 'Akses notifikasi atau optimasi baterai belum disetel. Ketuk panduan di bawah.'
      : 'Notification access or battery optimization is not configured yet. Tap the guide below.';
  String get btnSetupGuide => isId ? 'Panduan Pengaturan' : 'Setup Guide';
  String get statTotalRules => isId ? 'Aturan Aktif' : 'Active Rules';
  String get statReceived => isId ? 'Notifikasi Masuk' : 'Received';
  String get statDispatched => isId ? 'Sukses (2xx)' : 'Success (2xx)';
  String get statFailed => isId ? 'Gagal' : 'Failed';
  String get notifAccessTitle => isId ? 'Akses Notifikasi Sistem' : 'System Notification Access';
  String get batteryTitle => isId ? 'Optimasi Baterai' : 'Battery Optimization';
  String get statusAllowed => isId ? 'Diizinkan ✓' : 'Allowed ✓';
  String get statusDenied => isId ? 'Belum Diizinkan ✗' : 'Denied ✗';
  String get statusUnrestricted => isId ? 'Tidak Dibatasi ✓' : 'Unrestricted ✓';
  String get statusRestricted => isId ? 'Dibatasi ✗' : 'Restricted ✗';
  String get recentActivity => isId ? 'Aktivitas Terakhir' : 'Recent Activity';
  String get noLogsYet => isId ? 'Belum ada log notifikasi yang tertangkap.' : 'No notification logs captured yet.';
  String get simChatTitle => isId ? 'Simulasi Pesan' : 'Message Sim';
  String get simOtpTitle => 'Simulasi OTP';
  String get simAlertTitle => 'Simulasi Alert';
  String get quickSimTitle => isId ? 'Uji Simulasi Notifikasi (Debug)' : 'Notification Simulation (Debug)';
  String get quickSimDesc => isId
      ? 'Simulasi ini hanya muncul saat mode debug untuk memverifikasi parser dan disembunyikan otomatis saat build rilis.'
      : 'Simulation tools only appear in debug mode to verify parser logic and are automatically omitted in release.';
  String get rebindSuccess => isId ? 'Sambungan Listener berhasil disegarkan.' : 'Listener rebind triggered successfully.';
  String get rebindFailed => isId ? 'Gagal merebind listener.' : 'Failed to rebind listener.';
  String get simSuccess => isId ? 'Simulasi diproses! Periksa tab Log Webhook.' : 'Simulation processed! Check Logs tab.';
  String get simFailed => isId ? 'Gagal menjalankan simulasi.' : 'Failed to run simulation.';

  // Rules Screen
  String get rulesTitle => isId ? 'Daftar Aturan Webhook' : 'Webhook Rules List';
  String get btnAddRule => isId ? 'Tambah Aturan' : 'Add Rule';
  String get btnExportConfig => isId ? 'Ekspor Konfigurasi (JSON)' : 'Export Config (JSON)';
  String get btnImportConfig => isId ? 'Impor Konfigurasi' : 'Import Config';
  String get noRulesYet => isId ? 'Belum ada aturan webhook.' : 'No webhook rules yet.';
  String get noRulesDesc => isId
      ? 'Tekan tombol Tambah Aturan di bawah untuk mulai memfilter notifikasi.'
      : 'Tap the Add Rule button below to start filtering notifications.';
  String get ruleSavedSuccess => isId ? 'Aturan berhasil disimpan ke database SQLite.' : 'Rule saved successfully to SQLite database.';
  String get ruleDeletedSuccess => isId ? 'Aturan berhasil dihapus.' : 'Rule deleted successfully.';
  String get deleteConfirmTitle => isId ? 'Hapus Aturan?' : 'Delete Rule?';
  String get deleteConfirmDesc => isId
      ? 'Apakah Anda yakin ingin menghapus aturan ini?'
      : 'Are you sure you want to delete this rule?';
  String get importSuccess => isId ? 'Pengaturan berhasil diimpor ke SQLite!' : 'Configuration successfully imported to SQLite!';
  String get importFailed => isId ? 'Format JSON pengaturan tidak valid.' : 'Invalid JSON configuration format.';
  String get filterLabel => isId ? 'Filter: ' : 'Filter: ';
  String get allNotifNoRegex => isId ? 'Semua notifikasi (Tanpa Regex)' : 'All notifications (No Regex)';
  String get allNotifFilterDesc => allNotifNoRegex;
  String get signatureActive => isId ? 'Signature: HMAC-SHA256 (Aktif)' : 'Signature: HMAC-SHA256 (Active)';
  String get importConfigPrompt => isId
      ? 'Tempelkan konfigurasi JSON aturan/database yang sebelumnya Anda ekspor:'
      : 'Paste the exported JSON configuration below:';

  // Rule Editor
  String get defaultRuleName => isId ? 'Aturan Gateway Notifikasi' : 'Notification Gateway Rule';
  String get defaultSampleText => isId
      ? 'Halo! Pesan penting baru saja diterima dari sistem.'
      : 'Hello! An important message was just received from the system.';
  String get editorTitleAdd => isId ? 'Tambah Aturan Webhook' : 'Add Webhook Rule';
  String get editorTitleEdit => isId ? 'Edit Aturan Webhook' : 'Edit Webhook Rule';
  String get presetsTitle => isId ? 'Template Siap Pakai:' : 'Quick Presets:';
  String get ruleNameLabel => isId ? 'Nama Aturan *' : 'Rule Name *';
  String get ruleNameHint => isId ? 'Misal: Alert Server, Filter Chat, OTP' : 'E.g.: Server Alert, Chat Filter, OTP';
  String get sourceAppLabel => isId
      ? 'Aplikasi Sumber (Package Name atau Nama Aplikasi)'
      : 'Source App (Package Name or App Name)';
  String get sourceAppHint => isId
      ? 'com.example.app (atau kosongkan / ketik * untuk semua aplikasi)'
      : 'com.example.app (or leave empty / type * for all apps)';
  String get chipAll => isId ? 'Semua (*)' : 'All (*)';
  String get btnPickApp => isId ? 'Pilih dari aplikasi terpasang' : 'Pick from installed apps';
  String get dialogPickAppTitle => isId ? 'Pilih Aplikasi Terpasang' : 'Select Installed App';
  String get searchAppHint => isId ? 'Cari aplikasi...' : 'Search app...';
  String get regexLabel => isId ? 'Pola Regex Filter Isi (Opsional)' : 'Content Regex Pattern (Optional)';
  String get regexHint => isId
      ? 'Kosongkan untuk meneruskan semua notifikasi dari aplikasi ini'
      : 'Leave empty to forward all notifications from this app';
  String get regexIgnoreCase => isId ? 'Abaikan Huruf Besar/Kecil (Ignore Case)' : 'Ignore Case';
  String get regexSandboxTitle => isId ? 'Uji Pola dengan Contoh Teks:' : 'Test Pattern with Sample Text:';
  String get sampleNotifTextHint => isId ? 'Contoh teks notifikasi...' : 'Sample notification text...';
  String get regexMatchAll => isId
      ? 'Semua notifikasi dari aplikasi ini akan diteruskan tanpa filter regex.'
      : 'All notifications from this app will be forwarded without regex filter.';
  String regexMatchedCount(int count) => isId
      ? '✓ Cocok! Ditemukan $count grup variabel.'
      : '✓ Matched! Found $count variable groups.';
  String get regexNotMatched => isId
      ? '✗ Pola regex tidak cocok dengan contoh teks.'
      : '✗ Regex pattern did not match sample text.';
  String regexInvalidError(Object err) => isId ? 'Format regex tidak valid: $err' : 'Invalid regex format: $err';
  String groupLabel(int idx, String val) => isId ? '• Grup $idx ({{group$idx}}): "$val"' : '• Group $idx ({{group$idx}}): "$val"';

  String get targetWebhookSection => isId ? 'Pengaturan Webhook Server Tujuan:' : 'Target Webhook Server Configuration:';
  String get webhookUrlLabel => isId ? 'URL Webhook Server Tujuan *' : 'Target Webhook URL *';
  String get httpMethodLabel => isId ? 'Metode HTTP' : 'HTTP Method';
  String get secretKeyLabel => isId ? 'Secret Key (Opsional HMAC-SHA256)' : 'Secret Key (Optional HMAC-SHA256)';
  String get secretKeyHint => isId ? 'Kunci otentikasi header X-Webhook-Signature' : 'Authentication key for X-Webhook-Signature';
  String get maxRetriesLabel => isId ? 'Maksimal Percobaan Ulang (Retry)' : 'Maximum Retries';
  String get btnTestWebhook => isId ? 'Kirim Tes Webhook ke Endpoint' : 'Send Test Webhook to Endpoint';
  String get customPayloadTitle => isId ? 'Kustomisasi Format JSON Payload (Opsional)' : 'Custom JSON Payload (Optional)';
  String get customPayloadDesc => isId
      ? 'Biarkan kosong untuk format JSON standar universal.\nVariabel: {{app_name}}, {{title}}, {{text}}, {{big_text}}, {{timestamp}}, {{datetime}}, {{rule_name}}, {{group1}}'
      : 'Leave empty for default universal JSON payload.\nVariables: {{app_name}}, {{title}}, {{text}}, {{big_text}}, {{timestamp}}, {{datetime}}, {{rule_name}}, {{group1}}';
  String get errRuleNameRequired => isId ? 'Nama aturan wajib diisi.' : 'Rule name is required.';
  String get errWebhookUrlRequired => isId ? 'URL Webhook wajib diisi!' : 'Webhook URL is required!';
  String sendingTestRequest(String url) => isId ? 'Mengirim request uji coba ke $url...' : 'Sending test request to $url...';
  String get testSampleGatewayTitle => isId ? 'Test Gateway Notifikasi' : 'Gateway Notification Test';
  String testSuccessResult(int code, String msg) => isId
      ? '✓ SUKSES HTTP $code\nServer menerima request webhook dengan baik.\nResponse:\n$msg'
      : '✓ SUCCESS HTTP $code\nWebhook server responded successfully.\nResponse:\n$msg';
  String testFailedResult(int code, String msg) => isId
      ? '✗ GAGAL (HTTP $code)\nError: $msg'
      : '✗ FAILED (HTTP $code)\nError: $msg';
  String get retryOption1 => isId ? '1x (Tanpa retry)' : '1x (No retry)';
  String get retryOption3 => isId ? '3x Percobaan bertahap' : '3x Retries with backoff';
  String get retryOption5 => isId ? '5x Percobaan' : '5x Retries';
  List<WebhookRulePreset> get currentPresets => WebhookRule.getPresets(isId);

  // Group Summary & Deduplication
  String get groupSummaryTitle => isId ? 'Abaikan Notifikasi Ringkasan (Group Summary)' : 'Ignore Group Summary Notifications';
  String get groupSummarySubtitle => isId
      ? 'Menyaring ringkasan sistem (seperti "2 pesan baru") agar tidak memicu webhook terpisah. Matikan jika Anda ingin menangkap notifikasi ringkasan.'
      : 'Filters system bundle headers (such as "2 new messages") so they do not trigger separate webhooks. Turn off if you wish to capture summary headers.';
  String get deduplicateTitle => isId ? 'Deduplikasi Pesan Cerdas (Anti Duplikat)' : 'Smart Message Deduplication (Anti-Duplicate)';
  String get deduplicateSubtitle => isId
      ? 'Mencegah pengiriman webhook ganda jika sistem Android/aplikasi mengirim pesan identik berulang dalam selang 2,5 detik.'
      : 'Prevents duplicate webhooks if Android/app dispatches identical events within 2.5 seconds.';

  // Setup Wizard (Strict & Mandatory)
  String get wizardTitle => isId ? 'Izin Wajib Pengaktifan Gateway' : 'Mandatory Gateway Activation';
  String get wizardSubtitle => isId
      ? 'Akses notifikasi sistem wajib diaktifkan agar gateway dapat bekerja.'
      : 'System notification access is mandatory for the gateway to function.';
  String get wizardMandatoryWarningTitle => isId ? 'AKSES NOTIFIKASI WAJIB' : 'NOTIFICATION ACCESS REQUIRED';
  String get wizardMandatoryWarningDesc => isId
      ? 'Aplikasi Notifymee adalah gateway penerus notifikasi ke webhook. Tanpa izin Akses Notifikasi, aplikasi tidak dapat mendeteksi atau memproses notifikasi apapun.\n\nAnda tidak dapat menggunakan atau menjelajahi fitur aplikasi sebelum memberikan izin ini.\n\nSilakan pilih "Buka Pengaturan" untuk mengaktifkan, atau "Keluar Aplikasi".'
      : 'Notifymee is a notification-to-webhook gateway. Without Notification Access, the app cannot intercept or forward any notifications.\n\nYou cannot explore or use the app features before granting this permission.\n\nPlease tap "Open Settings" to enable access, or "Exit App".';
  String get btnExitApp => isId ? 'Keluar Aplikasi' : 'Exit App';
  String get btnContinue => isId ? 'Lanjutkan ke Aplikasi' : 'Continue to App';
  String get btnOpenSettings => isId ? 'Buka Pengaturan Akses Notifikasi' : 'Open Notification Access Settings';
  String get btnGrantBattery => isId ? 'Setel Baterai Tidak Dibatasi' : 'Set Battery to Unrestricted';
  String get btnRebind => isId ? 'Perbarui Sambungan Listener' : 'Rebind Notification Listener';
  String get rebindSuccessNotice => isId ? '✓ Sambungan listener berhasil diperbarui.' : '✓ Listener connection re-established.';
  String get rebindFailedNotice => isId ? 'Gagal memperbarui sambungan listener.' : 'Failed to rebind listener.';
  String get setupCompleteTitle => isId ? 'Semua Pengaturan Siap' : 'Setup Complete';
  String get setupCompleteDesc => isId ? 'Layanan siap memantau notifikasi.' : 'Service is ready to monitor notifications.';
  String get notifAccessStepDesc => isId
      ? 'Izin wajib sistem Android agar gateway dapat mendengarkan notifikasi masuk secara real-time.'
      : 'Mandatory Android permission for the gateway to intercept incoming notifications in real-time.';
  String get checkSettingsAction => isId ? 'Periksa Pengaturan' : 'Check Settings';
  String get restrictedSettingsHeader => isId
      ? 'PENTING: Khusus Android 13, 14, 15, 16 (Setelan Dibatasi)'
      : 'IMPORTANT: Android 13-16 (Restricted Settings)';
  String get restrictedSettingsAndroidDesc => isId
      ? 'Jika switch di Akses Notifikasi berwarna abu-abu (Restricted):\n1. Buka Pengaturan HP -> Aplikasi -> Notifymee.\n2. Tekan ikon titik tiga (⋮) di pojok kanan atas.\n3. Pilih "Izinkan setelan terbatas" (Allow restricted settings).\n4. Masukkan PIN / sidik jari ponsel Anda.'
      : 'If the Notification Access toggle is greyed out (Restricted Setting):\n1. Go to Phone Settings -> Apps -> Notifymee.\n2. Tap the three dots (⋮) in the top-right corner.\n3. Tap "Allow restricted settings".\n4. Authenticate with PIN or fingerprint.';
  String get batteryStepDesc => isId
      ? 'Android mematikan aplikasi saat layar mati. Menyetel menjadi Tidak Dibatasi menjamin gateway bekerja 24/7.'
      : 'Android kills apps when screen is off. Setting to Unrestricted ensures the gateway stays running 24/7.';
  String get rebindStepDesc => isId
      ? 'Jika Anda sudah menyalakan izin tetapi notifikasi belum terkirim ke server, perbarui sambungan listener sistem.'
      : 'If permissions are granted but notifications are not dispatching, refresh the listener service connection.';
  String get vendorSettingTitle => isId ? 'Pengaturan Tambahan Berdasarkan Merk HP' : 'OEM Vendor Settings';
  String get vendorXiaomiDesc => isId
      ? 'Buka Info Aplikasi -> Nyalakan "Mulai Otomatis (Autostart)", setel Penghemat Baterai ke "Tidak ada pembatasan (No restrictions)", dan pastikan aplikasi target TIDAK dikunci di fitur "Kunci Aplikasi (App Lock)".'
      : 'Open App Info -> Turn on "Autostart", set Battery Saver to "No restrictions", and ensure target apps are NOT locked in "App Lock".';
  String get vendorSamsungDesc => isId
      ? 'Pengaturan -> Perawatan Perangkat -> Baterai -> Batas latar belakang -> Masukkan ke "Aplikasi yang tidak pernah tidur", dan jangan kunci target di Secure Folder.'
      : 'Settings -> Device Care -> Battery -> Background limits -> Add to "Never sleeping apps", and avoid Secure Folder for target apps.';
  String get vendorOppoDesc => isId
      ? 'Info Aplikasi -> Penggunaan Baterai -> Izinkan aktivitas latar belakang & izinkan mulai otomatis.'
      : 'App Info -> Battery Usage -> Allow background activity & allow autostart.';
  String get vendorVivoDesc => isId
      ? 'Pengaturan -> Baterai -> Konsumsi daya latar belakang tinggi -> Izinkan Notifymee.'
      : 'Settings -> Battery -> High background power consumption -> Allow Notifymee.';

  // App Lock Warning
  String get appLockWarningTitle => isId ? 'PERHATIAN: Hindari Fitur "Kunci Aplikasi" (App Lock)' : 'WARNING: Avoid "App Lock" Features';
  String get appLockWarningDesc => isId
      ? 'Aplikasi target (misal Telegram, WhatsApp, e-Wallet) TIDAK BOLEH dikunci dengan fitur Kunci Aplikasi bawaan ponsel (Xiaomi HyperOS, Oppo, Samsung Secure Folder). Sistem keamanan HP secara sengaja menyembunyikan dan memblokir notifikasi aplikasi yang terkunci dari semua pembaca notifikasi.'
      : 'Target apps (e.g. Telegram, WhatsApp, banking apps) MUST NOT be locked with OEM App Lock features (Xiaomi HyperOS, Oppo, Samsung Secure Folder). System security intentionally hides and blocks notifications of locked apps from all listener services.';

  // Logs Screen
  String get logsTitle => isId ? 'Riwayat Log Webhook' : 'Webhook Dispatch Logs';
  String get filterAll => isId ? 'Semua' : 'All';
  String get filterSuccess => isId ? 'Sukses' : 'Success';
  String get filterFailed => isId ? 'Gagal' : 'Failed';
  String get filterSkipped => isId ? 'Dilewati' : 'Skipped';
  String get btnClearLogs => isId ? 'Hapus Semua Log' : 'Clear All Logs';
  String get clearLogsConfirm => isId ? 'Hapus semua riwayat log di SQLite?' : 'Clear all log history from SQLite?';
  String get btnResend => isId ? 'Kirim Ulang Webhook' : 'Resend Webhook';
  String get statusProcessed => isId ? 'TERKIRIM' : 'DISPATCHED';
  String get statusSkippedBadge => isId ? 'DILEWATI' : 'SKIPPED';
  String get statusFailedBadge => isId ? 'GAGAL' : 'FAILED';
  String get modalPayloadDetail => isId ? 'Detail Payload Webhook' : 'Webhook Payload Detail';
  String get searchLogsHint => isId ? 'Cari judul, isi, atau aplikasi...' : 'Search title, content, or app...';
  String get noMatchingLogs => isId ? 'Tidak ada log yang sesuai pencarian.' : 'No matching logs found.';
  String dispatchedSuccess(int code) => isId ? 'Terkirim Sukses (HTTP $code)' : 'Dispatched Successfully (HTTP $code)';
  String get dispatchFailed => isId ? 'Pengiriman Webhook Gagal' : 'Webhook Dispatch Failed';
  String get notificationSkipped => isId ? 'Notifikasi Dilewati (Filter)' : 'Notification Skipped (Filter)';
  String latencyLabel(int ms) => isId ? 'Respon: $ms ms' : 'Latency: $ms ms';
  String errorMessageLabel(String msg) => isId ? 'Pesan: $msg' : 'Message: $msg';
  String get sectionIncomingInfo => isId ? 'Informasi Notifikasi Masuk' : 'Incoming Notification Info';
  String get fieldAppPackage => isId ? 'Aplikasi (Package):' : 'App (Package):';
  String get fieldTitle => isId ? 'Judul:' : 'Title:';
  String get fieldEmpty => isId ? '(Kosong)' : '(Empty)';
  String get fieldMessageContent => isId ? 'Isi Pesan:' : 'Message Content:';
  String get fieldReceivedTime => isId ? 'Waktu Diterima:' : 'Received Time:';
  String get sectionRuleWebhook => isId ? 'Aturan & Target Webhook' : 'Rule & Webhook Target';
  String get fieldMatchedRule => isId ? 'Aturan Cocok:' : 'Matched Rule:';
  String get sectionPayloadSent => isId ? 'Payload JSON Terkirim ke Webhook' : 'JSON Payload Sent to Webhook';

  // System & Architecture Guide
  String get guideTitle => isId ? 'Panduan & Cara Kerja Sistem' : 'System Guide & Architecture';
  String get guideAndroidTitle => isId ? 'Pengaturan Gateway HP Android' : 'Android Gateway Setup';
  String get guideAndroidDesc => isId
      ? 'Panduan langkah demi langkah agar aplikasi dapat memantau notifikasi 24/7 di latar belakang tanpa terhenti oleh sistem baterai.'
      : 'Step-by-step instructions so the application monitors notifications 24/7 in background without battery interruptions.';
  String get guideAppleTitle => isId ? 'Batasan Keamanan Apple Sandbox (iOS)' : 'Apple Sandbox Security Limitations (iOS)';
  String get guideAppleDesc => isId
      ? 'Pada sistem operasi iOS (iPhone/iPad non-jailbreak), Apple menerapkan isolasi aplikasi (sandboxing) yang sangat ketat.\n\nSecara teknis, TIDAK ADA API resmi pada iOS yang mengizinkan aplikasi pihak ketiga untuk menyadap atau membaca notifikasi milik aplikasi lain (seperti notifikasi pesan atau perbankan).'
      : 'On iOS devices (iPhone/iPad non-jailbreak), Apple enforces strict application sandboxing.\n\nTechnically, there is NO public API on iOS that allows a third-party app to read or intercept notifications belonging to other applications.';
  String get guideShortcutsTitle => isId ? 'Alternatif SMS di iPhone (Apple Shortcuts)' : 'iPhone SMS Alternative (Apple Shortcuts)';
  String get guideShortcutsDesc => isId
      ? 'Jika Anda menggunakan iPhone dan ingin meneruskan SMS ke webhook, gunakan fitur bawaan Apple Shortcuts:\n\n1. Buka aplikasi Shortcuts (Pintasan).\n2. Tab Otomatisasi (Automation) -> Buat Otomatisasi Pribadi.\n3. Pilih pemicu: Pesan (Message).\n4. Tindakan: Dapatkan Isi URL (POST request ke webhook URL Anda).\n5. Matikan "Tanya Sebelum Menjalankan".'
      : 'If using an iPhone to forward incoming SMS to a webhook, utilize Apple Shortcuts:\n\n1. Open Shortcuts app.\n2. Tap Automation -> Create Personal Automation.\n3. Choose trigger: Message.\n4. Action: Get Contents of URL (POST request to your webhook URL).\n5. Turn off "Ask Before Running".';
  String get guidePayloadTitle => isId ? 'Format JSON Payload Universal' : 'Universal JSON Payload Format';
  String get guidePayloadDesc => isId
      ? 'Payload standar universal yang dikirimkan oleh Notifymee ke endpoint webhook server Anda:'
      : 'Standard universal JSON payload dispatched by Notifymee to your webhook endpoint:';
  String get guideNodeTitle => isId ? 'Contoh Server Handler (Node.js Express)' : 'Sample Server Handler (Node.js Express)';
  String get guidePhpTitle => isId ? 'Contoh Server Handler (PHP)' : 'Sample Server Handler (PHP)';

  // App Notifications Disabled Warning
  String get appNotifDisabledTitle => isId
      ? 'Notifikasi Notifymee Dinonaktifkan di Pengaturan HP'
      : 'Notifymee Notifications Disabled in Settings';
  String get appNotifDisabledDesc => isId
      ? 'Aplikasi mati saat ditutup dari layar aplikasi berjalan karena izin notifikasi untuk Notifymee dimatikan. Android & HyperOS mewajibkan notifikasi Foreground Service aktif agar gateway tidak dimatikan saat aplikasi ditutup.'
      : 'The app dies after being swiped from Recents because notifications for Notifymee are turned off. Android requires an active Foreground Service notification to keep the gateway running 24/7.';
  String get appNotifDisabledTip => isId
      ? 'Tips: Agar tidak memenuhi bilah status, ubah notifikasi Notifymee menjadi Hening / Senyap (Silent / Non-intrusive) di setelan HP, jangan dimatikan izinnya secara total.'
      : 'Tip: To keep the status bar clean without breaking background monitoring, set Notifymee notifications to Silent / Non-intrusive in phone settings instead of disabling them completely.';
  String get btnOpenAppNotifSettings => isId ? 'Buka Pengaturan Notifikasi HP' : 'Open Phone Notification Settings';

  // Per-Package Blacklist & Exclude
  String get btnBlacklistThis => isId ? 'Blacklist / Exclude Notifikasi Serupa' : 'Blacklist / Exclude Similar Notifications';
  String get blacklistDialogTitle => isId ? 'Blacklist Notifikasi untuk' : 'Blacklist Notification for';
  String get blacklistDialogDesc => isId
      ? 'Notifikasi dari aplikasi ini yang mengandung teks atau kata kunci ini akan otomatis diabaikan (tidak dikirim ke webhook).'
      : 'Notifications from this app matching this text will be automatically ignored (never sent to webhook).';
  String get blacklistPatternLabel => isId ? 'Pola Teks / Kata Kunci Blacklist:' : 'Blacklist Text / Keyword Pattern:';
  String get blacklistPatternHint => isId ? 'Misal: Memeriksa pesan baru, status...' : 'E.g.: Checking for new messages, status...';
  String get btnAddToBlacklist => isId ? 'Tambahkan ke Blacklist' : 'Add to Blacklist';
  String get blacklistSuccess => isId ? 'Berhasil ditambahkan ke Blacklist aplikasi!' : 'Successfully added to app blacklist!';
  String get blacklistDeleted => isId ? 'Pola blacklist berhasil dihapus.' : 'Blacklist entry deleted.';
  String get blacklistTitle => isId ? 'Daftar Blacklist / Pengecualian Kata Kunci' : 'Blacklist / Exclude Keywords';
  String get noBlacklistItems => isId ? 'Belum ada teks yang diblacklist untuk aplikasi ini.' : 'No blacklisted patterns for this app yet.';
  String get btnManageBlacklist => isId ? 'Kelola Blacklist' : 'Manage Blacklist';
  String get blacklistNoticeDesc => isId
      ? 'Notifikasi dengan kata kunci ini akan otomatis diabaikan (tidak dikirim ke webhook).'
      : 'Future notifications matching this text pattern will be automatically skipped.';
  String get blacklistAllAppsTitle => isId ? 'Daftar Blacklist Kata Kunci' : 'Keyword Blacklist';
  String get blacklistAllAppsSubtitle => isId
      ? 'Notifikasi dari aplikasi berikut yang cocok dengan pola kata kunci akan otomatis diabaikan.'
      : 'Notifications from these apps matching the pattern will be ignored.';
  String get blacklistEmptyTotal => isId
      ? 'Belum ada kata kunci yang diblacklist.\n\nTips: Buka riwayat Log -> ketuk log notifikasi status (seperti "Memeriksa pesan baru") -> ketuk tombol "Blacklist / Exclude Notifikasi Serupa".'
      : 'No keywords blacklisted yet.\n\nTip: Open Logs -> tap a status log (e.g. "Checking for new messages") -> tap "Blacklist / Exclude Similar Notifications".';
  String get confirmDeleteBlacklist => isId ? 'Hapus pola blacklist ini?' : 'Delete this blacklist pattern?';
  String get btnAddNewBlacklist => isId ? 'Tambah Blacklist Manual' : 'Add Manual Blacklist';

  // Background Architecture & Lock App Guide
  String get guideArchComparisonTitle => isId
      ? 'Mengapa Notifymee Berbeda dengan WhatsApp / Telegram?'
      : 'Why Notifymee Differs from WhatsApp / Telegram';
  String get guideArchComparisonDesc => isId
      ? 'Aplikasi chatting seperti WhatsApp atau Telegram TIDAK berjalan terus-menerus di memori saat ditutup. Mereka menggunakan Google Play Services (FCM Push Cloud) yang dibangunkan server Google kurang dari 1 detik hanya saat ada pesan masuk.\n\nSebaliknya, Notifymee bertugas membaca notifikasi milik aplikasi lain langsung di dalam sistem HP (On-Device Notification Gateway). Tidak ada server cloud yang tahu apa notifikasi di layar HP Anda selain sistem internal HP itu sendiri. Oleh karena itu, Notifymee wajib mempertahankan koneksi sistem lokal (NotificationListenerService) secara realtime 24/7 di latar belakang.'
      : 'Chat apps like WhatsApp or Telegram do NOT run continuously in RAM when swiped away. They utilize Google Play Services (FCM Push Cloud) which wakes them up for under a second only when a message arrives.\n\nConversely, Notifymee operates as an On-Device Notification Gateway reading other apps\' notifications directly inside the phone. No cloud server knows what notifications appear on your screen. Therefore, Notifymee must maintain a continuous local listener connection (NotificationListenerService) 24/7 in memory.';

  String get guideKeepAliveTitle => isId
      ? 'Panduan: Kunci Notifymee di Layar Aplikasi Berjalan (Recent Apps)'
      : 'Guide: Lock Notifymee in Recent Apps Screen';
  String get guideKeepAliveSubtitle => isId
      ? 'Jika ingin aplikasi kebal saat dibersihkan dari layar recent apps:'
      : 'To prevent the app from being stopped when cleaning recent apps:';
  String get guideLockStep1 => isId
      ? 'Buka layar Recent Apps (daftar aplikasi berjalan / multitasking).'
      : 'Open the Recent Apps / Multitasking screen.';
  String get guideLockStep2 => isId
      ? 'Tekan dan tahan (atau tarik ke bawah) pada jendela kartu Notifymee.'
      : 'Press and hold (or drag down) on the Notifymee app card.';
  String get guideLockStep3 => isId
      ? 'Ketuk ikon Gembok (Lock 🔒) sampai ikon gembok muncul di pojok kartu.'
      : 'Tap the Padlock icon (Lock 🔒) until the padlock symbol appears on the card.';
  String get guideLockStep4 => isId
      ? 'Selesai! Notifymee kini tidak akan dibunuh saat tombol "Bersihkan Semua" (Clear All) ditekan.'
      : 'Done! Notifymee will now remain active even when "Clear All" is pressed.';
  String get guideKeepAliveAltNote => isId
      ? 'Alternatif tanpa mengunci aplikasi: Pastikan izin notifikasi Notifymee di pengaturan HP tetap menyala (boleh disetel Hening/Senyap agar tidak ada pop-up). Notifikasi tersebut berfungsi sebagai jangkar Foreground Service agar sistem Android tidak membunuh layanan gateway.'
      : 'Alternative without locking: Ensure Notifymee\'s app notification permission remains ON in phone settings (you can set it to Silent so it does not clutter the status bar). This notification serves as a Foreground Service anchor preventing Android from terminating the gateway.';
}
