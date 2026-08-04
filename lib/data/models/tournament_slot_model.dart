class TournamentSlotModel {
  final String id;
  final String tournamentId;
  final int slotNumber;
  final String status; // 'available', 'locked'
  final String? userId;
  final String? userName;

  TournamentSlotModel({
    required this.id,
    required this.tournamentId,
    required this.slotNumber,
    required this.status,
    this.userId,
    this.userName,
  });

  factory TournamentSlotModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TournamentSlotModel(
      id: id,
      tournamentId: data['tournamentId'] ?? '',
      slotNumber: data['slotNumber'] ?? 0,
      status: data['status'] ?? 'available',
      userId: data['userId'] ?? data['bookedBy'],
      userName: data['userName'] ?? data['bookedByName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'slotNumber': slotNumber,
      'status': status,
      'userId': userId,
      'userName': userName,
    };
  }
}
