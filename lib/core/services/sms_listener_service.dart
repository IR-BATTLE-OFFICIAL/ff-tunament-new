import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

/// SMS Auto-Verification Service (100% Firebase)
///
/// On the ADMIN's merchant phone:
/// 1. Admin opens the app and enables "SMS Auto-Verification" toggle.
/// 2. This service reads the SMS inbox for recent bank/UPI credit messages.
/// 3. Also registers a MethodChannel listener for new incoming SMS
///    (sent from the native Android BroadcastReceiver in SmsBroadcastReceiver.kt).
/// 4. All parsed UTR + Amount receipts are saved to Firestore `bank_receipts`.
/// 5. When any user submits a manual deposit, TournamentService checks this
///    collection and instantly approves if a matching, unused UTR is found.
class SmsListenerService {
  static final SmsListenerService _instance = SmsListenerService._internal();
  factory SmsListenerService() => _instance;
  SmsListenerService._internal();

  static const _channel = MethodChannel('com.ffarena.ff_arena/sms');

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isListening = false;

  bool get isListening => _isListening;

  // Known Indian bank/UPI SMS sender keywords
  static const List<String> _creditKeywords = [
    'credited', 'received', 'credit', 'deposited',
  ];

  static const List<String> _bankSenders = [
    'HDFCBK', 'ICICIB', 'SBIUPI', 'AXISBK', 'KOTAKB', 'PNBSMS',
    'BOIIND', 'CANBNK', 'CENTBK', 'IDBIBK', 'INDBNK', 'UCOBNK',
    'PAYTM', 'PYTMSB', 'PHONEPE', 'GPAY', 'BHIMUPI', 'UPI', 'BHIM',
  ];

  /// Start listening: reads recent inbox SMS + hooks into native SMS receiver.
  Future<bool> startListening() async {
    if (_isListening) return true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Request SMS permission via native channel
    try {
      final granted = await _channel.invokeMethod<bool>('requestSmsPermission');
      if (granted != true) {
        debugPrint('❌ SMS permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('SMS permission request error: $e');
      return false;
    }

    // Set up MethodChannel listener for new incoming SMS from native BroadcastReceiver
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final sender = call.arguments['sender'] as String? ?? '';
        final body = call.arguments['body'] as String? ?? '';
        await _processSms(sender, body);
      }
    });

    // Read recent SMS inbox to catch any payments that arrived before app opened
    await _scanInbox();

    _isListening = true;
    debugPrint('✅ SMS Auto-Verification started');
    return true;
  }

  /// Stop listening.
  void stopListening() {
    _channel.setMethodCallHandler(null);
    _isListening = false;
    debugPrint('🔴 SMS Auto-Verification stopped');
  }

  /// Scans recent SMS inbox (last 50) for UPI credit messages.
  Future<void> _scanInbox() async {
    try {
      final query = SmsQuery();
      final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 50,
      );
      debugPrint('📬 Scanning ${messages.length} inbox messages...');
      for (final msg in messages) {
        await _processSms(msg.sender ?? '', msg.body ?? '');
      }
    } catch (e) {
      debugPrint('SMS inbox scan error: $e');
    }
  }

  /// Core logic: parse SMS and save to Firestore if it's a UPI credit.
  Future<void> _processSms(String sender, String body) async {
    if (body.isEmpty) return;

    // Filter: must be credit-related
    final bodyLower = body.toLowerCase();
    final isCreditSms = _creditKeywords.any((k) => bodyLower.contains(k));
    final senderUpper = sender.toUpperCase();
    final isKnownSender = _bankSenders.any((s) => senderUpper.contains(s));

    if (!isCreditSms && !isKnownSender) return;

    // Parse 12-digit UTR
    final utrMatch = RegExp(r'\b(\d{12})\b').firstMatch(body);
    if (utrMatch == null) return;
    final utr = utrMatch.group(1)!;

    // Parse Amount (Rs 500, INR 100, ₹200, Rs 1,000.00)
    double amount = 0;
    final amountMatch = RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(body);

    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0;
    } else {
      final fallback = RegExp(
        r'([\d,]+(?:\.\d{1,2})?)\s*(?:credited|received)',
        caseSensitive: false,
      ).firstMatch(body);
      if (fallback != null) {
        amount = double.tryParse(fallback.group(1)!.replaceAll(',', '')) ?? 0;
      }
    }

    if (amount <= 0) return;

    debugPrint('💳 Parsed: UTR=$utr | ₹$amount | From: $sender');
    await _saveToFirestore(utr, amount, sender, body);
  }

  /// Save receipt to Firestore — skips duplicates.
  Future<void> _saveToFirestore(
    String utr,
    double amount,
    String sender,
    String rawText,
  ) async {
    try {
      final existing = await _db
          .collection('bank_receipts')
          .where('utr', isEqualTo: utr)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        debugPrint('⚠️ UTR $utr already stored. Skipping.');
        return;
      }

      await _db.collection('bank_receipts').add({
        'utr': utr,
        'amount': amount,
        'sender': sender,
        'rawText': rawText,
        'isUsed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Receipt saved: UTR=$utr | ₹$amount');
    } catch (e) {
      debugPrint('❌ Firestore save error: $e');
    }
  }
}
