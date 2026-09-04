import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class LuckySpinScreen extends StatefulWidget {
  const LuckySpinScreen({super.key});

  @override
  State<LuckySpinScreen> createState() => _LuckySpinScreenState();
}

class _LuckySpinScreenState extends State<LuckySpinScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool _isSpinning = false;
  bool _hasSpunToday = false;
  String? _result;
  int _selectedSegment = 0;

  final List<_SpinPrize> _prizes = [
    _SpinPrize('₹5 Cash', Colors.amber, Icons.currency_rupee, 5.0, 'cash'),
    _SpinPrize('Try Again', Colors.grey.shade700, Icons.refresh, 0.0, 'none'),
    _SpinPrize('₹10 Cash', Colors.orange, Icons.currency_rupee, 10.0, 'cash'),
    _SpinPrize('₹2 Bonus', Colors.green, Icons.card_giftcard, 2.0, 'bonus'),
    _SpinPrize('₹20 Cash', Colors.red, Icons.currency_rupee, 20.0, 'cash'),
    _SpinPrize('Try Again', Colors.grey.shade700, Icons.refresh, 0.0, 'none'),
    _SpinPrize('₹3 Bonus', Colors.teal, Icons.card_giftcard, 3.0, 'bonus'),
    _SpinPrize('₹50 Cash', Colors.purple, Icons.star, 50.0, 'cash'),
  ];

  double _currentAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.decelerate);
    _checkIfSpunToday();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkIfSpunToday() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.userModel?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return;

    final lastSpin = data['lastSpinDate'];
    if (lastSpin != null) {
      final lastSpinDate = (lastSpin as Timestamp).toDate();
      final now = DateTime.now();
      final isSameDay = lastSpinDate.year == now.year &&
          lastSpinDate.month == now.month &&
          lastSpinDate.day == now.day;
      if (mounted) setState(() => _hasSpunToday = isSameDay);
    }
  }

  Future<void> _spin() async {
    if (_isSpinning || _hasSpunToday) return;

    setState(() {
      _isSpinning = true;
      _result = null;
    });

    // Pick a random prize with weighted probability
    final rand = Random();
    // Weights: 50cash is rare (1), 20cash is uncommon (2), 5/10 common (3 each), bonus medium (2 each), try again (5 each)
    final weights = [3, 5, 3, 2, 2, 5, 2, 1];
    final totalWeight = weights.reduce((a, b) => a + b);
    int roll = rand.nextInt(totalWeight);
    int picked = 0;
    int cumulative = 0;
    for (int i = 0; i < weights.length; i++) {
      cumulative += weights[i];
      if (roll < cumulative) {
        picked = i;
        break;
      }
    }

    // Calculate angle to spin to that segment
    final segmentAngle = (2 * pi) / _prizes.length;
    // We want the picked segment to land at the top pointer
    // The pointer is at top (angle 0 = top, going clockwise)
    final targetAngle = (2 * pi * 5) + // 5 full rotations
        (2 * pi - (picked * segmentAngle + segmentAngle / 2));

    _animation = Tween<double>(begin: _currentAngle, end: _currentAngle + targetAngle)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));

    _controller.reset();
    await _controller.forward();

    _currentAngle = (_currentAngle + targetAngle) % (2 * pi);
    _selectedSegment = picked;

    // Award prize
    final prize = _prizes[picked];
    if (prize.type != 'none') {
      await _awardPrize(prize);
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(Provider.of<AuthProvider>(context, listen: false).userModel?.uid)
        .update({'lastSpinDate': Timestamp.now()});

    if (mounted) {
      setState(() {
        _isSpinning = false;
        _hasSpunToday = true;
        _result = prize.label;
      });
      _showResultDialog(prize);
    }
  }

  Future<void> _awardPrize(_SpinPrize prize) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.userModel?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};

    final Map<String, dynamic> updates = {'lastSpinDate': Timestamp.now()};

    if (prize.type == 'cash') {
      final current = (data['balance'] ?? 0.0).toDouble();
      updates['balance'] = current + prize.amount;
    } else if (prize.type == 'bonus') {
      final current = (data['bonusBalance'] ?? 0.0).toDouble();
      updates['bonusBalance'] = current + prize.amount;
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).update(updates);

    // Log transaction
    if (prize.amount > 0) {
      await FirebaseFirestore.instance.collection('transactions').add({
        'userId': uid,
        'amount': prize.amount,
        'type': prize.type == 'cash' ? 'spin_win' : 'spin_bonus',
        'dateTime': Timestamp.now(),
        'status': 'success',
        'note': 'Lucky Spin - Won ${prize.label}',
      });
    }
  }

  void _showResultDialog(_SpinPrize prize) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              prize.type == 'none'
                  ? const Icon(Icons.refresh, size: 70, color: Colors.grey)
                  : Icon(prize.icon, size: 70, color: prize.color),
              const SizedBox(height: 15),
              Text(
                prize.type == 'none' ? 'Better Luck Next Time!' : '🎉 Congratulations!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                prize.type == 'none'
                    ? 'You got: ${prize.label}\nTry again tomorrow!'
                    : 'You won: ${prize.label}\nAdded to your wallet!',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('AWESOME!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LUCKY SPIN')),
      body: Column(
        children: [
          // Countdown / Status Banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _hasSpunToday
                    ? [Colors.grey.shade800, Colors.grey.shade900]
                    : [AppColors.primary.withOpacity(0.2), AppColors.accent.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hasSpunToday ? Colors.grey.shade600 : AppColors.primary.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _hasSpunToday ? Icons.timer : Icons.stars,
                  color: _hasSpunToday ? Colors.grey : AppColors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  _hasSpunToday
                      ? '⏰ Come back tomorrow for your next spin!'
                      : '🎡 You have 1 FREE spin today!',
                  style: TextStyle(
                    color: _hasSpunToday ? Colors.grey : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Spin Wheel
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pointer Arrow
                  const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 50),

                  // The Wheel
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _animation.value,
                        child: SizedBox(
                          width: 280,
                          height: 280,
                          child: CustomPaint(
                            painter: _SpinWheelPainter(_prizes),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Spin Button
                  GestureDetector(
                    onTap: _spin,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: _hasSpunToday || _isSpinning
                            ? LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade800])
                            : const LinearGradient(
                                colors: [AppColors.primary, AppColors.accent],
                              ),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: _hasSpunToday || _isSpinning
                            ? []
                            : [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSpinning ? Icons.hourglass_top : Icons.play_circle_fill,
                            color: _hasSpunToday || _isSpinning ? Colors.grey.shade400 : Colors.black,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isSpinning
                                ? 'SPINNING...'
                                : _hasSpunToday
                                    ? 'ALREADY SPUN'
                                    : 'SPIN NOW',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _hasSpunToday || _isSpinning ? Colors.grey.shade400 : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Prize List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: _prizes.map((prize) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: prize.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: prize.color.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(prize.icon, size: 14, color: prize.color),
                              const SizedBox(width: 4),
                              Text(prize.label, style: TextStyle(fontSize: 12, color: prize.color, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpinPrize {
  final String label;
  final Color color;
  final IconData icon;
  final double amount;
  final String type; // 'cash', 'bonus', 'none'

  const _SpinPrize(this.label, this.color, this.icon, this.amount, this.type);
}

class _SpinWheelPainter extends CustomPainter {
  final List<_SpinPrize> prizes;

  _SpinWheelPainter(this.prizes);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = (2 * pi) / prizes.length;

    for (int i = 0; i < prizes.length; i++) {
      final startAngle = i * segmentAngle - pi / 2;
      final paint = Paint()..color = prizes[i].color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      // Draw divider lines
      final linePaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..strokeWidth = 2;
      final angle = startAngle;
      canvas.drawLine(
        center,
        Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)),
        linePaint,
      );

      // Draw text
      final textAngle = startAngle + segmentAngle / 2;
      final textRadius = radius * 0.65;
      final textCenter = Offset(
        center.dx + textRadius * cos(textAngle),
        center.dy + textRadius * sin(textAngle),
      );

      canvas.save();
      canvas.translate(textCenter.dx, textCenter.dy);
      canvas.rotate(textAngle + pi / 2);

      final textPainter = TextPainter(
        text: TextSpan(
          text: prizes[i].label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: 80);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    // Center circle
    final centerPaint = Paint()..color = AppColors.background;
    canvas.drawCircle(center, radius * 0.12, centerPaint);
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, borderPaint);
    canvas.drawCircle(center, radius * 0.12, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
