import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Chip con el ícono y el color de un actor del proceso.
class ActorChip extends StatelessWidget {
  const ActorChip({super.key, required this.actor, this.label});

  final Actor actor;

  /// Texto opcional; por defecto, el nombre del actor.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forActor(actor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.actor(actor), size: 14, color: color),
          const SizedBox(width: 4),
          Text(label ?? actor.label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
