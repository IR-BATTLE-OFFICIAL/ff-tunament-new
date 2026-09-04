import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationModel {
  final String id;
  final String tournamentId;
  final String userId;
  final String userName;
  final String? userProfilePic;
  final String ffUid;
  final String teamName;
  final List<String> playerDetails;
  final DateTime registrationDate;
  final String status; // confirmed, pending, cancelled
  final bool prizePaid;
  final bool killPrizePaid;
  final int slotNumber; // Which slot this registration occupies (1-based, 0 = no slot assigned)
  final bool isArchived;
  final bool isCompletedHistory;

  RegistrationModel({
    required this.id,
    required this.tournamentId,
    required this.userId,
    required this.userName,
    this.userProfilePic,
    required this.ffUid,
    required this.teamName,
    required this.playerDetails,
    required this.registrationDate,
    required this.status,
    this.prizePaid = false,
    this.killPrizePaid = false,
    this.slotNumber = 0,
    this.isArchived = false,
    this.isCompletedHistory = false,
  });

  factory RegistrationModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return RegistrationModel(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Player',
      userProfilePic: data['userProfilePic'],
      ffUid: data['ffUid'] ?? '',
      teamName: data['teamName'] ?? '',
      playerDetails: List<String>.from(data['playerDetails'] ?? []),
      registrationDate: (data['registrationDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      prizePaid: data['prizePaid'] ?? false,
      killPrizePaid: data['killPrizePaid'] ?? false,
      slotNumber: data['slotNumber'] ?? 0,
      isArchived: data['isArchived'] ?? false,
      isCompletedHistory: data['isCompletedHistory'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'userId': userId,
      'userName': userName,
      'userProfilePic': userProfilePic,
      'ffUid': ffUid,
      'teamName': teamName,
      'playerDetails': playerDetails,
      'registrationDate': registrationDate,
      'status': status,
      'prizePaid': prizePaid,
      'killPrizePaid': killPrizePaid,
      'slotNumber': slotNumber,
      'isArchived': isArchived,
      'isCompletedHistory': isCompletedHistory,
    };
  }

  bool get isCancelled => status.toLowerCase() == 'cancelled';
}
