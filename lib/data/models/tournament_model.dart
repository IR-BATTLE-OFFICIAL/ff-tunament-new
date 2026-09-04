import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentModel {
  final String id;
  final String title;
  final String imageUrl;
  final DateTime dateTime;
  final double entryFee;
  final double prizePool;
  final double booyahPool;
  final double perKillPrize;
  final String matchType; // Solo, Duo, Squad
  final String mode; // CS Rank, BR Rank, Lone Wolf
  /// The Firestore ID of the game mode selected by the admin.  Keeping this
  /// alongside [mode] means renamed modes still show their tournaments.
  final String? gameModeId;
  final String map;
  final int totalSlots;
  final int filledSlots;
  final String version; // Mobile, PC
  final String status; // upcoming, live, completed
  final String? roomId;
  final String? roomPassword;
  final String rules;
  final bool isMega;
  final bool isFree;
  final String? winnerId;
  final String? winnerName;
  final String? liveStreamUrl;
  final String? platform; // youtube, rooter, locoe, etc.
  final String? resultImageUrl;
  final bool isAdminDeleted;

  TournamentModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.dateTime,
    required this.entryFee,
    required this.prizePool,
    this.booyahPool = 0.0,
    this.perKillPrize = 0.0,
    required this.matchType,
    required this.mode,
    this.gameModeId,
    required this.map,
    required this.totalSlots,
    required this.filledSlots,
    required this.version,
    required this.status,
    this.roomId,
    this.roomPassword,
    required this.rules,
    this.isMega = false,
    this.isFree = false,
    this.winnerId,
    this.winnerName,
    this.liveStreamUrl,
    this.platform,
    this.resultImageUrl,
    this.isAdminDeleted = false,
  });

  factory TournamentModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    
    DateTime dt;
    final dtVal = data['dateTime'];
    if (dtVal is Timestamp) {
      dt = dtVal.toDate();
    } else if (dtVal is String) {
      dt = DateTime.tryParse(dtVal) ?? DateTime.now();
    } else if (dtVal is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(dtVal);
    } else {
      dt = DateTime.now();
    }

    return TournamentModel(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      dateTime: dt,
      entryFee: (data['entryFee'] as num?)?.toDouble() ?? 0.0,
      prizePool: (data['prizePool'] as num?)?.toDouble() ?? 0.0,
      booyahPool: (data['booyahPool'] as num?)?.toDouble() ?? 0.0,
      perKillPrize: (data['perKillPrize'] as num?)?.toDouble() ?? 0.0,
      matchType: (data['matchType'] ?? 'Solo').toString(),
      mode: (data['mode'] ?? 'BR Rank').toString(),
      gameModeId: data['gameModeId']?.toString(),
      map: (data['map'] ?? 'Bermuda').toString(),
      totalSlots: (data['totalSlots'] as num?)?.toInt() ?? 0,
      filledSlots: (data['filledSlots'] as num?)?.toInt() ?? 0,
      version: (data['version'] ?? 'Mobile').toString(),
      status: (data['status'] ?? 'upcoming').toString(),
      roomId: data['roomId']?.toString(),
      roomPassword: data['roomPassword']?.toString(),
      rules: (data['rules'] ?? '').toString(),
      isMega: data['isMega'] == true,
      isFree: data['isFree'] == true,
      winnerId: data['winnerId']?.toString(),
      winnerName: data['winnerName']?.toString(),
      liveStreamUrl: data['liveStreamUrl']?.toString(),
      platform: data['platform']?.toString(),
      resultImageUrl: data['resultImageUrl']?.toString(),
      isAdminDeleted: data['isAdminDeleted'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'dateTime': dateTime,
      'entryFee': entryFee,
      'prizePool': prizePool,
      'booyahPool': booyahPool,
      'perKillPrize': perKillPrize,
      'matchType': matchType,
      'mode': mode,
      'gameModeId': gameModeId,
      'map': map,
      'totalSlots': totalSlots,
      'filledSlots': filledSlots,
      'version': version,
      'status': status,
      'roomId': roomId,
      'roomPassword': roomPassword,
      'rules': rules,
      'isMega': isMega,
      'isFree': isFree,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'liveStreamUrl': liveStreamUrl,
      'platform': platform,
      'resultImageUrl': resultImageUrl,
      'isAdminDeleted': isAdminDeleted,
    };
  }

  TournamentModel copyWith({
    String? id,
    String? title,
    String? imageUrl,
    DateTime? dateTime,
    double? entryFee,
    double? prizePool,
    double? booyahPool,
    double? perKillPrize,
    String? matchType,
    String? mode,
    String? gameModeId,
    String? map,
    int? totalSlots,
    int? filledSlots,
    String? version,
    String? status,
    String? roomId,
    String? roomPassword,
    String? rules,
    bool? isMega,
    bool? isFree,
    String? winnerId,
    String? winnerName,
    String? liveStreamUrl,
    String? platform,
    String? resultImageUrl,
    bool? isAdminDeleted,
  }) {
    return TournamentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      dateTime: dateTime ?? this.dateTime,
      entryFee: entryFee ?? this.entryFee,
      prizePool: prizePool ?? this.prizePool,
      booyahPool: booyahPool ?? this.booyahPool,
      perKillPrize: perKillPrize ?? this.perKillPrize,
      matchType: matchType ?? this.matchType,
      mode: mode ?? this.mode,
      gameModeId: gameModeId ?? this.gameModeId,
      map: map ?? this.map,
      totalSlots: totalSlots ?? this.totalSlots,
      filledSlots: filledSlots ?? this.filledSlots,
      version: version ?? this.version,
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      roomPassword: roomPassword ?? this.roomPassword,
      rules: rules ?? this.rules,
      isMega: isMega ?? this.isMega,
      isFree: isFree ?? this.isFree,
      winnerId: winnerId ?? this.winnerId,
      winnerName: winnerName ?? this.winnerName,
      liveStreamUrl: liveStreamUrl ?? this.liveStreamUrl,
      platform: platform ?? this.platform,
      resultImageUrl: resultImageUrl ?? this.resultImageUrl,
      isAdminDeleted: isAdminDeleted ?? this.isAdminDeleted,
    );
  }
}
