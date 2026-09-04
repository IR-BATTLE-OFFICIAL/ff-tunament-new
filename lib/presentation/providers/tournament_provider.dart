import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/data/models/registration_model.dart';
import 'package:ff_arena/data/models/download_log_model.dart';
import 'package:ff_arena/data/models/game_mode_model.dart';
import 'package:ff_arena/data/datasources/tournament_service.dart';
import 'package:ff_arena/core/utils/storage_service.dart';

class TournamentProvider extends ChangeNotifier {
  final TournamentService _tournamentService = TournamentService();
  
  Stream<List<DownloadLog>> downloadLogs() => _tournamentService.getDownloadLogs();
  
  Stream<List<TournamentModel>> upcomingTournaments() => _tournamentService.getTournaments('upcoming');
  Stream<List<TournamentModel>> liveTournaments() => _tournamentService.getTournaments('live');
  Stream<List<TournamentModel>> completedTournaments() => _tournamentService.getTournaments('completed');
  Stream<List<TournamentModel>> allTournaments() => _tournamentService.getAllTournaments();

  Stream<List<TournamentModel>> tournamentsByMode(String mode) {
    return _tournamentService.getTournaments('upcoming').map((list) => 
      list.where((t) => t.mode == mode && !t.isMega).toList()
    );
  }

  Stream<List<TournamentModel>> tournamentsByGameMode(String gameModeId, String modeTitle) {
    return _tournamentService.getTournaments('upcoming').map((list) => 
      list.where((t) {
        final matchId = t.gameModeId == gameModeId;
        final matchTitle = t.mode.trim().toLowerCase() == modeTitle.trim().toLowerCase();
        return (matchId || matchTitle) && !t.isMega;
      }).toList()
    );
  }

  Stream<List<TournamentModel>> megaTournaments() {
    return _tournamentService.getTournaments('upcoming').map((list) => 
      list.where((t) => t.isMega).toList()
    );
  }

  Stream<List<TournamentModel>> freeTournaments() {
    return _tournamentService.getTournaments('upcoming').map((list) => 
      list.where((t) => t.isFree).toList()
    );
  }

  Stream<List<TournamentModel>> getAllUpcomingTournaments() {
    return _tournamentService.getTournaments('upcoming');
  }

  Future<void> createTournament(TournamentModel tournament) async {
    await _tournamentService.createTournament(tournament);
    notifyListeners();
  }

  Future<void> updateTournament(String id, Map<String, dynamic> data) async {
    await _tournamentService.updateTournament(id, data);
    notifyListeners();
  }

  Future<void> resetCompletedTournament(String id, DateTime nextDateTime) async {
    await _tournamentService.resetCompletedTournament(id, nextDateTime);
    notifyListeners();
  }

  Future<void> updateMatchInfo(String id, String roomId, String password, {String? liveStreamUrl}) async {
    await _tournamentService.updateMatchInfo(id, roomId, password, liveStreamUrl: liveStreamUrl);
    notifyListeners();
  }

  Future<void> sendMatchReminder(String id) async {
    await _tournamentService.sendMatchReminder(id);
    notifyListeners();
  }

  Future<void> deleteTournament(String id) async {
    await _tournamentService.deleteTournament(id);
    notifyListeners();
  }

  Future<void> cancelTournament(String id, [String? reason]) async {
    await _tournamentService.cancelTournament(id, reason);
    notifyListeners();
  }

  Future<void> joinTournament(RegistrationModel registration, double entryFee, {String? voucherId}) async {
    await _tournamentService.joinTournament(registration, entryFee, voucherId: voucherId);
    notifyListeners();
  }

  Future<void> requestWithdrawal(String uid, double amount, String details, String method, {String? scannerUrl}) async {
    await _tournamentService.requestWithdrawal(uid, amount, details, method, scannerUrl: scannerUrl);
    notifyListeners();
  }

  Stream<List<Map<String, dynamic>>> withdrawalMethods() => _tournamentService.getWithdrawalMethods();

  Future<void> addWithdrawalMethod(Map<String, dynamic> data) async {
    await _tournamentService.addWithdrawalMethod(data);
    notifyListeners();
  }

  Future<void> updateWithdrawalMethod(String id, Map<String, dynamic> data) async {
    await _tournamentService.updateWithdrawalMethod(id, data);
    notifyListeners();
  }

  Future<void> deleteWithdrawalMethod(String id) async {
    await _tournamentService.deleteWithdrawalMethod(id);
    notifyListeners();
  }

  Stream<List<RegistrationModel>> myMatches(String userId) => _tournamentService.getMyMatches(userId);
  Stream<List<RegistrationModel>> participants(String tournamentId) => _tournamentService.getParticipants(tournamentId);
  Stream<List<Map<String, dynamic>>> withdrawalRequests() => _tournamentService.getWithdrawalRequests();
  Stream<List<Map<String, dynamic>>> depositRequests() => _tournamentService.getDepositRequests();
  Stream<List<Map<String, dynamic>>> allTransactions() => _tournamentService.getAllTransactions();
  Stream<List<Map<String, dynamic>>> getAllTransactions() => _tournamentService.getAllTransactions();
  Stream<List<Map<String, dynamic>>> results(String tournamentId) => _tournamentService.getResults(tournamentId);
  Stream<List<Map<String, dynamic>>> banners() => _tournamentService.getBanners();

  Future<bool> requestDeposit(String uid, double amount, String txId, {String type = 'manual', File? imageFile, String? voucherId}) async {
    String? imageUrl;
    
    if (imageFile != null) {
      final storageService = StorageService();
      imageUrl = await storageService.uploadImage('deposits', imageFile);
    }

    final isAutoVerified = await _tournamentService.requestDeposit(uid, amount, txId, type: type, imageUrl: imageUrl, voucherId: voucherId);
    notifyListeners();
    return isAutoVerified;
  }

  Future<void> submitReport(Map<String, dynamic> reportData, {File? proofImage, File? proofVideo}) async {
    final storageService = StorageService();
    
    if (proofImage != null) {
      String? imageUrl = await storageService.uploadImage('reports', proofImage);
      if (imageUrl != null) reportData['proofImageUrl'] = imageUrl;
    }
    
    if (proofVideo != null) {
      // Videos go to Supabase
      String videoUrl = await storageService.uploadFile('reports/videos', proofVideo, '${DateTime.now().millisecondsSinceEpoch}.mp4');
      reportData['proofVideoUrl'] = videoUrl;
    }

    await _tournamentService.submitReport(reportData);
    notifyListeners();
  }

  Future<void> updateDepositStatus(String id, String status, {String? reason}) async {
    await _tournamentService.updateDepositStatus(id, status, reason: reason);
    notifyListeners();
  }

  Future<void> resetDepositToPending(String id) async {
    await _tournamentService.resetDepositToPending(id);
    notifyListeners();
  }

  Future<void> addBanner(Map<String, dynamic> data) async {
    await _tournamentService.addBanner(data);
    notifyListeners();
  }

  Future<void> updateBanner(String id, Map<String, dynamic> data) async {
    await _tournamentService.updateBanner(id, data);
    notifyListeners();
  }

  Future<void> deleteBanner(String id) async {
    await _tournamentService.deleteBanner(id);
    notifyListeners();
  }

  Future<void> uploadResultsAndComplete(String tournamentId, List<Map<String, dynamic>> results, {File? resultImage}) async {
    String? imageUrl;
    if (resultImage != null) {
      final storageService = StorageService();
      imageUrl = await storageService.uploadImage('results', resultImage);
    }
    
    await _tournamentService.uploadResultsAndComplete(tournamentId, results, resultImageUrl: imageUrl);
    notifyListeners();
  }

  Future<void> distributePrize(String tournamentId, String winnerId, double amount) async {
    await _tournamentService.distributePrizeAndComplete(tournamentId, winnerId, amount);
    notifyListeners();
  }

  Future<void> distributeKillPrize(String tournamentId, String userId, double amount, int kills) async {
    await _tournamentService.distributeKillPrize(tournamentId, userId, amount, kills);
    notifyListeners();
  }

  Future<void> distributeParticipantPrize(String tournamentId, String userId, double amount) async {
    await _tournamentService.distributeParticipantPrize(tournamentId, userId, amount);
    notifyListeners();
  }

  Future<void> updateWithdrawalStatus(String id, String status, {String? reason}) async {
    await _tournamentService.updateWithdrawalStatus(id, status, reason: reason);
    notifyListeners();
  }

  Future<void> undoWithdrawalApproval(String id) async {
    await _tournamentService.undoWithdrawalApproval(id);
    notifyListeners();
  }

  Future<void> resetWithdrawalToPending(String id) async {
    await _tournamentService.resetWithdrawalToPending(id);
    notifyListeners();
  }

  Future<void> deleteDepositRequest(String id) async {
    await _tournamentService.deleteDepositRequest(id);
    notifyListeners();
  }

  Future<void> deleteWithdrawalRequest(String id) async {
    await _tournamentService.deleteWithdrawalRequest(id);
    notifyListeners();
  }

  Future<void> deleteAllDepositRequests({String? status}) async {
    await _tournamentService.deleteAllDepositRequests(status: status);
    notifyListeners();
  }

  Future<void> deleteAllWithdrawalRequests({String? status}) async {
    await _tournamentService.deleteAllWithdrawalRequests(status: status);
    notifyListeners();
  }

  Future<TournamentModel?> getTournamentById(String id) => _tournamentService.getTournamentById(id);

  // Voucher Methods
  Stream<List<Map<String, dynamic>>> vouchers() => _tournamentService.getVouchers();
  
  Future<void> createVoucher(Map<String, dynamic> data) async {
    await _tournamentService.createVoucher(data);
    notifyListeners();
  }

  Future<void> deleteVoucher(String id) async {
    await _tournamentService.deleteVoucher(id);
    notifyListeners();
  }

  Future<Map<String, dynamic>> validateVoucher(String code, String userId, String type) =>
    _tournamentService.validateVoucher(code, userId, type);

  // Support Chat
  Stream<List<Map<String, dynamic>>> supportTickets() => _tournamentService.getSupportTickets();
  Stream<List<Map<String, dynamic>>> supportMessages(String ticketId) => _tournamentService.getSupportMessages(ticketId);
  
  Future<void> startSupportTicket(String userId, String userName) async {
    await _tournamentService.startSupportTicket(userId, userName);
    notifyListeners();
  }

  Future<void> sendSupportMessage(String ticketId, String message, bool isUser) async {
    await _tournamentService.sendSupportMessage(ticketId, message, isUser);
    notifyListeners();
  }

  Future<void> markSupportRead(String ticketId, bool isAdmin) async {
    await _tournamentService.markSupportRead(ticketId, isAdmin);
    notifyListeners();
  }

  Future<void> closeSupportTicket(String ticketId) async {
    await _tournamentService.closeSupportTicket(ticketId);
    notifyListeners();
  }

  // App Config
  Stream<Map<String, dynamic>> appConfig() => _tournamentService.getAppConfig();
  
  Future<void> updateAppConfig(Map<String, dynamic> data) async {
    await _tournamentService.updateAppConfig(data);
    notifyListeners();
  }

  // AI Chat Persistence
  Future<void> saveAIMessage(String userId, String text, bool isUser) async {
    await _tournamentService.saveAIMessage(userId, text, isUser);
  }

  Stream<List<Map<String, dynamic>>> aiChatHistory(String userId) {
    return _tournamentService.getAIChatHistory(userId);
  }

  Future<void> clearAIChatHistory(String userId) async {
    await _tournamentService.clearAIChatHistory(userId);
    notifyListeners();
  }

  // Game Modes
  Stream<List<GameModeModel>> gameModes({bool onlyActive = false}) =>
      _tournamentService.getGameModes(onlyActive: onlyActive);

  Future<void> addGameMode(GameModeModel mode) async {
    await _tournamentService.addGameMode(mode);
    notifyListeners();
  }

  Future<void> updateGameMode(String id, Map<String, dynamic> data) async {
    await _tournamentService.updateGameMode(id, data);
    notifyListeners();
  }

  Future<void> deleteGameMode(String id) async {
    await _tournamentService.deleteGameMode(id);
    notifyListeners();
  }

  Future<void> seedDefaultGameModes() async {
    await _tournamentService.seedDefaultGameModes();
    notifyListeners();
  }
}