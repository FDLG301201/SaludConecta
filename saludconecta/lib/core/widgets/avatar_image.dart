import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Avatar circular: la ilustración SVG de la persona o, si no tiene, sus iniciales.
class AvatarImage extends StatelessWidget {
  const AvatarImage({super.key, required this.name, this.asset, this.size = 48, this.color});

  final String name;
  final String? asset;
  final double size;

  /// Color de las iniciales (por defecto, el primario del tema).
  final Color? color;

  /// "María Fernández" → "MF"; "Dr. Carlos Méndez" → "CM" (se ignoran los títulos).
  static String initialsOf(String name) {
    const titles = {'dr.', 'dra.', 'lic.'};
    final words = [
      for (final word in name.trim().split(RegExp(r'\s+')))
        if (word.isNotEmpty && !titles.contains(word.toLowerCase())) word,
    ];
    if (words.isEmpty) return '?';
    final first = words.first[0];
    final last = words.length > 1 ? words.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final path = asset;
    if (path != null) {
      return ClipOval(
        child: SvgPicture.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticsLabel: name,
          placeholderBuilder: (context) => SizedBox(width: size, height: size),
        ),
      );
    }
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: tint.withOpacity(0.15),
      child: Text(
        initialsOf(name),
        style: TextStyle(color: tint, fontWeight: FontWeight.bold, fontSize: size * 0.36),
      ),
    );
  }
}
