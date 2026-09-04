import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class ReferEarnScreen extends StatelessWidget {
  const ReferEarnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final tournamentProvider = Provider.of<TournamentProvider>(context);
    final String referralCode = user?.referralCode ?? user?.uid.substring(0, 8).toUpperCase() ?? "ARENA100";

    return Scaffold(
      appBar: AppBar(
        title: const Text("REFER & EARN"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: "Referral details",
            onPressed: () => _showReferralInfo(context),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: tournamentProvider.appConfig(),
        builder: (context, snapshot) {
          final config = snapshot.data ?? {};
          final String? dynamicBanner = config['referBannerUrl'];
          final referralEarnAmount = config['referralEarnAmount'] ?? 10;
          final referralSignupBonus = config['referralSignupBonus'] ?? 5;
          final String shareUrl = config['appShareUrl'] ?? "https://ffarena.com";
          final inviteMessage = "Join IR BATTLE and earn daily by playing tournaments! Use my referral code: $referralCode Download Now: $shareUrl";

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              children: [
                _buildHero(dynamicBanner),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildRewardCard("YOU EARN", "₹$referralEarnAmount", Icons.account_balance_wallet, Colors.greenAccent)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildRewardCard("FRIEND GETS", "₹$referralSignupBonus", Icons.redeem, Colors.orangeAccent)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildCodeCard(context, referralCode, inviteMessage),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () => Share.share(inviteMessage),
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text("SHARE INVITE NOW", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.6)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _copyText(context, shareUrl, "Invite link copied!"),
                        icon: const Icon(Icons.link, size: 18),
                        label: const Text("COPY INVITE LINK"),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildHero(String? bannerUrl) {
    return Container(
      height: 215,
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: bannerUrl != null ? NetworkImage(bannerUrl) : const AssetImage("assets/images/banner.png") as ImageProvider,
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        alignment: Alignment.bottomLeft,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xF0000000)]),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.card_giftcard_rounded, color: AppColors.primary, size: 30),
            SizedBox(height: 8),
            Text("INVITE FRIENDS. EARN MORE.", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            SizedBox(height: 4),
            Text("Share your code and get rewarded when they join.", style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardCard(String label, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.7)),
          const SizedBox(height: 3),
          Text(amount, style: TextStyle(color: color, fontSize: 23, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildCodeCard(BuildContext context, String code, String inviteMessage) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("YOUR REFERRAL CODE", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text(code, style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2))),
              IconButton(icon: const Icon(Icons.copy_rounded, color: AppColors.primary), tooltip: "Copy referral code", onPressed: () => _copyText(context, code, "Referral code copied!")),
              IconButton(icon: const Icon(Icons.copy_all_rounded, color: Colors.white60), tooltip: "Copy invite message", onPressed: () => _copyText(context, inviteMessage, "Invite message copied!")),
            ],
          ),
        ],
      ),
    );
  }

  void _copyText(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showReferralInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 20, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("HOW IT WORKS", style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text("1. Copy your referral code or invite message.", style: TextStyle(color: Colors.white70)),
              SizedBox(height: 10),
              Text("2. Share it with your friends.", style: TextStyle(color: Colors.white70)),
              SizedBox(height: 10),
              Text("3. Get rewarded when they sign up and join.", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
