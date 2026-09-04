import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/core/constants/app_constants.dart';
import 'package:ff_arena/core/utils/url_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("How To Play"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.rocket_launch), text: "Steps"),
            Tab(icon: Icon(Icons.rule), text: "Rules"),
            Tab(icon: Icon(Icons.quiz), text: "FAQs"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStepsTab(),
          _buildRulesTab(),
          _buildFAQsTab(),
        ],
      ),
    );
  }

  Widget _buildStepsTab() {
    final steps = [
      {
        "num": "1",
        "title": "Wallet Load & Deposit",
        "desc": "Wallet section me jaakar minimum ₹5 add karein. Manual UPI payment karke transaction ID aur screenshot upload karein. Admin verification ke baad balance update ho jayega.",
        "icon": Icons.account_balance_wallet,
        "color": Colors.green,
      },
      {
        "num": "2",
        "title": "Choose & Join Match",
        "desc": "Home screen par CS Rank, BR Rank, ya Lone Wolf matches select karein. Apni Free Fire UID aur original username daalkar join karein. Entry fee auto-deduct ho jayegi.",
        "icon": Icons.sports_esports,
        "color": AppColors.primary,
      },
      {
        "num": "3",
        "title": "Get Room ID & Password",
        "desc": "Match start hone se 15 minute pehle 'Matches' section me jaakar us tournament par click karein. Room ID aur Password wahan update ho jayega.",
        "icon": Icons.vpn_key,
        "color": Colors.cyan,
      },
      {
        "num": "4",
        "title": "Join Room in Free Fire",
        "desc": "Free Fire game open karein, Custom Room section me jaakar Room ID search karein. Password enter karke allocated slot par join karein aur game start hone ka wait karein.",
        "icon": FontAwesomeIcons.gamepad,
        "color": Colors.amber,
      },
      {
        "num": "5",
        "title": "Claim & Withdraw Prizes",
        "desc": "Game khatam hote hi, winner aur per-kill ke points ke hisab se prizes seedhe wallet balance me credit hote hain. Wallet se minimum ₹10 ka withdrawal UPI/Bank me kar sakte hain.",
        "icon": Icons.emoji_events,
        "color": Colors.orangeAccent,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (step['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: step['color'] as Color, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        step['num'] as String,
                        style: TextStyle(fontWeight: FontWeight.bold, color: step['color'] as Color),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: Colors.white10,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(step['icon'] as IconData, size: 20, color: step['color'] as Color),
                            const SizedBox(width: 10),
                            Text(
                              step['title'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step['desc'] as String,
                          style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRulesTab() {
    final rules = [
      {
        "title": "Level 35+ Requirement",
        "desc": "Match ko fair aur competitive rakhne ke liye sirf wahi accounts join kar sakte hain jinka Free Fire Level 35 ya usse zyada hai.",
        "icon": Icons.trending_up,
        "color": Colors.orange,
      },
      {
        "title": "Hacking & Scripts Ban",
        "desc": "Kisi bhi tarah ka mod apk, script, config files ya unfair gameplay use karne par account ko bina kisi refund ke permanent ban kar diya jayega.",
        "icon": Icons.gavel,
        "color": Colors.redAccent,
      },
      {
        "title": "No Teaming Up",
        "desc": "Solo matches me kisi aur player ke saath teaming karne par dono players ki rewards cancel kar di jayengi aur points revoke ho jayenge.",
        "icon": Icons.group_remove,
        "color": Colors.pinkAccent,
      },
      {
        "title": "No Emulator / PC Allowed",
        "desc": "Match sirf Mobile device ke liye hai (unless PC explicitly stated in matching info). Emulator bypass tools ya PC players strictly not allowed.",
        "icon": Icons.computer,
        "color": Colors.blueAccent,
      },
      {
        "title": "Fair Room Conduct",
        "desc": "Room ID aur Password kisi non-registered user ke saath share na karein. Unauthorized joiners ko kick out kar diya jayega aur warning milegi.",
        "icon": Icons.security,
        "color": Colors.green,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.redAccent, size: 24),
                SizedBox(width: 15),
                Expanded(
                  child: Text(
                    "Rules todne par account permanent block hoga aur balance freeze kar diya jayega. Fair khele aur secure rahein!",
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          ...rules.map((rule) {
            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.03)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (rule['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(rule['icon'] as IconData, color: rule['color'] as Color, size: 22),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule['title'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          rule['desc'] as String,
                          style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFAQsTab() {
    final faqs = [
      {
        "q": "Room ID aur Password kab aur kahan milta hai?",
        "a": "Match shuru hone ke theek 15-20 minute pehle 'Matches' section me click karein. Jab aap us tournament ke details me jaoge, toh screen par 'ROOM DETAILS' box me ID aur Password live ho jayenge."
      },
      {
        "q": "Kills aur Winning rewards kab update hote hain?",
        "a": "Match complete hone ke baad admin screen-shots verify karke match results upload karta hai. 1-2 ghante ke andar-andar wallet me balance credit kar diya jaata hai."
      },
      {
        "q": "Deposit request verify hone me kitna time lagta hai?",
        "a": "Manual payments ki verification manually admin dwara ki jaati hai jisme lagbhag 10 minute se lekar 1 ghante tak ka time lag sakta hai. Verify hone par direct main balance me credit ho jayega."
      },
      {
        "q": "Minimum withdrawal limit aur time kya hai?",
        "a": "Minimum withdrawal ₹10 hai. Withdraw karne par transaction 24 ghante ke andar processing complete hone par aapke UPI / Bank account me transfer ho jayegi."
      },
      {
        "q": "Refer & Earn ka reward kab milta hai?",
        "a": "Signup ke waqt referral code daalne par friend ko ₹5 milega. Jab aapka friend apna pehla tournament join karega, tab refer karne wale ko ₹10 milte hain."
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: faqs.length,
      itemBuilder: (context, index) {
        final faq = faqs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: AppColors.surface,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.help_outline, color: AppColors.primary),
              title: Text(
                faq['q']!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: Text(
                    faq['a']!,
                    style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
