class WebhookRule {
  String id;
  String name;
  bool enabled;
  String packageName; // Empty or "*" means all apps
  String regexPattern;
  bool regexIgnoreCase;
  String webhookUrl;
  String httpMethod; // "POST", "GET", "PUT"
  Map<String, String> headers;
  String customPayload;
  bool sendOnlyIfMatched;
  String secretKey;
  int maxRetries;
  bool ignoreGroupSummary;
  bool deduplicateMessages;
  bool ignoreOngoing;
  int cooldownSeconds;

  WebhookRule({
    required this.id,
    required this.name,
    this.enabled = true,
    this.packageName = '',
    this.regexPattern = '',
    this.regexIgnoreCase = true,
    required this.webhookUrl,
    this.httpMethod = 'POST',
    Map<String, String>? headers,
    this.customPayload = '',
    this.sendOnlyIfMatched = true,
    this.secretKey = '',
    this.maxRetries = 3,
    this.ignoreGroupSummary = true,
    this.deduplicateMessages = true,
    this.ignoreOngoing = true,
    this.cooldownSeconds = 0,
  }) : headers = headers ?? {'Content-Type': 'application/json'};

  factory WebhookRule.fromJson(Map<String, dynamic> json) {
    Map<String, String> parsedHeaders = {};
    if (json['headers'] != null && json['headers'] is Map) {
      json['headers'].forEach((k, v) {
        parsedHeaders[k.toString()] = v.toString();
      });
    } else {
      parsedHeaders['Content-Type'] = 'application/json';
    }

    return WebhookRule(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Aturan Baru',
      enabled: json['enabled'] as bool? ?? true,
      packageName: json['packageName']?.toString() ?? '',
      regexPattern: json['regexPattern']?.toString() ?? '',
      regexIgnoreCase: json['regexIgnoreCase'] as bool? ?? true,
      webhookUrl: json['webhookUrl']?.toString() ?? '',
      httpMethod: json['httpMethod']?.toString() ?? 'POST',
      headers: parsedHeaders,
      customPayload: json['customPayload']?.toString() ?? '',
      sendOnlyIfMatched: json['sendOnlyIfMatched'] as bool? ?? true,
      secretKey: json['secretKey']?.toString() ?? '',
      maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 3,
      ignoreGroupSummary: json['ignoreGroupSummary'] as bool? ?? true,
      deduplicateMessages: json['deduplicateMessages'] as bool? ?? true,
      ignoreOngoing: json['ignoreOngoing'] as bool? ?? true,
      cooldownSeconds: (json['cooldownSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  factory WebhookRule.fromMap(Map<String, dynamic> map) => WebhookRule.fromJson(map);

  Map<String, dynamic> toMap() => toJson();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'packageName': packageName,
      'regexPattern': regexPattern,
      'regexIgnoreCase': regexIgnoreCase,
      'webhookUrl': webhookUrl,
      'httpMethod': httpMethod,
      'headers': headers,
      'customPayload': customPayload,
      'sendOnlyIfMatched': sendOnlyIfMatched,
      'secretKey': secretKey,
      'maxRetries': maxRetries,
      'ignoreGroupSummary': ignoreGroupSummary,
      'deduplicateMessages': deduplicateMessages,
      'ignoreOngoing': ignoreOngoing,
      'cooldownSeconds': cooldownSeconds,
    };
  }

  WebhookRule copyWith({
    String? id,
    String? name,
    bool? enabled,
    String? packageName,
    String? regexPattern,
    bool? regexIgnoreCase,
    String? webhookUrl,
    String? httpMethod,
    Map<String, String>? headers,
    String? customPayload,
    bool? sendOnlyIfMatched,
    String? secretKey,
    int? maxRetries,
    bool? ignoreGroupSummary,
    bool? deduplicateMessages,
    bool? ignoreOngoing,
    int? cooldownSeconds,
  }) {
    return WebhookRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      packageName: packageName ?? this.packageName,
      regexPattern: regexPattern ?? this.regexPattern,
      regexIgnoreCase: regexIgnoreCase ?? this.regexIgnoreCase,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      httpMethod: httpMethod ?? this.httpMethod,
      headers: headers ?? Map.from(this.headers),
      customPayload: customPayload ?? this.customPayload,
      sendOnlyIfMatched: sendOnlyIfMatched ?? this.sendOnlyIfMatched,
      secretKey: secretKey ?? this.secretKey,
      maxRetries: maxRetries ?? this.maxRetries,
      ignoreGroupSummary: ignoreGroupSummary ?? this.ignoreGroupSummary,
      deduplicateMessages: deduplicateMessages ?? this.deduplicateMessages,
      ignoreOngoing: ignoreOngoing ?? this.ignoreOngoing,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
    );
  }

  static List<WebhookRulePreset> getPresets(bool isIndonesian) {
    if (isIndonesian) return presets;
    return [
      WebhookRulePreset(
        title: 'Forward All (*)',
        description: 'Forward all incoming notifications without app or regex filter.',
        packageName: '*',
        regexPattern: '',
        sampleTitle: 'System Notification',
        sampleText: 'Hello! This is a sample notification text.',
      ),
      WebhookRulePreset(
        title: 'Keyword Filter',
        description: 'Forward if notification contains specific keywords.',
        packageName: '*',
        regexPattern: r'(?i)(alert|urgent|warning|important|update)',
        sampleTitle: 'System Alert',
        sampleText: 'ALERT: Server maintenance has been scheduled.',
      ),
      WebhookRulePreset(
        title: 'OTP / 2FA Extraction',
        description: 'Detect and extract verification token via named group (?<otp>...).',
        packageName: '*',
        regexPattern: r'(?i)(?:code|otp|token|pin)[\s:]+(?<otp>[A-Za-z0-9]{4,8})',
        sampleTitle: 'Security Code',
        sampleText: 'Your verification code is 849201. Valid for 5 minutes.',
      ),
      WebhookRulePreset(
        title: 'Error & Failure Filter',
        description: 'Capture alerts containing error status or exception.',
        packageName: '*',
        regexPattern: r'(?i)(error|failed|timeout|exception)',
        sampleTitle: 'Service Report',
        sampleText: 'ERROR: Database connection timeout occurred.',
      ),
      WebhookRulePreset(
        title: 'Numeric Value Extraction',
        description: 'Extract monetary or numeric values via (?<amount>...).',
        packageName: '*',
        regexPattern: r'(?:Rp|IDR|\$|\b)\s*(?<amount>[\d\.,]+)',
        sampleTitle: 'Transaction Data',
        sampleText: 'A payment of \$50.00 has been successfully processed.',
      ),
    ];
  }

  static List<WebhookRulePreset> presets = [
    WebhookRulePreset(
      title: 'Teruskan Semua (*)',
      description: 'Meneruskan semua notifikasi yang masuk tanpa filter aplikasi atau regex.',
      packageName: '*',
      regexPattern: '',
      sampleTitle: 'Notifikasi Sistem',
      sampleText: 'Halo! Ini adalah contoh teks notifikasi.',
    ),
    WebhookRulePreset(
      title: 'Filter Kata Kunci',
      description: 'Meneruskan jika notifikasi mengandung kata kunci penting tertentu.',
      packageName: '*',
      regexPattern: r'(?i)(alert|urgent|peringatan|penting|update)',
      sampleTitle: 'Pemberitahuan Sistem',
      sampleText: 'ALERT: Pembaruan data penting telah selesai diproses.',
    ),
    WebhookRulePreset(
      title: 'Ekstraksi Kode OTP / 2FA',
      description: 'Mendeteksi dan mengekstrak kode verifikasi ke variabel {{otp}} dan {{group1}}.',
      packageName: '*',
      regexPattern: r'(?i)(?:kode|otp|token|code)[\s:]+(?<otp>[A-Za-z0-9]{4,8})',
      sampleTitle: 'Kode Keamanan',
      sampleText: 'Kode verifikasi Anda adalah 849201. Berlaku selama 5 menit.',
    ),
    WebhookRulePreset(
      title: 'Filter Error & Kegagalan',
      description: 'Menangkap pesan peringatan yang berisi status error atau kegagalan sistem.',
      packageName: '*',
      regexPattern: r'(?i)(error|failed|gagal|timeout|exception)',
      sampleTitle: 'Laporan Layanan',
      sampleText: 'ERROR: Koneksi jaringan terputus saat sinkronisasi data.',
    ),
    WebhookRulePreset(
      title: 'Ekstraksi Nilai Angka / QRIS',
      description: 'Mengekstrak nominal angka ke variabel {{amount}} dan {{group1}}.',
      packageName: '*',
      regexPattern: r'(?:Rp|IDR|\$|\b)\s*(?<amount>[\d\.,]+)',
      sampleTitle: 'Notifikasi Data',
      sampleText: 'Pembayaran QRIS sebesar Rp 50.000 telah berhasil diterima.',
    ),
  ];
}

class WebhookRulePreset {
  final String title;
  final String description;
  final String packageName;
  final String regexPattern;
  final String sampleTitle;
  final String sampleText;

  WebhookRulePreset({
    required this.title,
    required this.description,
    required this.packageName,
    required this.regexPattern,
    required this.sampleTitle,
    required this.sampleText,
  });
}
