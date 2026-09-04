import 'package:cloud_firestore/cloud_firestore.dart';

class ResultModel {
  final String id;
  final String tournamentId;
  final int rank;
  final String playerName;
  final String ffUid;
  final int kills;
  final double positionPrize;
  final double killPrize;
  final double booyahPrize;
  final double prizeWon;

  ResultModel({
    required this.id,
    required this.tournamentId,
    required this.rank,
    required this.playerName,
    required this.ffUid,
    required this.kills,
    this.positionPrize = 0.0,
    this.killPrize = 0.0,
    this.booyahPrize = 0.0,
    required this.prizeWon,
  });

  factory ResultModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ResultModel(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      rank: data['rank'] ?? 0,
      playerName: data['playerName'] ?? '',
      ffUid: data['ffUid'] ?? '',
      kills: data['kills'] ?? 0,
      positionPrize: (data['positionPrize'] ?? 0.0).toDouble(),
      killPrize: (data['killPrize'] ?? 0.0).toDouble(),
      booyahPrize: (data['booyahPrize'] ?? 0.0).toDouble(),
      prizeWon: (data['prizeWon'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'rank': rank,
      'playerName': playerName,
      'ffUid': ffUid,
      'kills': kills,
      'positionPrize': positionPrize,
      'killPrize': killPrize,
      'booyahPrize': booyahPrize,
      'prizeWon': prizeWon,
    };
  }
}
