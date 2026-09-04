import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ff_arena/core/utils/storage_service.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amountController = TextEditingController();
  File? _scannerImage;
  bool _isLoading = false;
  final List<int> _quickAmounts = [50, 100, 200, 500, 1000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickScanner() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _scannerImage = File(picked.path));
    }
  }

  void _removeScanner() {
    setState(() => _scannerImage = null);
  }

  Future<void> _submit(double balance, TournamentProvider provider, String uid) async {
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (amount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimum withdrawal is ₹10."), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (amount > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient balance."), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_scannerImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload your UPI QR Scanner image."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? scannerUrl;
      final storage = StorageService();
      scannerUrl = await storage.uploadImage('withdrawals', _scannerImage!);

      await provider.requestWithdrawal(uid, amount, '', 'UPI', scannerUrl: scannerUrl);
      if (!mounted) return;
      await Provider.of<AuthProvider>(context, listen: false).refreshUser();
      if (mounted) {
        _showSuccessDialog(amount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(double amount) {
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
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              const Text("REQUEST SUBMITTED!", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary)),
              const SizedBox(height: 8),
              Text(
                "₹${amount.toStringAsFixed(2)} withdrawal request sent!\nIt will be processed within 24 hours.",
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
    final provider = Provider.of<TournamentProvider>(context);
    final balance = user?.balance ?? 0.0;
    final balanceStr = balance.toStringAsFixed(2);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("WITHDRAW MONEY"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ─── BALANCE CARD ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4)),
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "WITHDRAWABLE BALANCE",
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "₹$balanceStr",
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Min withdrawal ₹10 • Processed in 24 hrs",
                    style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── AMOUNT SECTION ───
            const Text(
              "WITHDRAW AMOUNT",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10141A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.primary),
                decoration: const InputDecoration(
                  hintText: "0",
                  prefixText: "₹ ",
                  prefixStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.primary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Quick Amounts
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
                          "₹$val",
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

            const SizedBox(height: 28),

            // ─── QR SCANNER UPLOAD ───
            Row(
              children: [
                Container(
                  width: 4, height: 18,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                const Text(
                  "UPLOAD YOUR UPI QR SCANNER",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Upload your UPI QR code so payment can be sent directly to you.",
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: _pickScanner,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: _scannerImage != null ? 220 : 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF10141A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _scannerImage != null ? AppColors.primary : const Color(0xFF30363D),
                    width: _scannerImage != null ? 2 : 1.5,
                  ),
                  boxShadow: _scannerImage != null
                      ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 12)]
                      : [],
                ),
                child: _scannerImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              _scannerImage!,
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.contain,
                            ),
                          ),
                          // Remove button
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _removeScanner,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                          // Change overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(14),
                                  bottomRight: Radius.circular(14),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit, size: 14, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Text("Tap to change QR", style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.qr_code_2, size: 36, color: AppColors.primary),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "TAP TO UPLOAD YOUR QR SCANNER",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "PhonePe / GPay / Paytm / Any UPI QR",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── INFO BOX ───
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10141A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Withdrawal Info", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        SizedBox(height: 4),
                        Text(
                          "• Minimum withdrawal is ₹10\n• Requests are processed within 24 hours\n• Upload your UPI QR so payment reaches you instantly",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ─── SUBMIT BUTTON ───
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _submit(balance, provider, user?.uid ?? ''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                ),
                child: _isLoading
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, color: Colors.black, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "SUBMIT WITHDRAWAL REQUEST",
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
