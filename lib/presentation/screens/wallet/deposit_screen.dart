import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:ff_arena/data/datasources/tournament_service.dart';
import 'package:ff_arena/core/services/payment_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amountController = TextEditingController();
  final _voucherController = TextEditingController();
  final List<int> _quickAmounts = [10, 50, 100, 200, 500, 1000];
  
  File? _screenshot;
  bool _isLoading = false;
  bool _showScreenshotUpload = false;
  Map<String, dynamic>? _appliedVoucher;

  // 5-minute payment session timer.
  Timer? _timer;
  int _remainingSeconds = 300;
  bool _isTimerExpired = false;

  // Stream listener for zero-effort auto-detection
  StreamSubscription<QuerySnapshot>? _depositSubscription;
  bool _isAutoDetectedSuccess = false;
  final PaymentService _paymentService = PaymentService();
  StreamSubscription<QuerySnapshot>? _bankReceiptSubscription;

  @override
  void initState() {
    super.initState();
    _start10MinuteTimer();
    
  }

  void _start10MinuteTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 300;
      _isTimerExpired = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isTimerExpired = true;
        });
      }
    });
  }

  // ⚡ ZERO-EFFORT AUTO-DETECTION STREAM LISTENER
  void _startZeroEffortAutoDetectListener() {
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) return;

    final startTime = Timestamp.now();

    // 1. Listen for any approved deposit request for this user
    _depositSubscription = FirebaseFirestore.instance
        .collection('deposit_requests')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (_isAutoDetectedSuccess || !mounted) return;

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final data = change.doc.data() ?? {};
          final status = data['status'];
          final docTime = data['dateTime'] as Timestamp?;

          // Check if status is success and arrived during this payment session
          if (status == 'success' && docTime != null && docTime.compareTo(startTime) >= 0) {
            _isAutoDetectedSuccess = true;
            _timer?.cancel();

            final amount = (data['amount'] ?? 0.0).toDouble();
            _showSuccessDialog(amount, "⚡ AUTOMATICALLY DETECTED!\n₹$amount credited to your wallet.");
            break;
          }
        }
      }
    });

    // 2. Listen for incoming bank receipts to auto-credit WITHOUT UTR entry!
    _bankReceiptSubscription = FirebaseFirestore.instance
        .collection('bank_receipts')
        .where('isUsed', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
      if (_isAutoDetectedSuccess || !mounted) return;

      final expectedAmount = double.tryParse(_amountController.text) ?? 0.0;

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() ?? {};
          final receiptAmount = (data['amount'] ?? 0.0).toDouble();
          final utr = (data['utr'] ?? '').toString();
          final createdAt = data['createdAt'] as Timestamp?;

          final isRecent = createdAt == null || createdAt.compareTo(startTime) >= 0;

          if (isRecent && (expectedAmount <= 0 || (receiptAmount - expectedAmount).abs() < 1.0)) {
            _isAutoDetectedSuccess = true;
            _timer?.cancel();

            final success = await TournamentService().autoVerifyReceiptWithoutUtr(
              user.uid,
              change.doc.id,
              receiptAmount,
              utr,
            );

            if (success && mounted) {
              _showSuccessDialog(
                receiptAmount,
                "⚡ INSTANT AUTOMATIC PAYMENT DETECTED!\n₹$receiptAmount credited to your wallet.",
              );
              break;
            } else {
              _isAutoDetectedSuccess = false;
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _depositSubscription?.cancel();
    _paymentService.dispose();
    _amountController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  String _formatTimerText() {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _applyVoucher(String userId) async {
    final code = _voucherController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (code.isEmpty) return;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter amount first"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      final v = await Provider.of<TournamentProvider>(context, listen: false)
          .validateVoucher(code, userId, 'deposit_bonus');

      final minAmount = (v['minAmount'] ?? 0.0).toDouble();
      if (amount < minAmount) {
        throw Exception("Minimum deposit for this voucher is ₹$minAmount");
      }

      setState(() {
        _appliedVoucher = v;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚡ Bonus voucher applied!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _pickScreenshot() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _screenshot = File(pickedFile.path);
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.black),
            const SizedBox(width: 8),
            Text("$label copied to clipboard!"),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _launchUpiApp(String appName, String upiId) async {
    final amount = double.tryParse(_amountController.text) ?? 10;
    
    // Always copy UPI ID to clipboard first
    Clipboard.setData(ClipboardData(text: upiId));

    String? packageName;
    final lowerApp = appName.toLowerCase();
    if (lowerApp.contains('gpay') || lowerApp.contains('google')) {
      packageName = 'com.google.android.apps.nsummit';
    } else if (lowerApp.contains('phonepe')) {
      packageName = 'com.phonepe.app';
    } else if (lowerApp.contains('paytm')) {
      packageName = 'net.one97.paytm';
    } else if (lowerApp.contains('bhim')) {
      packageName = 'in.org.npci.upiapp';
    }

    bool launched = false;

    if (packageName != null) {
      final intentUri = Uri.parse(
        "intent://pay?pa=$upiId&pn=IR%20BATTLE%20Esports&am=$amount&cu=INR&tn=Wallet%20Deposit#Intent;scheme=upi;package=$packageName;end",
      );
      try {
        if (await canLaunchUrl(intentUri)) {
          launched = await launchUrl(intentUri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint("Intent launch error for $packageName: $e");
      }

      // Secondary fallback for GPay package name variation (Tez)
      if (!launched && lowerApp.contains('gpay')) {
        final gpayAltUri = Uri.parse(
          "intent://pay?pa=$upiId&pn=IR%20BATTLE%20Esports&am=$amount&cu=INR&tn=Wallet%20Deposit#Intent;scheme=upi;package=com.google.android.apps.tez;end",
        );
        try {
          if (await canLaunchUrl(gpayAltUri)) {
            launched = await launchUrl(gpayAltUri, mode: LaunchMode.externalApplication);
          }
        } catch (_) {}
      }
    }

    // Generic fallback if specific app package launch failed or wasn't supported
    if (!launched) {
      final upiUri = Uri.parse(
        "upi://pay?pa=$upiId&pn=IR%20BATTLE%20Esports&am=$amount&cu=INR&tn=Wallet%20Deposit",
      );
      try {
        if (await canLaunchUrl(upiUri)) {
          launched = await launchUrl(upiUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? "Opening $appName (UPI ID $upiId copied)"
                : "UPI ID ($upiId) copied to clipboard! Open $appName to pay ₹$amount.",
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _downloadOrViewQr(String qrUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF10141A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("MERCHANT QR SCANNER", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15),
                  ],
                ),
                child: qrUrl.startsWith('http')
                    ? Image.network(qrUrl, height: 220, width: 220, fit: BoxFit.contain)
                    : Image.asset('assets/images/payment_qr.jpeg', height: 220, width: 220),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _copyToClipboard(qrUrl, "QR Image Link");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("📷 Take screenshot or long press to save QR image to gallery!"),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download, color: Colors.black),
                  label: const Text("DOWNLOAD / SAVE QR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitScreenshotRequest() async {
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (amount < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimum deposit amount is ₹5."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_screenshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please upload your payment screenshot."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final isAutoVerified = await Provider.of<TournamentProvider>(context, listen: false).requestDeposit(
        user.uid,
        amount,
        'screenshot-${DateTime.now().millisecondsSinceEpoch}',
        type: 'screenshot',
        imageFile: _screenshot,
        voucherId: _appliedVoucher?['id'],
      );

      if (mounted) {
        if (isAutoVerified) {
          _showSuccessDialog(amount, "⚡ INSTANT AUTO-VERIFIED!\n₹$amount added to your wallet immediately.");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Request submitted! Wallet will auto-update as soon as payment is confirmed."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _paySecurely() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum deposit amount is Rs. 5.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final payment = await _paymentService.startWalletTopUp(
        amountInPaise: (amount * 100).round(),
        userName: user.name ?? '',
        email: user.email ?? '',
        phone: user.phone ?? '',
      );
      if (!mounted) return;
      _timer?.cancel();
      _isAutoDetectedSuccess = true;
      _showSuccessDialog(payment.amount, 'Payment verified securely. Rs. ${payment.amount.toStringAsFixed(2)} has been added to your wallet.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(double amount, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF10141A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              const Text("CASH ADDED!", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.primary)),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text("DONE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final tournamentProvider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("ADD CASH TO WALLET")),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: tournamentProvider.appConfig(),
        builder: (context, snapshot) {
          final config = snapshot.data ?? {};
          final qrCodeUrl = config['qrCodeUrl'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount Input Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10141A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("ENTER AMOUNT (₹)", style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.primary),
                        decoration: const InputDecoration(
                          hintText: "100",
                          prefixText: "₹ ",
                          prefixStyle: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.primary),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _quickAmounts.length,
                          itemBuilder: (context, index) {
                            final val = _quickAmounts[index].toString();
                            final isSelected = _amountController.text == val;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => setState(() => _amountController.text = val),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : const Color(0xFF21262D),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isSelected ? AppColors.primary : Colors.white10),
                                  ),
                                  child: Text(
                                    "+₹$val",
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Voucher Input Box
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _voucherController,
                        decoration: InputDecoration(
                          hintText: "Enter Bonus Voucher Code",
                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          filled: true,
                          fillColor: const Color(0xFF10141A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        enabled: _appliedVoucher == null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _appliedVoucher != null ? () => setState(() => _appliedVoucher = null) : () => _applyVoucher(user?.uid ?? ''),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _appliedVoucher != null ? Colors.redAccent : AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      child: Text(
                        _appliedVoucher != null ? "REMOVE" : "APPLY",
                        style: TextStyle(color: _appliedVoucher != null ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (_appliedVoucher != null) ...[
                  const SizedBox(height: 6),
                  Text("⚡ Voucher Applied: ${_appliedVoucher!['value']}% Bonus will be added!", style: const TextStyle(color: AppColors.neonGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                ],

                const SizedBox(height: 20),

                // 5-minute countdown timer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _isTimerExpired ? Colors.red.withValues(alpha: 0.15) : const Color(0xFF2E2409),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _isTimerExpired ? Colors.redAccent : AppColors.primary, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: (_isTimerExpired ? Colors.red : AppColors.primary).withValues(alpha: 0.2), blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_isTimerExpired ? Colors.redAccent : AppColors.primary).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isTimerExpired ? Icons.timer_off : Icons.timer,
                          color: _isTimerExpired ? Colors.redAccent : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isTimerExpired ? "5-MIN SESSION EXPIRED" : "SCAN & PAY WITHIN 5 MINUTES",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: _isTimerExpired ? Colors.redAccent : AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isTimerExpired
                                  ? "Tap below to restart payment timer"
                                  : "Scan the QR code and complete your payment.",
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isTimerExpired ? Colors.redAccent : AppColors.primary),
                        ),
                        child: Text(
                          _formatTimerText(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _isTimerExpired ? Colors.redAccent : AppColors.primary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // IF TIMER IS EXPIRED: SHOW RESTART BUTTON
                if (_isTimerExpired)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10141A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.history_toggle_off, size: 50, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        const Text("Payment Session Expired", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        const SizedBox(height: 6),
                        const Text("The 5-minute QR code timer has ended for security.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _start10MinuteTimer,
                            icon: const Icon(Icons.refresh, color: Colors.black),
                            label: const Text("RESTART 5-MIN SESSION", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // MERCHANT SCANNER & DOWNLOAD CONTAINER
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10141A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified, color: AppColors.primary, size: 18),
                            SizedBox(width: 6),
                            Text("SCAN QR CODE TO PAY", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8)),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // QR Code Box
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12),
                            ],
                          ),
                          child: qrCodeUrl.isNotEmpty
                              ? Image.network(
                                  qrCodeUrl,
                                  height: 200,
                                  width: 200,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/payment_qr.jpeg', height: 200, width: 200),
                                )
                              : Image.asset('assets/images/payment_qr.jpeg', height: 200, width: 200),
                        ),

                        const SizedBox(height: 14),

                        // DOWNLOAD QR BUTTON
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _downloadOrViewQr(
                              qrCodeUrl.isNotEmpty ? qrCodeUrl : "assets/images/payment_qr.jpeg",
                            ),
                            icon: const Icon(Icons.download, color: AppColors.primary, size: 18),
                            label: const Text("DOWNLOAD / SAVE QR SCANNER", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── UPLOAD PAYMENT SCREENSHOT SECTION (DIRECTLY VISIBLE) ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10141A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _screenshot != null
                            ? AppColors.neonGreen
                            : AppColors.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_screenshot != null ? AppColors.neonGreen : AppColors.primary)
                              .withValues(alpha: 0.15),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_a_photo, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "UPLOAD PAYMENT SCREENSHOT",
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Pay via QR above & upload screenshot here to credit wallet",
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Image Picker Box
                        InkWell(
                          onTap: _pickScreenshot,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _screenshot != null
                                    ? AppColors.neonGreen
                                    : Colors.white24,
                                width: _screenshot != null ? 2 : 1,
                              ),
                            ),
                            child: _screenshot != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(_screenshot!, fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.cloud_upload_outlined, size: 28, color: AppColors.primary),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Tap to Choose Screenshot from Gallery",
                                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        "JPEG, PNG screenshots accepted",
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Submit screenshot for verification
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitScreenshotRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send_rounded, color: Colors.black, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        "SUBMIT PAYMENT SCREENSHOT",
                                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUpiAppPill(String appName, String upiId) {
    return InkWell(
      onTap: () => _launchUpiApp(appName, upiId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.launch, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(appName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
