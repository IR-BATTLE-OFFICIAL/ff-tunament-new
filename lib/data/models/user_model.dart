import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? name;
  final String? email;
  final String? phone;
  final String? ffUid;
  final String? profilePic;
  final double balance;
  final double bonusBalance;
  final int totalWins;
  final double totalEarnings;
  final String? referralCode;
  final String? referredBy;
  final bool isAdmin;
  final bool hideAdminIdentity;
  final bool isBlocked;
  final bool isHighlighted;
  final int leaderboardPriority;
  final int unreadNotifications;
  final String? deviceId;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    this.name,
    this.email,
    this.phone,
    this.ffUid,
    this.profilePic,
    this.balance = 0.0,
    this.bonusBalance = 0.0,
    this.totalWins = 0,
    this.totalEarnings = 0.0,
    this.referralCode,
    this.referredBy,
    this.isAdmin = false,
    this.hideAdminIdentity = false,
    this.isBlocked = false,
    this.isHighlighted = false,
    this.leaderboardPriority = 0,
    this.unreadNotifications = 0,
    this.deviceId,
    this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel(
      uid: doc.id,
      name: data['name'],
      email: data['email'],
      phone: data['phone'],
      ffUid: data['ffUid'],
      profilePic: data['profilePic'],
      balance: (data['balance'] ?? 0.0).toDouble(),
      bonusBalance: (data['bonusBalance'] ?? 0.0).toDouble(),
      totalWins: data['totalWins'] ?? 0,
      totalEarnings: (data['totalEarnings'] ?? 0.0).toDouble(),
      referralCode: data['referralCode'],
      referredBy: data['referredBy'],
      isAdmin: data['isAdmin'] ?? false,
      hideAdminIdentity: data['hideAdminIdentity'] ?? false,
      isBlocked: data['isBlocked'] ?? false,
      isHighlighted: data['isHighlighted'] ?? false,
      leaderboardPriority: data['leaderboardPriority'] ?? 0,
      unreadNotifications: data['unreadNotifications'] ?? 0,
      deviceId: data['deviceId'],
      createdAt: data['createdAt'] != null && data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'ffUid': ffUid,
      'profilePic': profilePic,
      'balance': balance,
      'bonusBalance': bonusBalance,
      'totalWins': totalWins,
      'totalEarnings': totalEarnings,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'isAdmin': isAdmin,
      'hideAdminIdentity': hideAdminIdentity,
      'isBlocked': isBlocked,
      'isHighlighted': isHighlighted,
      'leaderboardPriority': leaderboardPriority,
      'unreadNotifications': unreadNotifications,
      'deviceId': deviceId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
