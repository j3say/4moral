import 'package:flutter/material.dart';

class BadgeWidget extends StatelessWidget {
  final String badge;

  const BadgeWidget({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    // Normalise the key once so small typos don’t break the colour lookup
    final String key = badge.trim();

    final Map<String, Map<String, Color>> badgeColors = {
      'Standard': {'bg': Colors.black, 'text': Colors.white},
      'Mentor': {'bg': Colors.red, 'text': Colors.white},
      'Media': {'bg': Colors.purple, 'text': Colors.white},
      'Holy Peaces': {'bg': Colors.blue, 'text': Colors.white},
      'Business': {'bg': Colors.yellow[700]!, 'text': Colors.white},
      'Ngo': {'bg': Colors.green, 'text': Colors.white},
    };

    final colors =
        badgeColors[key] ?? {'bg': Colors.grey.shade200, 'text': Colors.black};

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: colors['bg'],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors['bg']!.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(1, 3),
          ),
        ],
      ),
      child: Text(
        badge,
        style: TextStyle(color: colors['text'], fontWeight: FontWeight.w600),
      ),
    );
  }
}
