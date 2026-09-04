import 'package:cloud_firestore/cloud_firestore.dart';

class GameModeModel {
  final String id;
  final String title;
  final String bannerUrl;
  final int order;
  final bool isActive;
  final DateTime createdAt;

  GameModeModel({
    required this.id,
    required this.title,
    required this.bannerUrl,
    this.order = 1,
    this.isActive = true,
    required this.createdAt,
  });

  factory GameModeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GameModeModel.fromMap(data, doc.id);
  }

  factory GameModeModel.fromMap(Map<String, dynamic> data, String docId) {
    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        parsedDate = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        parsedDate = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
      }
    }

    final rawOrder = data['order'];
    int parsedOrder = 1;
    if (rawOrder is int) {
      parsedOrder = rawOrder;
    } else if (rawOrder is double) {
      parsedOrder = rawOrder.toInt();
    } else if (rawOrder != null) {
      parsedOrder = int.tryParse(rawOrder.toString()) ?? 1;
    }

    return GameModeModel(
      id: docId,
      title: (data['title'] ?? '').toString(),
      bannerUrl: (data['bannerUrl'] ?? '').toString(),
      order: parsedOrder,
      isActive: data['isActive'] == true || data['isActive'] == null,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'bannerUrl': bannerUrl,
      'order': order,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
