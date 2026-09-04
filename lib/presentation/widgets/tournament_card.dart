import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:intl/intl.dart';
import 'package:ff_arena/presentation/screens/tournament/tournament_details_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class TournamentCard extends StatelessWidget {
  final TournamentModel tournament;

  const TournamentCard({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final int slotsLeft = (tournament.totalSlots - tournament.filledSlots).clamp(0, tournament.totalSlots);
    final double fillRatio = tournament.totalSlots > 0 ? (tournament.filledSlots / tournament.totalSlots).clamp(0.0, 1.0) : 0.0;
    final bool isFull = slotsLeft == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (tournament.isMega)
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: 1),
          if (tournament.isFree)
            BoxShadow(color: AppColors.neonGreen.withValues(alpha: 0.2), blurRadius: 16, spreadRadius: 1),
          if (tournament.status == 'live')
            BoxShadow(color: AppColors.neonRed.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: 1),
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(
          color: tournament.isMega
              ? AppColors.primary.withValues(alpha: 0.6)
              : tournament.isFree
                  ? AppColors.neonGreen.withValues(alpha: 0.5)
                  : tournament.status == 'live'
                      ? AppColors.neonRed.withValues(alpha: 0.6)
                      : const Color(0xFF30363D),
          width: tournament.isMega || tournament.isFree || tournament.status == 'live' ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TournamentDetailsScreen(tournament: tournament)),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section with Badges
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                    child: Stack(
                      children: [
                        Image.network(
                          tournament.imageUrl,
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 130,
                            color: AppColors.surfaceLight,
                            child: const Center(
                              child: Icon(Icons.sports_esports, size: 50, color: Colors.white24),
                            ),
                          ),
                        ),
                        // Dark bottom gradient overlay for smooth text pop
                        Container(
                          height: 130,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Top Left Badges (Status / Mega / Free)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: [
                        if (tournament.isMega)
                          _cyberBadge("⚡ MEGA", AppColors.primary, Colors.black)
                        else if (tournament.status == 'live')
                          _cyberBadge("🔴 LIVE", AppColors.neonRed, Colors.white)
                        else
                          _cyberBadge(tournament.status.toUpperCase(), AppColors.primary, Colors.black),
                        if (tournament.isFree) ...[
                          const SizedBox(width: 6),
                          _cyberBadge("🎁 FREE", AppColors.neonGreen, Colors.black),
                        ],
                      ],
                    ),
                  ),

                  // Top Right Badges (Mode & Match Type)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      children: [
                        _glassBadge(tournament.mode, AppColors.accent),
                        const SizedBox(width: 5),
                        _glassBadge(tournament.matchType.toUpperCase(), Colors.white70),
                      ],
                    ),
                  ),

                  // Watch Live button if live
                  if (tournament.status == 'live' && tournament.liveStreamUrl != null && tournament.liveStreamUrl!.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => launchUrl(Uri.parse(tournament.liveStreamUrl!)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFD50000)]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: AppColors.neonRed.withValues(alpha: 0.5), blurRadius: 8),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _getPlatformIcon(tournament.platform),
                              const SizedBox(width: 5),
                              const Text("WATCH LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Map badge bottom-left
                  Positioned(
                    bottom: 8,
                    left: 10,
                    child: Row(
                      children: [
                        const Icon(Icons.map_outlined, size: 13, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          tournament.map.toUpperCase(),
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Title & Info Details Section
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      tournament.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),

                    // Time Row
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM, hh:mm a').format(tournament.dateTime),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 3-Column Stats Grid (Prize Pool, Entry Fee, Per Kill)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10141A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF21262D)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (tournament.prizePool > 0) ...[
                            _statTile(
                              "PRIZE POOL",
                              "₹${tournament.prizePool.toStringAsFixed(0)}",
                              Icons.emoji_events,
                              AppColors.primary,
                            ),
                            Container(width: 1, height: 26, color: const Color(0xFF21262D)),
                          ],
                          if (tournament.booyahPool > 0) ...[
                            _statTile(
                              "BOOYAH POOL",
                              "₹${tournament.booyahPool.toStringAsFixed(0)}",
                              Icons.military_tech,
                              Colors.amberAccent,
                            ),
                            Container(width: 1, height: 26, color: const Color(0xFF21262D)),
                          ],
                          _statTile(
                            "ENTRY",
                            tournament.isFree ? "FREE" : "₹${tournament.entryFee.toStringAsFixed(0)}",
                            Icons.confirmation_number_outlined,
                            tournament.isFree ? AppColors.neonGreen : Colors.white,
                          ),
                          if (tournament.perKillPrize > 0) ...[
                            Container(width: 1, height: 26, color: const Color(0xFF21262D)),
                            _statTile(
                              "PER KILL",
                              "₹${tournament.perKillPrize.toStringAsFixed(0)}",
                              Icons.gps_fixed,
                              AppColors.accent,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Slots Progress & CTA Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isFull ? "🔴 FULL" : "⚡ $slotsLeft SLOTS LEFT",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isFull ? AppColors.neonRed : AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    "${tournament.filledSlots}/${tournament.totalSlots}",
                                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: fillRatio,
                                  backgroundColor: const Color(0xFF21262D),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isFull
                                        ? AppColors.neonRed
                                        : fillRatio > 0.8
                                            ? Colors.orangeAccent
                                            : AppColors.primary,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Join / View Action Pill Button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isFull
                                ? const LinearGradient(colors: [Color(0xFF30363D), Color(0xFF21262D)])
                                : AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              if (!isFull)
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isFull ? "DETAILS" : "JOIN",
                                style: TextStyle(
                                  color: isFull ? Colors.white60 : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                size: 13,
                                color: isFull ? Colors.white60 : Colors.black,
                              ),
                            ],
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

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _cyberBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: bgColor.withValues(alpha: 0.4), blurRadius: 6),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
      ),
    );
  }

  Widget _glassBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
      ),
    );
  }

  Widget _getPlatformIcon(String? platform) {
    switch (platform?.toLowerCase()) {
      case 'youtube':
        return const FaIcon(FontAwesomeIcons.youtube, size: 12, color: Colors.white);
      default:
        return const Icon(Icons.live_tv, size: 12, color: Colors.white);
    }
  }
}
