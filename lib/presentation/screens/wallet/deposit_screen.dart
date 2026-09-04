import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amountController = TextEditingController();
  final _voucherController = TextEditingController();
  final List<int> _quickAmounts = [10, 50, 100, 200, 500, 1000];

  int _step = 1; // 1 = Enter Amount, 2 = QR & Screenshot
  File? _screenshot;
  bool _isLoading = false;
  Map<String, dynamic>? _appliedVoucher;

  @override
  void dispose() {
    _amountController.dispose();
    _voucherController.dispose();
    super.dispose();
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
          content: Text("Please upload your payment screenshot first."),
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
              content: Text("✅ Payment screenshot submitted! Wallet will auto-update upon admin confirmation."),
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
      appBar: AppBar(
        title: const Text("ADD CASH TO WALLET"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 2) {
              setState(() => _step = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: tournamentProvider.appConfig(),
        builder: (context, snapshot) {
          final config = snapshot.data ?? {};
          final qrCodeUrl = config['qrCodeUrl'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _step == 1
                ? _buildStep1AmountInput(user?.uid ?? '')
                : _buildStep2QrAndUpload(qrCodeUrl),
          );
        },
      ),
    );
  }

  // ─── STEP 1: ENTER AMOUNT ───
  Widget _buildStep1AmountInput(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF10141A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 12),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "ENTER DEPOSIT AMOUNT (₹)",
                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primary),
                decoration: const InputDecoration(
                  hintText: "100",
                  prefixText: "₹ ",
                  prefixStyle: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Quick Select Amount:",
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

        const SizedBox(height: 20),

        // Bonus Voucher Box
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF30363D))),
                ),
                textCapitalization: TextCapitalization.characters,
                enabled: _appliedVoucher == null,
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _appliedVoucher != null ? () => setState(() => _appliedVoucher = null) : () => _applyVoucher(userId),
              style: ElevatedButton.styleFrom(
                backgroundColor: _appliedVoucher != null ? Colors.redAccent : AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

        const SizedBox(height: 36),

        // NEXT BUTTON
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(_amountController.text) ?? 0;
              if (amount < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Minimum deposit amount is ₹5."), backgroundColor: Colors.redAccent),
                );
                return;
              }
              setState(() => _step = 2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "NEXT",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1.0),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── STEP 2: SCANNER & DIRECT UPLOAD SCREENSHOT ───
  Widget _buildStep2QrAndUpload(String qrCodeUrl) {
    final amount = double.tryParse(_amountController.text) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Amount Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("AMOUNT TO PAY: ", style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text("₹${amount.toStringAsFixed(0)}", style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _step = 1),
                child: const Row(
                  children: [
                    Icon(Icons.edit, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text("Change", style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── MAIN SCANNER & SCREENSHOT CARD ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF10141A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 12),
            ],
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, color: AppColors.primary, size: 18),
                  SizedBox(width: 6),
                  Text(
                    "SCAN QR CODE TO PAY",
                    style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // QR Code Image
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 15),
                  ],
                ),
                child: qrCodeUrl.isNotEmpty
                    ? Image.network(
                        qrCodeUrl,
                        height: 220,
                        width: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/payment_qr.jpeg', height: 220, width: 220),
                      )
                    : Image.asset('assets/images/payment_qr.jpeg', height: 220, width: 220),
              ),

              const SizedBox(height: 20),

              // ─── BUTTON UNDER SCANNER: UPLOAD PAYMENT SCREENSHOT ───
              if (_screenshot == null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _pickScreenshot,
                    icon: const Icon(Icons.add_a_photo, color: Colors.black, size: 20),
                    label: const Text(
                      "UPLOAD PAYMENT SCREENSHOT",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                  ),
                ),
              ] else ...[
                // SCREENSHOT PREVIEW & CONFIRM BUTTON
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.neonGreen, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_screenshot!, width: 60, height: 60, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Screenshot Selected ✅", style: TextStyle(color: AppColors.neonGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                                SizedBox(height: 2),
                                Text("Tap confirm below to complete deposit", style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _pickScreenshot,
                            child: const Text("Change", style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitScreenshotRequest,
                    icon: _isLoading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                    label: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text(
                            "CONFIRM PAYMENT SCREENSHOT",
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
