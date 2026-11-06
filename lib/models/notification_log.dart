class NotificationLog {
  final String id;
  final int timestamp;
  final String datetime;
  final String packageName;
  final String title;
  final String text;
  final bool matched;
  final String matchedRuleName;
  final String webhookUrl;
  final int httpStatus;
  final String responseBody;
  final String errorMessage;
  final int latencyMs;
  final String payloadSent;
  final String notificationKey;
  final String status;
  final bool isGroupSummary;

  NotificationLog({
    required this.id,
    required this.timestamp,
    required this.datetime,
    required this.packageName,
    required this.title,
    required this.text,
    required this.matched,
    required this.matchedRuleName,
    required this.webhookUrl,
    required this.httpStatus,
    required this.responseBody,
    required this.errorMessage,
    required this.latencyMs,
    required this.payloadSent,
    this.notificationKey = '',
    this.status = '',
    this.isGroupSummary = false,
  });

  factory NotificationLog.fromJson(Map<String, dynamic> json) {
    return NotificationLog(
      id: json['id']?.toString() ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      datetime: json['datetime']?.toString() ?? '',
      packageName: json['packageName']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      matched: json['matched'] as bool? ?? false,
      matchedRuleName: json['matchedRuleName']?.toString() ?? '',
      webhookUrl: json['webhookUrl']?.toString() ?? '',
      httpStatus: (json['httpStatus'] as num?)?.toInt() ?? 0,
      responseBody: json['responseBody']?.toString() ?? '',
      errorMessage: json['errorMessage']?.toString() ?? '',
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
      payloadSent: json['payloadSent']?.toString() ?? '',
      notificationKey: json['notificationKey']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      isGroupSummary: json['isGroupSummary'] as bool? ?? false,
    );
  }

  bool get isSuccess => status == 'SUCCESS' || (httpStatus >= 200 && httpStatus < 300);
  bool get isFailed => status == 'FAILED' || (matched && (httpStatus == 0 || httpStatus >= 400 || errorMessage.isNotEmpty));
  bool get isSkipped => status == 'SKIPPED' || !matched;
}

