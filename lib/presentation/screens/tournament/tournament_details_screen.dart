import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:ff_arena/data/models/registration_model.dart';
import 'package:intl/intl.dart';
import 'package:ff_arena/presentation/screens/tournament/join_tournament_screen.dart';
import 'package:ff_arena/presentation/widgets/prize_breakdown_widget.dart';

class TournamentDetailsScreen extends StatefulWidget {
  final TournamentModel tournament;

  const TournamentDetailsScreen({super.key, required this.tournament});

  @override
  State<TournamentDetailsScreen> createState() => _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen> {
  int _selectedSlot = 0; // 0 = none selected

  String _prizeBreakdown(Map<String, dynamic> result) {
    final parts = <String>[];
    
    final positionPrize = (result['positionPrize'] as num?)?.toDouble() ?? 0;
    final killPrize = (result['killPrize'] as num?)?.toDouble() ?? 0;
    final booyahPrize = (result['booyahPrize'] as num?)?.toDouble() ?? 0;
    
    if (positionPrize > 0) parts.add('Position ₹${_formatAmount(positionPrize)}');
    if (killPrize > 0) parts.add('Kill ₹${_formatAmount(killPrize)}');
    if (booyahPrize > 0) parts.add('Booyah ₹${_formatAmount(booyahPrize)}');
    
    return parts.isEmpty ? '' : parts.join(' • ');
  }

  String _formatAmount(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.userModel;
    final userId = userModel?.uid;
    final tournamentProvider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<RegistrationModel>>(
        stream: tournamentProvider.participants(widget.tournament.id),
        builder: (context, snapshot) {
          final participants = snapshot.data ?? [];
          bool isJoined = participants.any((reg) => reg.userId == userId);

          // Find user's already booked slot
          int mySlot = 0;
          if (isJoined) {
            final myReg = participants.where((r) => r.userId == userId).firstOrNull;
            mySlot = myReg?.slotNumber ?? 0;
          }

          // Build set of taken slots & map of player names by slot
          final Set<int> takenSlots = participants
              .where((r) => r.slotNumber > 0)
              .map((r) => r.slotNumber)
              .toSet();

          final Map<int, String> slotPlayerNames = {
            for (var r in participants)
              if (r.slotNumber > 0) r.slotNumber: r.userName
          };

          return CustomScrollView(
            slivers: [
              // ─── HERO SLIVER APP BAR ───
              SliverAppBar(
                expandedHeight: 230,
                pinned: true,
                backgroundColor: AppColors.background,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.tournament.imageUrl.isNotEmpty)
                        Image.network(
                          widget.tournament.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.sports_esports, size: 64, color: AppColors.primary),
                          ),
                        )
                      else
                        Container(color: AppColors.surface),

                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                              AppColors.background.withValues(alpha: 0.95),
                              AppColors.background,
                            ],
                            stops: const [0.0, 0.4, 0.85, 1.0],
                          ),
                        ),
                      ),

                      // Status Badge & Tournament Tag on top of image
                      Positioned(
                        bottom: 16,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildBadge(
                                  widget.tournament.status.toUpperCase(),
                                  widget.tournament.status == 'upcoming'
                                      ? AppColors.neonGreen
                                      : (widget.tournament.status == 'live' ? AppColors.neonRed : Colors.cyanAccent),
                                ),
                                const SizedBox(width: 8),
                                _buildBadge(widget.tournament.mode.toUpperCase(), AppColors.primary),
                                const SizedBox(width: 8),
                                _buildBadge(widget.tournament.matchType.toUpperCase(), Colors.white),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.tournament.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── BODY CONTENT ───
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Blocked User Alert
                        if (userModel?.isBlocked ?? false)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.block, color: Colors.redAccent, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "YOUR ACCOUNT IS BLOCKED! You cannot join matches.",
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ─── ROOM CREDENTIALS (If Joined) ───
                        if (isJoined)
                          _buildRoomInfo(widget.tournament),

                        // ─── 4 HIGHLIGHT STAT CARDS ───
                        _buildHighlightStatsGrid(participants.length),

                        const SizedBox(height: 16),

                        // ─── MATCH CONFIGURATION DETAILS GRID ───
                        _buildMatchDetailsGrid(),

                        const SizedBox(height: 24),

                        // ─── PRIZE BREAKDOWN SECTION ───
                        if (widget.tournament.prizeBreakdown.isNotEmpty) ...[
                          PrizeBreakdownWidget(prizeBreakdown: widget.tournament.prizeBreakdown),
                          const SizedBox(height: 24),
                        ],

                        // ─── UPCOMING ONLY SECTIONS (Match Rules, Slots Grid, Joined Players) ───
                        if (widget.tournament.status.toLowerCase() == 'upcoming') ...[
                          const SizedBox(height: 24),
                          _buildRulesCard(),

                          const SizedBox(height: 24),
                          _buildSlotSection(
                            takenSlots: takenSlots,
                            slotPlayerNames: slotPlayerNames,
                            isJoined: isJoined,
                            mySlot: mySlot,
                          ),

                          const SizedBox(height: 24),
                          _buildJoinedPlayersSection(tournamentProvider),
                        ],

                        // ─── RESULTS SECTION (Shown when LIVE or COMPLETED) ───
                        if (widget.tournament.status.toLowerCase() != 'upcoming') ...[
                          const SizedBox(height: 24),
                          _buildResultsSection(tournamentProvider),
                        ],

                        const SizedBox(height: 100), // Space for bottom action bar
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),

      // ─── STICKY BOTTOM ACTION BAR ───
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: StreamBuilder<List<RegistrationModel>>(
        stream: Provider.of<TournamentProvider>(context, listen: false).participants(widget.tournament.id),
        builder: (context, snapshot) {
          final participants = snapshot.data ?? [];
          bool isJoined = participants.any((reg) => reg.userId == userId);

          if (isJoined) {
            return Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00B248)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 12),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.black, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "ALREADY JOINED",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.8),
                  ),
                ],
              ),
            );
          }

          if (userModel?.isBlocked ?? false) {
            return Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text("ACCOUNT BLOCKED", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            );
          }

          if (widget.tournament.status != 'upcoming') {
            return Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Center(
                child: Text(
                  "MATCH ${widget.tournament.status.toUpperCase()}",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
              ),
            );
          }

          final bool slotRequired = widget.tournament.totalSlots > 0;
          final bool slotSelected = _selectedSlot > 0;
          final bool canJoin = !slotRequired || slotSelected;

          return SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: 54,
            child: ElevatedButton(
              onPressed: canJoin
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JoinTournamentScreen(
                            tournament: widget.tournament,
                            selectedSlot: _selectedSlot,
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: const Color(0xFF21262D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!canJoin) ...[
                    const Icon(Icons.touch_app, color: Colors.white38, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "TAP A SLOT ABOVE TO JOIN",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 0.5),
                    ),
                  ] else if (widget.tournament.isFree) ...[
                    const Icon(Icons.card_giftcard, color: Colors.black, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "JOIN FREE${_selectedSlot > 0 ? ' • SLOT #$_selectedSlot' : ''}",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.5),
                    ),
                  ] else ...[
                    const Icon(Icons.sports_esports, color: Colors.black, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "JOIN NOW (₹${_formatAmount(widget.tournament.entryFee)})${_selectedSlot > 0 ? ' • SLOT #$_selectedSlot' : ''}",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.5),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── HIGHLIGHT STAT CARDS (ONLY SHOW ENTERED FIELDS) ───
  // ─── HIGHLIGHT STAT CARDS (ONLY SHOW ENTERED FIELDS) ───
  Widget _buildHighlightStatsGrid(int currentJoined) {
    final t = widget.tournament;
    final isFull = currentJoined >= t.totalSlots && t.totalSlots > 0;

    final List<Widget> cards = [];

    // Prize Pool Card (Only if > 0)
    if (t.prizePool > 0) {
      cards.add(
        _statCard(
          title: "PRIZE POOL",
          value: "₹${_formatAmount(t.prizePool)}",
          icon: Icons.emoji_events,
          color: AppColors.primary,
          bgColor: const Color(0xFF2E2409),
        ),
      );
    }

    // Booyah Pool Card (Only if > 0)
    if (t.booyahPool > 0) {
      cards.add(
        _statCard(
          title: "BOOYAH POOL",
          value: "₹${_formatAmount(t.booyahPool)}",
          icon: Icons.military_tech,
          color: Colors.amberAccent,
          bgColor: const Color(0xFF2E2409),
        ),
      );
    }

    // Entry Fee Card (Always shown: FREE or Amount)
    cards.add(
      _statCard(
        title: "ENTRY FEE",
        value: t.isFree ? "FREE 🎁" : "₹${_formatAmount(t.entryFee)}",
        icon: Icons.confirmation_number,
        color: t.isFree ? AppColors.neonGreen : Colors.white,
        bgColor: const Color(0xFF10141A),
      ),
    );

    // Per Kill Card (Only if > 0)
    if (t.perKillPrize > 0) {
      cards.add(
        _statCard(
          title: "PER KILL",
          value: "₹${_formatAmount(t.perKillPrize)}",
          icon: Icons.gps_fixed,
          color: AppColors.accent,
          bgColor: const Color(0xFF10141A),
        ),
      );
    }

    // Slots Card (Only if > 0)
    if (t.totalSlots > 0) {
      cards.add(
        _statCard(
          title: "SLOTS",
          value: "$currentJoined/${t.totalSlots}",
          icon: isFull ? Icons.lock : Icons.people,
          color: isFull ? AppColors.neonRed : AppColors.neonGreen,
          bgColor: const Color(0xFF10141A),
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    // If 1 to 3 cards: Single Row
    if (cards.length <= 3) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    // If 4 cards: 2 x 2 grid
    if (cards.length == 4) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 8),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 8),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    // If 5 cards: Row of 3 (Top) + Row of 2 (Bottom)
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 8),
            Expanded(child: cards[1]),
            const SizedBox(width: 8),
            Expanded(child: cards[2]),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: cards[3]),
            const SizedBox(width: 8),
            Expanded(child: cards[4]),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 6),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 10, 
                color: Colors.white.withValues(alpha: 0.7), 
                fontWeight: FontWeight.w800, 
                letterSpacing: 0.5
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── MATCH DETAILS GRID CARDS (DYNAMICALLY HIDES UNENTERED FIELDS) ───
  Widget _buildMatchDetailsGrid() {
    final t = widget.tournament;
    final dateStr = DateFormat('dd MMM yyyy').format(t.dateTime);
    final timeStr = DateFormat('hh:mm a').format(t.dateTime);

    final List<Widget> items = [];

    // Schedule - Always shown
    items.add(_detailRowItem(Icons.calendar_month, "Date", dateStr, AppColors.primary));
    items.add(_detailRowItem(Icons.access_time, "Time", timeStr, AppColors.accent));

    // Mode & Match Type - Always shown if filled
    if (t.mode.trim().isNotEmpty) {
      items.add(_detailRowItem(Icons.sports_esports, "Mode", t.mode.trim(), AppColors.neonGreen));
    }
    if (t.matchType.trim().isNotEmpty) {
      items.add(_detailRowItem(Icons.groups, "Match Type", t.matchType.trim(), Colors.orangeAccent));
    }

    // Map - Only if filled by Admin
    if (t.map.trim().isNotEmpty) {
      items.add(_detailRowItem(Icons.map, "Map", t.map.trim(), Colors.purpleAccent));
    }

    // Version - Only if filled by Admin
    if (t.version.trim().isNotEmpty) {
      items.add(_detailRowItem(Icons.verified, "Version", t.version.trim(), Colors.blueAccent));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    // Build 2-column grid rows
    final List<Widget> rows = [];
    for (int i = 0; i < items.length; i += 2) {
      if (i > 0) {
        rows.add(const Divider(color: Color(0xFF30363D), height: 24));
      }
      final first = items[i];
      final second = (i + 1 < items.length) ? items[i + 1] : null;

      rows.add(
        Row(
          children: [
            Expanded(child: first),
            if (second != null) ...[
              Container(width: 1, height: 35, color: const Color(0xFF30363D)),
              Expanded(child: second),
            ] else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10141A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(children: rows),
    );
  }

  Widget _detailRowItem(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── ROOM CREDENTIALS CARD ───
  Widget _buildRoomInfo(TournamentModel t) {
    final hasRoomInfo = (t.roomId != null && t.roomId!.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10141A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                "ROOM ID & PASSWORD",
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.0, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasRoomInfo ? AppColors.neonGreen.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hasRoomInfo ? AppColors.neonGreen : Colors.amber),
                ),
                child: Text(
                  hasRoomInfo ? "RELEASED ✓" : "15 MINS BEFORE",
                  style: TextStyle(color: hasRoomInfo ? AppColors.neonGreen : Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (hasRoomInfo) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Room ID:", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Row(
                        children: [
                          SelectableText(
                            t.roomId!,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16, color: AppColors.primary),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: t.roomId!));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Room ID copied!")));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF30363D), height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Password:", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Row(
                        children: [
                          SelectableText(
                            t.roomPassword ?? 'None',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary, letterSpacing: 1),
                          ),
                          const SizedBox(width: 6),
                          if (t.roomPassword != null && t.roomPassword!.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16, color: AppColors.primary),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: t.roomPassword!));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password copied!")));
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Room ID and Password will be posted here exactly 15 minutes before match start time.",
                      style: TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── MATCH RULES SECTION (ONLY IF RULES ENTERED) ───
  Widget _buildRulesCard() {
    final rules = widget.tournament.rules.trim();
    if (rules.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10141A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text(
                "MATCH RULES & INSTRUCTIONS",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rules,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── SLOT GRID SECTION (FREE FIRE CUSTOM ROOM LOBBY STYLE) ───
  Widget _buildSlotSection({
    required Set<int> takenSlots,
    required Map<int, String> slotPlayerNames,
    required bool isJoined,
    required int mySlot,
  }) {
    final int total = widget.tournament.totalSlots;
    if (total <= 0) return const SizedBox.shrink();

    final matchType = widget.tournament.matchType.toLowerCase();
    final int teamSize = matchType == 'squad' ? 4 : (matchType == 'duo' ? 2 : 1);
    final int totalTeams = (total / teamSize).ceil();
    final int filledSlotsCount = takenSlots.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(
              teamSize > 1 ? "SELECT YOUR TEAM SLOT (${matchType.toUpperCase()})" : "SELECT YOUR SLOT (SOLO)",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: filledSlotsCount >= total ? AppColors.neonRed.withValues(alpha: 0.15) : AppColors.neonGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: filledSlotsCount >= total ? AppColors.neonRed : AppColors.neonGreen),
              ),
              child: Text(
                "$filledSlotsCount/$total FILLED",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: filledSlotsCount >= total ? AppColors.neonRed : AppColors.neonGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Legend row
        Row(
          children: [
            _legendDot(AppColors.neonGreen, "Available"),
            const SizedBox(width: 14),
            _legendDot(const Color(0xFFFFD54F), "Occupied"),
            const SizedBox(width: 14),
            _legendDot(AppColors.primary, "Selected"),
            if (mySlot > 0) ...[
              const SizedBox(width: 14),
              _legendDot(AppColors.accent, "Yours"),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ─── TEAM BOXES GRID (SOLO / DUO / SQUAD) ───
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: teamSize == 4 ? 1 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: teamSize == 4 ? 2.4 : (teamSize == 2 ? 1.8 : 3.6),
          ),
          itemCount: totalTeams,
          itemBuilder: (context, teamIndex) {
            final int teamNum = teamIndex + 1;
            final int startSlot = (teamIndex * teamSize) + 1;
            final List<int> teamSlotNumbers = List.generate(
              teamSize,
              (i) => startSlot + i,
            ).where((s) => s <= total).toList();

            return _buildTeamCard(
              teamNumber: teamNum,
              slotNumbers: teamSlotNumbers,
              takenSlots: takenSlots,
              slotPlayerNames: slotPlayerNames,
              isJoined: isJoined,
              mySlot: mySlot,
            );
          },
        ),

        const SizedBox(height: 12),
        if (!isJoined && widget.tournament.totalSlots > 0)
          Text(
            _selectedSlot > 0
                ? "✅ Slot #$_selectedSlot selected — tap JOIN NOW below"
                : "👆 Tap an available slot to select it",
            style: TextStyle(
              color: _selectedSlot > 0 ? AppColors.neonGreen : AppColors.textMuted,
              fontSize: 12,
              fontWeight: _selectedSlot > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
      ],
    );
  }

  Widget _buildTeamCard({
    required int teamNumber,
    required List<int> slotNumbers,
    required Set<int> takenSlots,
    required Map<int, String> slotPlayerNames,
    required bool isJoined,
    required int mySlot,
  }) {
    final letters = ['A', 'B', 'C', 'D'];
    final int filledInTeam = slotNumbers.where((s) => takenSlots.contains(s)).length;
    final bool isTeamFull = filledInTeam == slotNumbers.length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12161F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTeamFull
              ? Colors.redAccent.withValues(alpha: 0.4)
              : (filledInTeam > 0 ? AppColors.primary.withValues(alpha: 0.5) : const Color(0xFF2A313D)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── LEFT SIDE TEAM NUMBER BANNER ───
            Container(
              width: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isTeamFull
                      ? [const Color(0xFF3D141A), const Color(0xFF200A0D)]
                      : (filledInTeam > 0
                          ? [const Color(0xFF3D2E14), const Color(0xFF20160A)]
                          : [const Color(0xFF1C222E), const Color(0xFF141822)]),
                ),
                border: const Border(
                  right: BorderSide(color: Color(0xFF2A313D), width: 1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "TEAM",
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    teamNumber < 10 ? "0$teamNumber" : "$teamNumber",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            // ─── RIGHT SIDE STACKED SUB-SLOTS (A, B, C, D) ───
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(slotNumbers.length, (index) {
                    final slotNum = slotNumbers[index];
                    final letter = index < letters.length ? letters[index] : '${index + 1}';
                    final isTaken = takenSlots.contains(slotNum);
                    final playerName = slotPlayerNames[slotNum] ?? '';
                    final isMySlot = mySlot == slotNum;
                    final isSelected = _selectedSlot == slotNum;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: index < slotNumbers.length - 1 ? 3 : 0),
                        child: _buildSlotRow(
                          letter: letter,
                          slotNum: slotNum,
                          isTaken: isTaken,
                          playerName: playerName,
                          isMySlot: isMySlot,
                          isSelected: isSelected,
                          isJoined: isJoined,
                          onTap: (isTaken || isJoined)
                              ? null
                              : () {
                                  setState(() {
                                    _selectedSlot = isSelected ? 0 : slotNum;
                                  });
                                },
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotRow({
    required String letter,
    required int slotNum,
    required bool isTaken,
    required String playerName,
    required bool isMySlot,
    required bool isSelected,
    required bool isJoined,
    required VoidCallback? onTap,
  }) {
    Color bgColor;
    Color borderColor;
    Widget contentWidget;

    if (isMySlot) {
      bgColor = const Color(0xFF1E3A2B);
      borderColor = AppColors.neonGreen;
      contentWidget = Row(
        children: [
          Expanded(
            child: Text(
              playerName.isNotEmpty ? playerName : "YOU",
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.neonGreen,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.neonGreen,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              "YOU",
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black),
            ),
          ),
        ],
      );
    } else if (isTaken) {
      bgColor = const Color(0xFF382613);
      borderColor = const Color(0xFF6E4C23);
      contentWidget = Row(
        children: [
          const Icon(Icons.shield, size: 10, color: Color(0xFFFFD54F)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              playerName.isNotEmpty ? playerName : "PLAYING",
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFFF8E1),
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (isSelected) {
      bgColor = AppColors.primary.withValues(alpha: 0.25);
      borderColor = AppColors.primary;
      contentWidget = Row(
        children: [
          Text(
            "SLOT #$slotNum",
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          const Icon(Icons.check_circle, size: 12, color: AppColors.primary),
        ],
      );
    } else {
      bgColor = const Color(0xFF0F141C);
      borderColor = const Color(0xFF252D3A);
      contentWidget = Row(
        children: [
          Text(
            "#$slotNum",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            "Available",
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: borderColor,
            width: isSelected || isMySlot ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 6)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isTaken
                    ? const Color(0xFF52391C)
                    : (isSelected ? AppColors.primary : const Color(0xFF1E2633)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? Colors.black
                      : (isTaken ? const Color(0xFFFFD54F) : Colors.white60),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: contentWidget),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  // ─── JOINED PLAYERS LIST SECTION ───
  Widget _buildJoinedPlayersSection(TournamentProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text("JOINED PLAYERS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<RegistrationModel>>(
          stream: provider.participants(widget.tournament.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator(color: AppColors.primary);
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("No players joined yet.", style: TextStyle(color: AppColors.textMuted, fontSize: 12));

            final currentUserId = context.read<AuthProvider>().userModel?.uid;
            final participants = List<RegistrationModel>.from(snapshot.data!)
              ..sort((a, b) {
                // Show the signed-in player's card first, then list everybody
                // else by their booked slot number.
                final aIsCurrentUser = a.userId == currentUserId;
                final bIsCurrentUser = b.userId == currentUserId;
                if (aIsCurrentUser != bIsCurrentUser) return aIsCurrentUser ? -1 : 1;

                final aSlot = a.slotNumber > 0 ? a.slotNumber : 999999;
                final bSlot = b.slotNumber > 0 ? b.slotNumber : 999999;
                return aSlot.compareTo(bSlot);
              });

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final reg = participants[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.surfaceLight,
                        backgroundImage: (reg.userProfilePic != null && reg.userProfilePic!.isNotEmpty)
                            ? NetworkImage(reg.userProfilePic!)
                            : null,
                        child: (reg.userProfilePic == null || reg.userProfilePic!.isEmpty)
                            ? const Icon(Icons.person, size: 18, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reg.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(
                              "FF ID: ${reg.ffUid} | Team: ${reg.teamName}",
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (reg.slotNumber > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            "#${reg.slotNumber}",
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ─── RESULTS SECTION (Pro Survival eSports Scorecard) ───
  Widget _buildResultsSection(TournamentProvider provider) {
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).userModel?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text("SURVIVAL MATCH SCORECARD & RESULTS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
          ],
        ),
        const SizedBox(height: 12),

        StreamBuilder<List<Map<String, dynamic>>>(
          stream: provider.results(widget.tournament.id),
          builder: (context, resSnapshot) {
            if (resSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
            }
            if (!resSnapshot.hasData || resSnapshot.data!.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 36, color: Colors.grey),
                    SizedBox(height: 8),
                    Text("Results not declared yet", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text("Admin will calculate and declare Survival match results here once match ends.", style: TextStyle(color: AppColors.textMuted, fontSize: 11), textAlign: TextAlign.center),
                  ],
                ),
              );
            }

            final results = List<Map<String, dynamic>>.from(resSnapshot.data!);
            results.sort((a, b) {
              final rA = (a['rank'] as num?)?.toInt() ?? 0;
              final rB = (b['rank'] as num?)?.toInt() ?? 0;
              if (rA == 0 && rB == 0) return 0;
              if (rA == 0) return 1;
              if (rB == 0) return -1;
              return rA.compareTo(rB);
            });

            // Stats calculation
            int totalMatchKills = 0;
            double totalPrizeDistributed = 0.0;
            Map<String, dynamic>? mvpPlayer;
            int maxKills = -1;

            for (var r in results) {
              final kills = (r['kills'] as num?)?.toInt() ?? 0;
              final prize = (r['prizeWon'] as num?)?.toDouble() ?? 0.0;
              totalMatchKills += kills;
              totalPrizeDistributed += prize;
              if (kills > maxKills) {
                maxKills = kills;
                mvpPlayer = r;
              }
            }

            final booyahWinner = results.firstWhere(
              (r) => ((r['rank'] as num?)?.toInt() ?? 0) == 1,
              orElse: () => results.first,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🏆 Match Stats Overview Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10141A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (totalMatchKills > 0 || widget.tournament.perKillPrize > 0) ...[
                        _buildSummaryTile("TOTAL KILLS", "$totalMatchKills", Icons.local_fire_department, AppColors.neonRed),
                        Container(width: 1, height: 26, color: Colors.white10),
                      ],
                      _buildSummaryTile("PRIZE PAID", "₹${totalPrizeDistributed.toStringAsFixed(0)}", Icons.payments, AppColors.neonGreen),
                      if (mvpPlayer != null && maxKills > 0) ...[
                        Container(width: 1, height: 26, color: Colors.white10),
                        _buildSummaryTile("MATCH MVP", "${mvpPlayer['playerName'] ?? 'MVP'} ($maxKills K)", Icons.stars, AppColors.primary),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 👑 BOOYAH CHAMPION SPOTLIGHT (Rank 1)
                if (booyahWinner != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E2300), Color(0xFF1A1400)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: 1),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.emoji_events, size: 12, color: Colors.black),
                                  SizedBox(width: 4),
                                  Text("BOOYAH! CHAMPION", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                            Text(
                              "₹${((booyahWinner['prizeWon'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} WON",
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primary,
                              child: const Text("👑", style: TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    booyahWinner['playerName'] ?? 'Champion',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    "UID: ${booyahWinner['ffUid'] ?? 'N/A'}",
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if ((booyahWinner['kills'] as num? ?? 0) > 0 || widget.tournament.perKillPrize > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.gps_fixed, size: 12, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text("${booyahWinner['kills']} Kills", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 📊 Full Survival Match Scoreboard List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: results.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final res = results[index];
                    final declaredRank = (res['rank'] as num?)?.toInt() ?? 0;
                    final rankNum = declaredRank > 0 ? declaredRank : index + 1;
                    final isMyRow = currentUserId != null && res['userId'] == currentUserId;
                    final prizeWon = (res['prizeWon'] as num?)?.toDouble() ?? 0.0;
                    final kills = (res['kills'] as num?)?.toInt() ?? 0;
                    final prizeBreakdownStr = _prizeBreakdown(res);

                    Color rankColor;
                    IconData? rankIcon;
                    if (rankNum == 1) {
                      rankColor = const Color(0xFFFFD700);
                      rankIcon = Icons.military_tech;
                    } else if (rankNum == 2) {
                      rankColor = const Color(0xFFC0C0C0);
                    } else if (rankNum == 3) {
                      rankColor = const Color(0xFFCD7F32);
                    } else {
                      rankColor = Colors.white54;
                    }

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMyRow
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : rankNum == 1
                                ? AppColors.primary.withValues(alpha: 0.06)
                                : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMyRow
                              ? AppColors.neonGreen
                              : rankNum == 1
                                  ? AppColors.primary.withValues(alpha: 0.6)
                                  : const Color(0xFF30363D),
                          width: isMyRow ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Rank Badge
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: rankColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: rankColor.withValues(alpha: 0.6)),
                            ),
                            child: Center(
                              child: rankIcon != null
                                  ? Icon(rankIcon, size: 18, color: rankColor)
                                  : Text(
                                      "#$rankNum",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: rankColor),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Player Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        res['playerName'] ?? 'Unknown Gamer',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isMyRow ? AppColors.neonGreen : Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isMyRow) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.neonGreen,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text("YOU", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "UID: ${res['ffUid'] ?? 'N/A'}${prizeBreakdownStr.isNotEmpty ? ' • $prizeBreakdownStr' : ''}",
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),

                          // Kills & Prize Column
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (kills > 0 || widget.tournament.perKillPrize > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "$kills Kills",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                                  ),
                                ),
                              if (prizeWon > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "+₹${prizeWon.toStringAsFixed(0)}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.neonGreen),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
