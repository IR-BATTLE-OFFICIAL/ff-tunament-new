import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/data/models/registration_model.dart';
import 'package:ff_arena/data/models/download_log_model.dart';
import 'package:ff_arena/data/models/game_mode_model.dart';
import 'package:ff_arena/data/models/tournament_slot_model.dart';

class TournamentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<DownloadLog>> getDownloadLogs() {
    return _db
        .collection('download_logs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DownloadLog.fromFirestore(doc))
            .toList());
  }

  Stream<List<TournamentModel>> getTournaments(String status) {
    return _db
        .collection('tournaments')
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => TournamentModel.fromFirestore(doc))
                .where((t) => t.status.trim().toLowerCase() == status.trim().toLowerCase())
                .toList();
          } catch (e) {
            debugPrint("Error parsing tournaments stream ($status): $e");
            return [];
          }
        });
  }

  Stream<List<TournamentModel>> getAllTournaments() {
    return _db
        .collection('tournaments')
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => TournamentModel.fromFirestore(doc))
                .toList();
          } catch (e) {
            debugPrint("Error parsing all tournaments stream: $e");
            return [];
          }
        });
  }

  Future<void> createTournament(TournamentModel tournament) async {
    await _db.collection('tournaments').add(tournament.toMap());
  }

  Future<void> updateTournament(String id, Map<String, dynamic> data) async {
    await _db.collection('tournaments').doc(id).update(data);
  }

  Future<void> resetCompletedTournament(String id, DateTime nextDateTime) async {
    final docRef = _db.collection('tournaments').doc(id);
    await docRef.update({
      'status': 'upcoming',
      'dateTime': Timestamp.fromDate(nextDateTime),
      'roomId': '',
      'password': '',
      'liveStreamUrl': '',
      'winnerId': null,
      'winnerName': null,
      'resultDeclared': false,
      'prizesDistributed': false,
      'filledSlots': 0,
      'joinedCount': 0,
      'resultImageUrl': FieldValue.delete(),
    });
    
    final batch = _db.batch();

    // 1. Mark all old registrations as completed history (DO NOT DELETE so users retain history in My Matches -> Completed)
    final regs = await _db.collection('registrations').where('tournamentId', isEqualTo: id).get();
    for (var doc in regs.docs) {
      batch.update(doc.reference, {
        'isCompletedHistory': true,
        'status': 'completed',
      });
    }

    // 2. Mark old result records as completed history (DO NOT DELETE so past results are preserved for history)
    final oldResults = await _db.collection('results').where('tournamentId', isEqualTo: id).get();
    for (var doc in oldResults.docs) {
      batch.update(doc.reference, {
        'isCompletedHistory': true,
      });
    }

    await batch.commit();
  }

  Future<void> updateMatchInfo(String id, String roomId, String password, {String? liveStreamUrl}) async {
    final Map<String, dynamic> updateData = {
      'roomId': roomId,
      'password': password,
    };
    if (liveStreamUrl != null) {
      updateData['liveStreamUrl'] = liveStreamUrl;
    }
    await _db.collection('tournaments').doc(id).update(updateData);
  }

  Future<void> deleteTournament(String id) async {
    await _db.collection('tournaments').doc(id).delete();
  }

  Future<void> cancelTournament(String id, [String? reason]) async {
    final data = <String, dynamic>{'status': 'cancelled'};
    if (reason != null && reason.isNotEmpty) {
      data['cancelReason'] = reason;
    }
    await _db.collection('tournaments').doc(id).update(data);
  }

  Future<void> joinTournament(RegistrationModel reg, double entryFee, {String? voucherId}) async {
    final tournamentRef = _db.collection('tournaments').doc(reg.tournamentId);
    final registrationRef = _db.collection('registrations').doc();

    return _db.runTransaction((transaction) async {
      final tournamentDoc = await transaction.get(tournamentRef);
      if (!tournamentDoc.exists) throw Exception("Tournament not found");

      final int filledSlots = (tournamentDoc['filledSlots'] as num?)?.toInt() ?? 0;
      final int totalSlots = (tournamentDoc['totalSlots'] as num?)?.toInt() ?? 0;

      if (filledSlots >= totalSlots) throw Exception("Tournament is full");

      transaction.set(registrationRef, reg.toMap());
      transaction.update(tournamentRef, {
        'filledSlots': FieldValue.increment(1),
        'joinedCount': FieldValue.increment(1),
      });
    }).then((_) {
      if (voucherId != null && voucherId.isNotEmpty) {
        markVoucherUsed(voucherId, reg.userId);
      }
    });
  }

  Stream<List<RegistrationModel>> getParticipants(String tournamentId) {
    return _db
        .collection('registrations')
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RegistrationModel.fromFirestore(doc))
            .where((reg) => reg.isCompletedHistory != true && reg.isCancelled != true)
            .toList());
  }

  Future<void> requestWithdrawal(String uid, double amount, String details, String method, {String? scannerUrl}) async {
    final userRef = _db.collection('users').doc(uid);
    return _db.runTransaction((transaction) async {
      DocumentSnapshot userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception("User not found");
      
      bool isBlocked = userDoc['isBlocked'] ?? false;
      if (isBlocked) throw Exception("Your account is blocked. You cannot withdraw.");

      double currentBalance = (userDoc['balance'] ?? 0.0).toDouble();
      if (currentBalance < amount) throw Exception("Insufficient balance");
      
      transaction.update(userRef, {'balance': currentBalance - amount});
      
      final withdrawal = {
        'userId': uid,
        'amount': amount,
        'details': details,
        'method': method,
        'scannerUrl': scannerUrl,
        'dateTime': Timestamp.now(),
        'status': 'pending',
      };
      transaction.set(_db.collection('withdrawals').doc(), withdrawal);

      final tx = {
        'userId': uid,
        'amount': amount,
        'type': 'withdrawal',
        'dateTime': Timestamp.now(),
        'status': 'pending',
        'description': 'Your withdrawal pending via $method',
      };
      transaction.set(_db.collection('transactions').doc(), tx);
    });
  }

  Stream<List<Map<String, dynamic>>> getWithdrawalMethods() {
    return _db.collection('withdrawal_methods').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> addWithdrawalMethod(Map<String, dynamic> data) async {
    await _db.collection('withdrawal_methods').add(data);
  }

  Future<void> updateWithdrawalMethod(String id, Map<String, dynamic> data) async {
    await _db.collection('withdrawal_methods').doc(id).update(data);
  }

  Future<void> deleteWithdrawalMethod(String id) async {
    await _db.collection('withdrawal_methods').doc(id).delete();
  }

  Stream<List<Map<String, dynamic>>> getWithdrawalRequests() {
    return _db
        .collection('withdrawals')
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  Future<void> updateWithdrawalStatus(String id, String status, {String? reason}) async {
    final withdrawalRef = _db.collection('withdrawals').doc(id);
    
    DocumentSnapshot withdrawalDoc = await withdrawalRef.get();
    if (!withdrawalDoc.exists) throw Exception("Withdrawal request not found");

    String currentStatus = withdrawalDoc['status'] ?? 'pending';
    if (currentStatus != 'pending') return;

    String userId = withdrawalDoc['userId'];
    double amount = (withdrawalDoc['amount'] ?? 0.0).toDouble();

    await withdrawalRef.update({
      'status': status,
      if (reason != null && status == 'failed') 'rejectionReason': reason,
    });

    if (status == 'failed') {
      final userRef = _db.collection('users').doc(userId);
      await userRef.update({
        'balance': FieldValue.increment(amount),
      });

      await _db.collection('transactions').add({
        'userId': userId,
        'amount': amount,
        'type': 'refund',
        'dateTime': Timestamp.now(),
        'status': 'success',
        'description': 'Refund for rejected withdrawal: ₹$amount ${reason != null ? " (Reason: $reason)" : ""}',
      });
    }

    QuerySnapshot txSnapshot = await _db.collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'withdrawal')
        .where('amount', isEqualTo: amount)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    
    if (txSnapshot.docs.isNotEmpty) {
      String method = withdrawalDoc['method'] ?? 'UPI';
      await txSnapshot.docs.first.reference.update({
        'status': status,
        if (status == 'success')
          'description': 'Your withdrawal successful via $method',
        if (status == 'failed')
          'description': 'Your withdrawal rejected via $method${reason != null ? " (Reason: $reason)" : ""}',
      });
    }
  }

  Future<void> resetWithdrawalToPending(String id) async {
    final withdrawalRef = _db.collection('withdrawals').doc(id);
    DocumentSnapshot withdrawalDoc = await withdrawalRef.get(const GetOptions(source: Source.server));
    if (!withdrawalDoc.exists) throw Exception("Withdrawal request not found");

    if (withdrawalDoc['status'] != 'failed') throw Exception("Only rejected requests can be reset");

    String userId = withdrawalDoc['userId'];
    double amount = (withdrawalDoc['amount'] ?? 0.0).toDouble();

    final userRef = _db.collection('users').doc(userId);

    return _db.runTransaction((transaction) async {
      DocumentSnapshot userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception("User not found");

      double currentBalance = (userDoc['balance'] ?? 0.0).toDouble();
      if (currentBalance < amount) throw Exception("User has insufficient balance to reset this withdrawal");

      transaction.update(userRef, {'balance': currentBalance - amount});
      transaction.update(withdrawalRef, {
        'status': 'pending',
        'rejectionReason': FieldValue.delete(),
      });

      transaction.set(_db.collection('transactions').doc(), {
        'userId': userId,
        'amount': amount,
        'type': 'withdrawal',
        'dateTime': Timestamp.now(),
        'status': 'pending',
        'description': 'Your withdrawal pending via ${withdrawalDoc['method']}',
      });
    });
  }

  Future<bool> requestDeposit(String uid, double amount, String txId, {String type = 'manual', String? imageUrl, String? voucherId}) async {
    final userRef = _db.collection('users').doc(uid);
    DocumentSnapshot userDoc = await userRef.get();
    
    if (userDoc.exists) {
      bool isBlocked = userDoc['isBlocked'] ?? false;
      if (isBlocked) throw Exception("Your account is blocked. You cannot deposit.");
    }

    final normalizedTxId = txId.trim().toUpperCase();

    if (type.startsWith('manual')) {
      if (normalizedTxId.length < 12) {
        throw Exception("Invalid Transaction ID. It must be at least 12 digits.");
      }
    }

    final existingRequest = await _db.collection('deposit_requests')
        .where('transactionId', isEqualTo: normalizedTxId)
        .limit(1)
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception("This Transaction ID has already been submitted or used.");
    }

    Map<String, dynamic>? voucherData;
    if (voucherId != null) {
      final vDoc = await _db.collection('vouchers').doc(voucherId).get();
      if (vDoc.exists) {
        voucherData = {
          'id': vDoc.id,
          'code': vDoc['code'],
          'type': vDoc['type'],
          'value': vDoc['value'],
        };
      }
    }

    // Only a server-controlled flow may use imported bank receipts. User-entered
    // UTRs always remain pending for review; they must never credit themselves.
    if (type == 'legacy_trusted_receipt') {
      try {
        final receiptQuery = await _db.collection('bank_receipts')
          .where('utr', isEqualTo: normalizedTxId)
          .where('isUsed', isEqualTo: false)
          .limit(1)
          .get();

        if (receiptQuery.docs.isNotEmpty) {
          final receiptDoc = receiptQuery.docs.first;
          await receiptDoc.reference.update({
            'isUsed': true,
            'usedByUid': uid,
            'usedAt': FieldValue.serverTimestamp(),
          });

          double bonusAmount = 0;
          if (voucherData != null) {
            final vValue = (voucherData['value'] ?? 0.0).toDouble();
            bonusAmount = (amount * vValue) / 100;
          }

          await _db.collection('deposit_requests').add({
            'userId': uid,
            'amount': amount,
            'transactionId': normalizedTxId,
            'type': 'auto_verified',
            'screenshotUrl': imageUrl,
            'dateTime': Timestamp.now(),
            'status': 'success',
            'voucherId': voucherId,
            'voucherData': voucherData,
            'autoVerifiedAt': FieldValue.serverTimestamp(),
          });

          await _db.collection('users').doc(uid).update({
            'balance': FieldValue.increment(amount),
            'bonusBalance': FieldValue.increment(bonusAmount),
          });

          await _db.collection('transactions').add({
            'userId': uid,
            'amount': amount,
            'type': 'deposit',
            'status': 'success',
            'description': 'Instant Auto-Verified Deposit (Ref: $normalizedTxId)',
            'createdAt': FieldValue.serverTimestamp(),
          });

          return true; // INSTANT AUTO-VERIFIED!
        }
      } catch (e) {
        debugPrint("Auto-verify check error: $e");
      }
    }

    // Fallback: Submit for Admin 1-Click Verification
    final depositRequest = {
      'userId': uid,
      'amount': amount,
      'transactionId': normalizedTxId,
      'type': type,
      'screenshotUrl': imageUrl,
      'dateTime': Timestamp.now(),
      'status': 'pending',
      'voucherId': voucherId,
      'voucherData': voucherData,
    };
    final docRef = await _db.collection('deposit_requests').add(depositRequest);

    // Create pending deposit entry in user's transaction history
    await _db.collection('transactions').add({
      'userId': uid,
      'amount': amount,
      'type': 'deposit',
      'status': 'pending',
      'description': 'Your deposit pending',
      'depositRequestId': docRef.id,
      'transactionId': normalizedTxId,
      'dateTime': Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return false; // Submitted as pending
  }

  Future<bool> autoVerifyReceiptWithoutUtr(String uid, String receiptDocId, double amount, String utr) async {
    final receiptRef = _db.collection('bank_receipts').doc(receiptDocId);
    
    try {
      return await _db.runTransaction((transaction) async {
        final receiptSnapshot = await transaction.get(receiptRef);
        if (!receiptSnapshot.exists) return false;
        
        final isUsed = receiptSnapshot.data()?['isUsed'] ?? false;
        if (isUsed) return false;

        transaction.update(receiptRef, {
          'isUsed': true,
          'usedByUid': uid,
          'usedAt': FieldValue.serverTimestamp(),
        });

        final depRef = _db.collection('deposit_requests').doc();
        transaction.set(depRef, {
          'userId': uid,
          'amount': amount,
          'transactionId': utr,
          'type': 'zero_effort_auto',
          'dateTime': Timestamp.now(),
          'status': 'success',
          'autoVerifiedAt': FieldValue.serverTimestamp(),
        });

        final userRef = _db.collection('users').doc(uid);
        transaction.update(userRef, {
          'balance': FieldValue.increment(amount),
        });

        final txRef = _db.collection('transactions').doc();
        transaction.set(txRef, {
          'userId': uid,
          'amount': amount,
          'type': 'deposit',
          'status': 'success',
          'description': 'Your deposit successful',
          'createdAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint("autoVerifyReceiptWithoutUtr error: $e");
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getDepositRequests() {
    return _db
        .collection('deposit_requests')
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  Future<void> updateDepositStatus(String id, String status, {String? reason}) async {
    final depositRef = _db.collection('deposit_requests').doc(id);
    
    DocumentSnapshot depositDoc = await depositRef.get();
    if (!depositDoc.exists) throw Exception("Deposit request not found");

    String currentStatus = depositDoc['status'] ?? 'pending';
    if (currentStatus != 'pending') return;

    String userId = depositDoc['userId'];
    double amount = (depositDoc['amount'] ?? 0.0).toDouble();

    await depositRef.update({
      'status': status,
      if (reason != null && status == 'failed') 'rejectionReason': reason,
    });

    double bonusAmount = 0;
    if (status == 'success') {
      if (depositDoc['voucherData'] != null) {
        final vData = depositDoc['voucherData'] as Map<String, dynamic>;
        final vValue = (vData['value'] ?? 0.0).toDouble();
        bonusAmount = amount * (vValue / 100);

        final voucherId = depositDoc['voucherId'];
        if (voucherId != null) {
          await _db.collection('vouchers').doc(voucherId).update({
            'usedCount': FieldValue.increment(1),
            'usedBy': FieldValue.arrayUnion([userId]),
          });
        }
      }

      await _db.collection('users').doc(userId).update({
        'balance': FieldValue.increment(amount + bonusAmount)
      });
    }

    final String finalDesc = status == 'success'
        ? 'Your deposit successful'
        : (reason != null && reason.isNotEmpty ? 'Your deposit rejected: $reason' : 'Your deposit rejected');

    // Update existing transaction in history from 'pending' to 'success' or 'failed'
    final txQuery = await _db.collection('transactions')
        .where('depositRequestId', isEqualTo: id)
        .limit(1)
        .get();

    if (txQuery.docs.isNotEmpty) {
      await txQuery.docs.first.reference.update({
        'status': status,
        'amount': amount + bonusAmount,
        'description': finalDesc,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final txQuery2 = await _db.collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'deposit')
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (txQuery2.docs.isNotEmpty) {
        await txQuery2.docs.first.reference.update({
          'status': status,
          'amount': amount + bonusAmount,
          'description': finalDesc,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _db.collection('transactions').add({
          'userId': userId,
          'amount': amount + bonusAmount,
          'type': 'deposit',
          'dateTime': Timestamp.now(),
          'status': status,
          'description': finalDesc,
        });
      }
    }
  }

  Future<void> resetDepositToPending(String id) async {
    final depositRef = _db.collection('deposit_requests').doc(id);
    DocumentSnapshot depositDoc = await depositRef.get();
    if (!depositDoc.exists) throw Exception("Deposit request not found");

    String currentStatus = depositDoc['status'] ?? 'pending';
    if (currentStatus == 'pending') return;

    String userId = depositDoc['userId'];
    double amount = (depositDoc['amount'] ?? 0.0).toDouble();
    double bonusAmount = 0;

    if (depositDoc['voucherData'] != null) {
      final vData = depositDoc['voucherData'] as Map<String, dynamic>;
      final vValue = (vData['value'] ?? 0.0).toDouble();
      bonusAmount = amount * (vValue / 100);
    }

    double totalToDeduct = amount + bonusAmount;

    if (currentStatus == 'success') {
      final userRef = _db.collection('users').doc(userId);
      await _db.runTransaction((transaction) async {
        DocumentSnapshot userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw Exception("User not found");

        double currentBalance = (userDoc['balance'] ?? 0.0).toDouble();
        
        transaction.update(userRef, {'balance': currentBalance - totalToDeduct});
        transaction.update(depositRef, {
          'status': 'pending',
          'rejectionReason': FieldValue.delete(),
        });
      });
    } else {
      await depositRef.update({
        'status': 'pending',
        'rejectionReason': FieldValue.delete(),
      });
    }

    // Reset matching transaction back to pending
    final txQuery = await _db.collection('transactions')
        .where('depositRequestId', isEqualTo: id)
        .limit(1)
        .get();
    if (txQuery.docs.isNotEmpty) {
      await txQuery.docs.first.reference.update({
        'status': 'pending',
        'amount': amount,
        'description': 'Your deposit pending',
      });
    }
  }

  Future<void> deleteDepositRequest(String id) async {
    await _db.collection('deposit_requests').doc(id).delete();
  }

  Future<void> deleteWithdrawalRequest(String id) async {
    await _db.collection('withdrawals').doc(id).delete();
  }

  Future<void> deleteAllDepositRequests({String? status}) async {
    final collection = _db.collection('deposit_requests');
    final QuerySnapshot snapshot = (status != null && status.isNotEmpty)
        ? await collection.where('status', isEqualTo: status).get()
        : await collection.get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> deleteAllWithdrawalRequests({String? status}) async {
    final collection = _db.collection('withdrawals');
    final QuerySnapshot snapshot = (status != null && status.isNotEmpty)
        ? await collection.where('status', isEqualTo: status).get()
        : await collection.get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> uploadResultsAndComplete(String tournamentId, List<Map<String, dynamic>> results, {String? resultImageUrl}) async {
    final tournamentDoc = await _db.collection('tournaments').doc(tournamentId).get();
    if (!tournamentDoc.exists) throw Exception("Tournament not found");

    final TournamentModel tournament = TournamentModel.fromFirestore(tournamentDoc);
    final String tournamentTitle = tournament.title;

    final batch = _db.batch();
    final resultsCollection = _db.collection('results');

    final existing = await resultsCollection.where('tournamentId', isEqualTo: tournamentId).get();
    for (var doc in existing.docs) {
      if (doc.data()['isCompletedHistory'] != true) {
        batch.delete(doc.reference);
      }
    }

    // Sort results by rank to handle dynamic breakdown correctly
    final sortedResults = List<Map<String, dynamic>>.from(results)
      ..sort((a, b) => ((a['rank'] as num?)?.toInt() ?? 0).compareTo((b['rank'] as num?)?.toInt() ?? 0));

    for (var result in sortedResults) {
      // Apply automated prize breakdown if it's a Survival match
      if (tournament.mode.toLowerCase() == 'survival' && tournament.prizeBreakdown.isNotEmpty) {
        final rank = (result['rank'] as num?)?.toInt() ?? 0;
        final matchingPrize = tournament.prizeBreakdown.firstWhere(
          (p) => (p['rank'] as num?)?.toInt() == rank,
          orElse: () => {'amount': 0.0},
        );
        
        final double rankPrize = (matchingPrize['amount'] as num?)?.toDouble() ?? 0.0;
        result['positionPrize'] = rankPrize;
        result['prizeWon'] = rankPrize + (result['killPrize'] as num? ?? 0.0) + (result['booyahPrize'] as num? ?? 0.0);
      }

      final docRef = resultsCollection.doc();
      batch.set(docRef, {
        'tournamentId': tournamentId,
        ...result,
        'createdAt': Timestamp.now(),
      });
    }

    final tournamentRef = _db.collection('tournaments').doc(tournamentId);
    batch.update(tournamentRef, {
      'status': 'completed',
      'prizesDistributed': true,
      if (resultImageUrl != null) 'resultImageUrl': resultImageUrl,
    });

    await batch.commit();

    // Automatically distribute coins to wallet and create transaction history for all participants
    for (var result in sortedResults) {
      final String? userId = result['userId']?.toString();
      if (userId == null || userId.isEmpty) continue;

      final double prizeWon = (result['prizeWon'] as num?)?.toDouble() ?? 0.0;
      final int kills = (result['kills'] as num?)?.toInt() ?? 0;
      final int rank = (result['rank'] as num?)?.toInt() ?? 0;

      if (prizeWon > 0) {
        // 1. Credit User Wallet Balance & Total Earnings
        try {
          await _db.collection('users').doc(userId).update({
            'balance': FieldValue.increment(prizeWon),
            'totalEarnings': FieldValue.increment(prizeWon),
            if (rank == 1) 'totalWins': FieldValue.increment(1),
          });
        } catch (e) {
          debugPrint("Error updating balance for user $userId: $e");
        }

        // 2. Add Transaction Log to History
        try {
          await _db.collection('transactions').add({
            'userId': userId,
            'amount': prizeWon,
            'type': 'prize',
            'dateTime': Timestamp.now(),
            'status': 'success',
            'description': 'Tournament Prize (Rank #${rank > 0 ? rank : '-'}, $kills Kills) - $tournamentTitle',
          });
        } catch (e) {
          debugPrint("Error adding transaction for user $userId: $e");
        }

        // 3. Mark Registration Prize Paid
        try {
          final regQuery = await _db.collection('registrations')
              .where('tournamentId', isEqualTo: tournamentId)
              .where('userId', isEqualTo: userId)
              .limit(1)
              .get();
          if (regQuery.docs.isNotEmpty) {
            await regQuery.docs.first.reference.update({'prizePaid': true});
          }
        } catch (e) {
          debugPrint("Error updating registration prizePaid: $e");
        }

        // 4. Increment Total Platform Winnings
        await _incrementTotalWinnings(prizeWon);
      } else if (rank == 1) {
        await _db.collection('users').doc(userId).update({
          'totalWins': FieldValue.increment(1),
        }).catchError((e) {});
      }
    }
  }

  Future<void> distributePrizeAndComplete(String tournamentId, String winnerId, double amount) async {
    final tournamentDoc = await _db.collection('tournaments').doc(tournamentId).get();
    if (!tournamentDoc.exists) throw Exception("Tournament not found");

    await _db.collection('users').doc(winnerId).update({
      'balance': FieldValue.increment(amount),
      'totalEarnings': FieldValue.increment(amount),
    });

    await _db.collection('transactions').add({
      'userId': winnerId,
      'amount': amount,
      'type': 'prize',
      'dateTime': Timestamp.now(),
      'status': 'success',
      'description': 'Winner Prize in tournament: ${tournamentDoc['title']}',
    });

    await _incrementTotalWinnings(amount);
  }

  Future<void> distributeKillPrize(String tournamentId, String userId, double amount, int kills) async {
    if (amount <= 0) throw Exception("Kill prize amount must be greater than zero");

    final tournamentDoc = await _db.collection('tournaments').doc(tournamentId).get();
    if (!tournamentDoc.exists) throw Exception("Tournament not found");

    await _db.collection('users').doc(userId).update({
      'balance': FieldValue.increment(amount),
      'totalEarnings': FieldValue.increment(amount),
    });

    QuerySnapshot regSnapshot = await _db.collection('registrations')
        .where('tournamentId', isEqualTo: tournamentId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    
    if (regSnapshot.docs.isNotEmpty) {
      await regSnapshot.docs.first.reference.update({'killPrizePaid': true});
    }

    await _db.collection('transactions').add({
      'userId': userId,
      'amount': amount,
      'type': 'prize',
      'dateTime': Timestamp.now(),
      'status': 'success',
      'description': 'Kill Prize ($kills kills) in: ${tournamentDoc['title']}',
    });
    
    if (amount > 0) {
      await _incrementTotalWinnings(amount);
    }
  }

  Future<void> distributeParticipantPrize(String tournamentId, String userId, double amount) async {
    if (amount <= 0) throw Exception("Prize amount must be greater than zero");

    final tournamentDoc = await _db.collection('tournaments').doc(tournamentId).get();
    if (!tournamentDoc.exists) throw Exception("Tournament not found");

    await _db.collection('users').doc(userId).update({
      'balance': FieldValue.increment(amount),
      'totalEarnings': FieldValue.increment(amount),
    });

    await _db.collection('transactions').add({
      'userId': userId,
      'amount': amount,
      'type': 'prize',
      'dateTime': Timestamp.now(),
      'status': 'success',
      'description': 'Prize in tournament: ${tournamentDoc['title']}',
    });

    final registrations = await _db.collection('registrations')
        .where('tournamentId', isEqualTo: tournamentId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (registrations.docs.isNotEmpty) {
      await registrations.docs.first.reference.update({'prizePaid': true});
    }

    await _incrementTotalWinnings(amount);
  }

  Future<void> undoWithdrawalApproval(String id) async {
    final withdrawalRef = _db.collection('withdrawals').doc(id);
    DocumentSnapshot withdrawalDoc = await withdrawalRef.get();
    if (!withdrawalDoc.exists) throw Exception("Withdrawal request not found");

    if (withdrawalDoc['status'] != 'success') throw Exception("Only approved requests can be undone");

    await withdrawalRef.update({
      'status': 'pending',
    });
  }


  Future<void> sendMatchReminder(String tournamentId) async {
    final tournamentDoc = await _db.collection('tournaments').doc(tournamentId).get();
    if (!tournamentDoc.exists) throw Exception("Tournament not found");
    String title = tournamentDoc['title'] ?? 'Tournament';

    QuerySnapshot regSnapshot = await _db.collection('registrations')
        .where('tournamentId', isEqualTo: tournamentId)
        .get();

    final batch = _db.batch();
    for (var regDoc in regSnapshot.docs) {
      String userId = regDoc['userId'];
      
      final notificationRef = _db.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': userId,
        'title': 'Match Reminder: $title',
        'message': 'Your match for $title is about to start. Please be ready!',
        'dateTime': Timestamp.now(),
        'type': 'warning',
      });

      final userRef = _db.collection('users').doc(userId);
      batch.update(userRef, {
        'unreadNotifications': FieldValue.increment(1),
      });
    }
    await batch.commit();
  }

  Stream<List<RegistrationModel>> getMyMatches(String userId) {
    return _db
        .collection('registrations')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final matches = snapshot.docs
          .map((doc) => RegistrationModel.fromFirestore(doc))
          .toList();
      matches.sort((a, b) => b.registrationDate.compareTo(a.registrationDate));
      return matches;
    });
  }

  Stream<List<Map<String, dynamic>>> getResults(String tournamentId) {
    return _db
        .collection('results')
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snapshot) {
      final results = snapshot.docs
          .map((doc) => doc.data())
          .toList();
      results.sort((a, b) {
        final aRank = (a['rank'] as num?)?.toInt() ?? 0;
        final bRank = (b['rank'] as num?)?.toInt() ?? 0;
        // Declared ranks are always listed as 1, 2, 3, and so on.
        final aOrder = aRank > 0 ? aRank : 999999;
        final bOrder = bRank > 0 ? bRank : 999999;
        final rankCompare = aOrder.compareTo(bOrder);
        if (rankCompare != 0) return rankCompare;
        return ((b['kills'] ?? 0) as num).compareTo((a['kills'] ?? 0) as num);
      });
      return results;
    });
  }

  Stream<List<Map<String, dynamic>>> getBanners() {
    return _db.collection('banners').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Stream<List<Map<String, dynamic>>> getAllTransactions() {
    return _db
        .collection('transactions')
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getSupportTickets() {
    return _db
        .collection('support_tickets')
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getSupportMessages(String ticketId) {
    return _db
        .collection('support_tickets')
        .doc(ticketId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<void> startSupportTicket(String userId, String userName) async {
    final ticketRef = _db.collection('support_tickets').doc(userId);
    await ticketRef.set({
      'userId': userId,
      'userName': userName,
      'status': 'open',
      'lastMessage': 'Ticket started',
      'lastMessageTime': Timestamp.now(),
      'unreadByAdmin': true,
      'unreadByUser': false,
    }, SetOptions(merge: true));
  }

  Future<void> sendSupportMessage(String ticketId, String message, bool isUser) async {
    final ticketRef = _db.collection('support_tickets').doc(ticketId);
    final messageData = {
      'text': message,
      'isUser': isUser,
      'timestamp': Timestamp.now(),
    };

    await _db.runTransaction((transaction) async {
      transaction.set(ticketRef.collection('messages').doc(), messageData);
      transaction.update(ticketRef, {
        'lastMessage': message,
        'lastMessageTime': Timestamp.now(),
        'unreadByAdmin': isUser,
        'unreadByUser': !isUser,
      });
    });
  }

  Future<void> markSupportRead(String ticketId, bool isAdmin) async {
    await _db.collection('support_tickets').doc(ticketId).update({
      if (isAdmin) 'unreadByAdmin': false else 'unreadByUser': false,
    });
  }

  Future<void> closeSupportTicket(String ticketId) async {
    await _db.collection('support_tickets').doc(ticketId).update({
      'status': 'closed',
    });
  }

  Future<void> submitReport(Map<String, dynamic> reportData) async {
    await _db.collection('reports').add({
      ...reportData,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _incrementTotalWinnings(double amount) async {
    try {
      final configRef = _db.collection('settings').doc('app_config');
      final doc = await configRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        dynamic current = data['totalWinnings'] ?? 0.0;
        double currentVal = 0.0;
        if (current is String) {
          currentVal = double.tryParse(current) ?? 0.0;
        } else if (current is num) {
          currentVal = current.toDouble();
        }
        await configRef.update({
          'totalWinnings': currentVal + amount,
        });
      }
    } catch (e) {
      debugPrint("Error incrementing total winnings: $e");
    }
  }

  Future<void> addBanner(Map<String, dynamic> bannerData) async {
    await _db.collection('banners').add(bannerData);
  }

  Future<void> updateBanner(String id, Map<String, dynamic> bannerData) async {
    await _db.collection('banners').doc(id).update(bannerData);
  }

  Future<void> deleteBanner(String id) async {
    await _db.collection('banners').doc(id).delete();
  }

  Stream<Map<String, dynamic>> getAppConfig() {
    return _db.collection('settings').doc('app_config').snapshots().map((doc) => doc.data() ?? {});
  }

  Future<void> updateAppConfig(Map<String, dynamic> data) async {
    await _db.collection('settings').doc('app_config').set(data, SetOptions(merge: true));
  }

  Future<TournamentModel?> getTournamentById(String id) async {
    final doc = await _db.collection('tournaments').doc(id).get();
    if (doc.exists) {
      return TournamentModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<List<Map<String, dynamic>>> getVouchers() {
    return _db.collection('vouchers').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> createVoucher(Map<String, dynamic> data) async {
    await _db.collection('vouchers').add(data);
  }

  Future<void> deleteVoucher(String id) async {
    await _db.collection('vouchers').doc(id).delete();
  }

  Future<Map<String, dynamic>> validateVoucher(String code, String userId, String type) async {
    final normalizedCode = code.trim().toUpperCase();
    final query = await _db.collection('vouchers')
        .where('code', isEqualTo: normalizedCode)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw Exception("Invalid voucher code");

    final doc = query.docs.first;
    final data = doc.data();
    final expiry = (data['expiryDate'] as Timestamp).toDate();
    
    if (DateTime.now().isAfter(expiry)) throw Exception("Voucher has expired");

    if (data['type'] != type && type != 'any') {
      throw Exception("This voucher is not valid for this action");
    }

    final List usedBy = data['usedBy'] ?? [];
    if (usedBy.contains(userId)) throw Exception("You have already used this voucher");

    final int usedCount = data['usedCount'] ?? 0;
    final int limit = data['usageLimit'] ?? 100;
    if (usedCount >= limit) throw Exception("Voucher usage limit reached");

    return {'id': doc.id, ...data};
  }

  Future<void> markVoucherUsed(String voucherId, String userId) async {
    await _db.collection('vouchers').doc(voucherId).update({
      'usedCount': FieldValue.increment(1),
      'usedBy': FieldValue.arrayUnion([userId]),
    });
  }

  // AI Chat Persistence (Firestore)
  Future<void> saveAIMessage(String userId, String text, bool isUser) async {
    await _db.collection('ai_chat_history').doc(userId).collection('messages').add({
      'text': text,
      'isUser': isUser,
      'timestamp': Timestamp.now(),
    });
  }

  Stream<List<Map<String, dynamic>>> getAIChatHistory(String userId) {
    return _db
        .collection('ai_chat_history')
        .doc(userId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> clearAIChatHistory(String userId) async {
    final messagesRef = _db
        .collection('ai_chat_history')
        .doc(userId)
        .collection('messages');
    final snapshot = await messagesRef.get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── GAME MODES ──
  Stream<List<GameModeModel>> getGameModes({bool onlyActive = false}) {
    return _db.collection('game_modes').snapshots().map((snapshot) {
      List<GameModeModel> modes = [];
      for (var doc in snapshot.docs) {
        try {
          modes.add(GameModeModel.fromFirestore(doc));
        } catch (e) {
          debugPrint("Error parsing game_mode doc ${doc.id}: $e");
        }
      }
      if (onlyActive) {
        modes = modes.where((mode) => mode.isActive).toList();
      }
      modes.sort((a, b) => a.order.compareTo(b.order));
      return modes;
    });
  }

  Future<void> addGameMode(GameModeModel mode) async {
    debugPrint("Adding game mode: ${mode.title}");
    await _db.collection('game_modes').add(mode.toMap());
  }

  Future<void> updateGameMode(String id, Map<String, dynamic> data) async {
    await _db.collection('game_modes').doc(id).update(data);
  }

  Future<void> deleteGameMode(String id) async {
    await _db.collection('game_modes').doc(id).delete();
  }

  Future<void> seedDefaultGameModes() async {
    final snapshot = await _db.collection('game_modes').get();
    if (snapshot.docs.isNotEmpty) return; // already seeded

    final defaultModes = [
      {
        'title': 'BATTLE ROYALE',
        'bannerUrl': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=600&auto=format&fit=crop',
        'order': 1,
        'isActive': true,
        'createdAt': Timestamp.now(),
      },
      {
        'title': 'CLASH SQUAD',
        'bannerUrl': 'https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=600&auto=format&fit=crop',
        'order': 2,
        'isActive': true,
        'createdAt': Timestamp.now(),
      },
      {
        'title': 'LONE WOLF',
        'bannerUrl': 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?q=80&w=600&auto=format&fit=crop',
        'order': 3,
        'isActive': true,
        'createdAt': Timestamp.now(),
      },
      {
        'title': 'SURVIVAL',
        'bannerUrl': 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=600&auto=format&fit=crop',
        'order': 4,
        'isActive': true,
        'createdAt': Timestamp.now(),
      },
      {
        'title': 'FREE MATCH',
        'bannerUrl': 'https://images.unsplash.com/photo-1563089145-599997674d42?q=80&w=600&auto=format&fit=crop',
        'order': 5,
        'isActive': true,
        'createdAt': Timestamp.now(),
      },
    ];

    for (var m in defaultModes) {
      await _db.collection('game_modes').add(m);
    }
  }

  Stream<List<TournamentSlotModel>> getTournamentSlots(String tournamentId, {int? totalSlots}) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('slots')
        .orderBy('slotNumber')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TournamentSlotModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }
}

