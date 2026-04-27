import 'package:flutter/material.dart';
import '../models/elo_match.dart';

class EloTierBadge extends StatelessWidget {
  final int elo;
  final bool large;
  final bool showScore;

  const EloTierBadge({
    super.key,
    required this.elo,
    this.large = false,
    this.showScore = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(eloTierColorValue(elo));
    final name = eloTierName(elo);
    final emoji = eloTierEmoji(elo);

    if (large) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tier circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.25),
                  color.withOpacity(0.08),
                ],
              ),
              border: Border.all(color: color, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
                letterSpacing: 0.5),
          ),
          if (showScore) ...[
            const SizedBox(height: 2),
            Text(
              '$elo pts',
              style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      );
    }

    // Compact badge
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            showScore ? '$name · $elo' : name,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// Progress bar to next tier
class EloProgressBar extends StatelessWidget {
  final int elo;

  const EloProgressBar({super.key, required this.elo});

  @override
  Widget build(BuildContext context) {
    if (eloTierOf(elo) == EloTier.diamond) {
      return Text('Rang maximum atteint 👑',
          style: TextStyle(
              color: Color(eloTierColorValue(elo)),
              fontWeight: FontWeight.bold,
              fontSize: 12));
    }

    final color = Color(eloTierColorValue(elo));
    final tierStart = _tierStart(elo);
    final tierEnd = eloNextTierThreshold(elo);
    final progress = (elo - tierStart) / (tierEnd - tierStart);
    final remaining = tierEnd - elo;
    final nextName = eloTierName(tierEnd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Progression vers $nextName',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
            Text('$remaining pts restants',
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  int _tierStart(int elo) {
    if (elo < 1200) return 0;
    if (elo < 1400) return 1200;
    if (elo < 1600) return 1400;
    if (elo < 1800) return 1600;
    return 1800;
  }
}
