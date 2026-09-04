import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:ff_arena/presentation/widgets/tournament_card.dart';
import 'package:ff_arena/presentation/screens/home/notification_list_screen.dart';
import 'package:ff_arena/data/models/game_mode_model.dart';
import 'package:ff_arena/presentation/screens/home/mode_tournaments_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ff_arena/presentation/screens/home/leaderboard_screen.dart';
import 'package:ff_arena/presentation/screens/profile/refer_earn_screen.dart';
import 'package:ff_arena/presentation/screens/profile/support_chat_screen.dart';
import 'package:ff_arena/presentation/screens/wallet/wallet_screen.dart';
import 'package:ff_arena/presentation/screens/tournament/tournament_details_screen.dart';
import 'package:ff_arena/core/utils/url_utils.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final tournamentProvider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: const Icon(Icons.menu, color: AppColors.primary, size: 20),
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8),
                ],
              ),
              child: const Text(
                "IR BATTLE",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Wallet Balance Quick Chip
          Consumer<AuthProvider>(
            builder: (context, auth, child) {
              final balance = auth.userModel?.balance ?? 0.0;
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10141A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.2),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet, size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        "₹${balance.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.add_circle, size: 13, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),

          // Notification Bell with Badge
          Consumer<AuthProvider>(
            builder: (context, auth, child) {
              final unreadCount = auth.userModel?.unreadNotifications ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 24, color: Colors.white),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationListScreen()));
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.neonRed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: AppColors.neonRed.withValues(alpha: 0.6), blurRadius: 6),
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          unreadCount > 9 ? "9+" : unreadCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportChatScreen()));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined, color: Colors.black, size: 18),
              SizedBox(width: 6),
              Text(
                "AI HELP",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
            ),
          ),
          
          RefreshIndicator(
            onRefresh: () async {},
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  
                  // Featured Slider
                  _buildFeaturedBanner(tournamentProvider),
                  
                  const SizedBox(height: 20),

                  // GAME MODES Grid (dynamic from admin panel)
                  _buildGameModesSection(context, tournamentProvider),

                  const SizedBox(height: 20),

                  // Live Tournaments (Only show if match has an active Live Stream URL attached)
                  StreamBuilder<List<TournamentModel>>(
                    stream: tournamentProvider.liveTournaments(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        final matchesWithLiveLink = snapshot.data!
                            .where((t) => (t.liveStreamUrl ?? '').trim().isNotEmpty)
                            .toList();

                        if (matchesWithLiveLink.isNotEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("LIVE MATCHES", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent, letterSpacing: 1.1)),
                                    Icon(Icons.live_tv, size: 16, color: Colors.redAccent),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildTournamentList(matchesWithLiveLink),
                              const SizedBox(height: 20),
                            ],
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Winning Tip Section
                  _buildWinningTip(),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTournamentsSection(TournamentProvider provider) {
    return StreamBuilder<List<TournamentModel>>(
      stream: provider.freeTournaments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade800, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      "🎁 FREE TOURNAMENTS",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${snapshot.data!.length} OPEN",
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildTournamentList(snapshot.data!),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildCategorySection(String title, Stream<List<TournamentModel>> stream, {IconData? icon, Color? iconColor}) {
    return StreamBuilder<List<TournamentModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: iconColor ?? AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: (iconColor ?? AppColors.primary).withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: iconColor ?? Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Text(
                      "${snapshot.data!.length} MATCHES",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildTournamentList(snapshot.data!),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildWinningTip() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10141A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PRO TIP FOR VICTORY",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Check room ID & password 15 mins before match time. Make sure you play on your registered Free Fire account!",
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedBanner(TournamentProvider provider) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: provider.banners(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildCarousel(snapshot.data!);
      },
    );
  }

  Widget _buildCarousel(List<Map<String, dynamic>> items) {
    return CarouselSlider(
      options: CarouselOptions(
        height: 160.0,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.88,
        autoPlayInterval: const Duration(seconds: 4),
      ),
      items: items.map((data) {
        return Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                final target = data['target']?.toString().toLowerCase();
                if (target == 'refer') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ReferEarnScreen()));
                } else if (target == 'support') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportChatScreen()));
                } else if (target == 'wallet') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
                } else if (target == 'leaderboard') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardScreen()));
                } else if (target == 'link' && data['link'] != null && data['link'].toString().isNotEmpty) {
                  UrlUtils.launchURL(data['link'].toString());
                } else if (target == 'tournament' && data['tournamentId'] != null) {
                  final provider = Provider.of<TournamentProvider>(context, listen: false);
                  provider.getTournamentById(data['tournamentId']).then((tournament) {
                    if (tournament != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => TournamentDetailsScreen(tournament: tournament)));
                    }
                  });
                }
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: 1),
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
                  ],
                  border: Border.all(color: const Color(0xFF30363D)),
                  image: DecorationImage(image: NetworkImage(data['url']!), fit: BoxFit.cover),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? '',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                      ),
                      if (data['sub'] != null && data['sub'].toString().isNotEmpty)
                        Text(
                          data['sub'],
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildDynamicGameModeSections(TournamentProvider provider) {
    return StreamBuilder<List<GameModeModel>>(
      stream: provider.gameModes(onlyActive: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final modes = snapshot.data!;
        return Column(
          children: modes.map((mode) {
            return _buildCategorySection(
              "${mode.title.trim().toUpperCase()} MATCHES",
              provider.tournamentsByGameMode(mode.id, mode.title),
              icon: Icons.sports_esports,
              iconColor: AppColors.primary,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildGameModesSection(BuildContext context, TournamentProvider provider) {
    return StreamBuilder<List<GameModeModel>>(
      stream: provider.gameModes(onlyActive: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final modes = snapshot.data ?? [];

        if (modes.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
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
                    "GAME MODES",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.sports_esports, size: 18, color: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: modes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
                itemBuilder: (context, index) {
                  final mode = modes[index];
                  return _buildGameModeCard(context, mode);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGameModeCard(BuildContext context, GameModeModel mode) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ModeTournamentsScreen(
              gameModeId: mode.id,
              gameModeTitle: mode.title,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF30363D)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (mode.bannerUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: mode.bannerUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary.withValues(alpha: 0.4), AppColors.surface],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => _gameModeGradientBg(mode.title),
                )
              else
                _gameModeGradientBg(mode.title),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                  ),
                ),
              ),

              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.8,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.neonGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "TAP TO PLAY",
                          style: TextStyle(
                            color: AppColors.neonGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameModeGradientBg(String title) {
    // Different gradient per first character of title for variety
    final gradients = [
      [const Color(0xFF1a237e), const Color(0xFF4a148c)],
      [const Color(0xFF004d40), const Color(0xFF1b5e20)],
      [const Color(0xFF880e4f), const Color(0xFF4a148c)],
      [const Color(0xFF0d47a1), const Color(0xFF006064)],
      [const Color(0xFF3e2723), const Color(0xFF212121)],
    ];
    final idx = title.codeUnitAt(0) % gradients.length;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradients[idx][0], gradients[idx][1]],
        ),
      ),
      child: Center(
        child: Icon(Icons.sports_esports, color: Colors.white.withOpacity(0.2), size: 50),
      ),
    );
  }


  Widget _buildTournamentList(List<TournamentModel> tournaments) {
    if (tournaments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text("No tournaments available", style: TextStyle(color: Colors.grey, fontSize: 14)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tournaments.length,
      itemBuilder: (context, index) {
        return TournamentCard(tournament: tournaments[index]);
      },
    );
  }
}
