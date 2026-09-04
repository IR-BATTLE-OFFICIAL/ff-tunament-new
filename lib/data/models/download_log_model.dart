import 'package:cloud_firestore/cloud_firestore.dart';

class DownloadLog {
  final String id;
  final String architecture;
  final DateTime timestamp;
  final String userAgent;
  final String platform;

  DownloadLog({
    required this.id,
    required this.architecture,
    required this.timestamp,
    required this.userAgent,
    required this.platform,
  });

  factory DownloadLog.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DownloadLog(
      id: doc.id,
      architecture: data['architecture'] ?? 'unknown',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userAgent: data['userAgent'] ?? 'unknown',
      platform: data['platform'] ?? 'unknown',
    );
  }
}
