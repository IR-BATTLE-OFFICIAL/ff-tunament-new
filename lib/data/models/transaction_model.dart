import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String type; // deposit, withdrawal, prize, entry_fee
  final DateTime dateTime;
  final String status; // success, pending, failed
  final String? description;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.dateTime,
    required this.status,
    this.description,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      type: data['type'] ?? 'deposit',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'success',
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type,
      'dateTime': dateTime,
      'status': status,
      'description': description,
    };
  }
}
