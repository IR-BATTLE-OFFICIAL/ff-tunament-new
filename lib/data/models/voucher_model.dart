import 'package:cloud_firestore/cloud_firestore.dart';

class VoucherModel {
  final String id;
  final String code;
  final String type; // 'deposit_bonus', 'free_entry', 'discount'
  final double value; // Percentage for bonus, amount for discount, or 0 for free_entry
  final double? minAmount; // Minimum deposit amount for deposit_bonus
  final DateTime expiryDate;
  final bool isActive;
  final int usageLimit; // Max times this voucher can be used in total
  final int usedCount;
  final List<String> usedBy; // List of user IDs who have used this

  VoucherModel({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    this.minAmount,
    required this.expiryDate,
    this.isActive = true,
    this.usageLimit = 100,
    this.usedCount = 0,
    this.usedBy = const [],
  });

  factory VoucherModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return VoucherModel(
      id: doc.id,
      code: data['code'] ?? '',
      type: data['type'] ?? 'deposit_bonus',
      value: (data['value'] ?? 0.0).toDouble(),
      minAmount: data['minAmount'] != null ? (data['minAmount'] as num).toDouble() : null,
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      usageLimit: data['usageLimit'] ?? 100,
      usedCount: data['usedCount'] ?? 0,
      usedBy: List<String>.from(data['usedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code.toUpperCase(),
      'type': type,
      'value': value,
      'minAmount': minAmount,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'isActive': isActive,
      'usageLimit': usageLimit,
      'usedCount': usedCount,
      'usedBy': usedBy,
    };
  }
}
