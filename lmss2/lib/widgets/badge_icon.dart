import 'package:flutter/material.dart';

class BadgeIcon extends StatelessWidget {
  final String? value;
  final double size;
  const BadgeIcon({super.key, this.value, this.size = 42});

  static const _icons = <String, IconData>{
    'military_tech': Icons.military_tech,
    'workspace_premium': Icons.workspace_premium,
    'emoji_events': Icons.emoji_events,
    'local_fire_department': Icons.local_fire_department,
    'school': Icons.school,
    'verified': Icons.verified,
    'star': Icons.star,
  };

  @override
  Widget build(BuildContext context) {
    final raw = value?.trim() ?? '';
    if (raw.startsWith('https://')) {
      return ClipOval(
        child: Image.network(
          raw,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(Icons.workspace_premium, size: size),
        ),
      );
    }
    if (raw.runes.length <= 2 && raw.isNotEmpty) {
      return Text(raw, style: TextStyle(fontSize: size));
    }
    return Icon(_icons[raw] ?? Icons.workspace_premium, size: size);
  }
}
