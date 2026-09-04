import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:ff_arena/data/models/transaction_model.dart';
import 'package:intl/intl.dart';
import 'package:ff_arena/presentation/screens/wallet/deposit_screen.dart';
import 'package:ff_arena/presentation/screens/wallet/withdraw_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text("MY WALLET"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cyber Wallet Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF241C0A), Color(0xFF14171D)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet, color: AppColors.primary.withValues(alpha: 0.8), size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        "TOTAL AVAILABLE BALANCE",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "₹${user?.balance.toStringAsFixed(2) ?? "0.00"}",
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      shadows: [Shadow(blurRadius: 10, color: Color(0x66FFB800))],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars, size: 14, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          "Bonus Balance: ₹${user?.bonusBalance.toStringAsFixed(2) ?? "0.00"}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Deposit & Withdraw Action Buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DepositScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppColors.greenGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: AppColors.neonGreen.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.black, size: 18),
                          SizedBox(width: 6),
                          Text(
                            "ADD CASH",
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const WithdrawScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_circle_up_outlined, color: Colors.black, size: 18),
                          SizedBox(width: 6),
                          Text(
                            "WITHDRAW",
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "RECENT TRANSACTIONS",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildTransactionList(authProvider.transactions),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(Stream<List<TransactionModel>> transactionsStream) {
    return StreamBuilder<List<TransactionModel>>(
      stream: transactionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted),
                  SizedBox(height: 10),
                  Text("No transactions yet", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final tx = snapshot.data![index];
            final isCredit = tx.type == 'deposit' || tx.type == 'prize' || tx.type == 'referral_bonus' || tx.type == 'referral_reward' || tx.type == 'refund';
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCredit ? AppColors.neonGreen.withValues(alpha: 0.15) : AppColors.neonRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isCredit ? AppColors.neonGreen.withValues(alpha: 0.4) : AppColors.neonRed.withValues(alpha: 0.4)),
                    ),
                    child: Icon(
                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isCredit ? AppColors.neonGreen : AppColors.neonRed,
                      size: 18,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFormattedDescription(tx),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(tx.dateTime),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          if (tx.type == 'withdrawal' || tx.type == 'deposit') ...[
                            const SizedBox(width: 8),
                            _buildStatusTag(tx.status),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  "${isCredit ? '+' : '-'} ₹${tx.amount.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: isCredit ? AppColors.neonGreen : AppColors.neonRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  String _getFormattedDescription(TransactionModel tx) {
    if (tx.type == 'deposit') {
      if (tx.status == 'pending') {
        return "Your deposit pending";
      } else if (tx.status == 'success') {
        return "Your deposit successful";
      } else if (tx.status == 'failed') {
        return "Your deposit rejected";
      }
    }
    if (tx.type == 'withdrawal') {
      String desc = tx.description ?? '';
      
      String methodPart = "";
      if (desc.contains("via ")) {
        final splitStr = desc.split("via ");
        if (splitStr.length > 1) {
          final cleanMethod = splitStr[1].replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim();
          if (cleanMethod.isNotEmpty) {
            methodPart = " via $cleanMethod";
          }
        }
      }

      if (tx.status == 'pending') {
        return "Your withdrawal pending$methodPart";
      } else if (tx.status == 'success') {
        return "Your withdrawal successful$methodPart";
      } else if (tx.status == 'failed') {
        return "Your withdrawal rejected$methodPart";
      }
    }
    return tx.description ?? tx.type.toUpperCase();
  }

  Widget _buildStatusTag(String status) {
    Color bg;
    Color fg;
    String text;

    if (status == 'pending') {
      bg = Colors.orange.withValues(alpha: 0.2);
      fg = Colors.orangeAccent;
      text = "PENDING";
    } else if (status == 'success') {
      bg = Colors.green.withValues(alpha: 0.2);
      fg = Colors.greenAccent;
      text = "SUCCESSFUL";
    } else {
      bg = Colors.red.withValues(alpha: 0.2);
      fg = Colors.redAccent;
      text = "REJECTED";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
