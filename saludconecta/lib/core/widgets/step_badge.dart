import 'package:flutter/material.dart';

import '../../domain/process/process_step.dart';
import '../theme/app_colors.dart';

/// Número de paso en un círculo, con el color de su actor (o el color que se indique).
class StepBadge extends StatelessWidget {
  const StepBadge({super.key, required this.step, this.size = 32, this.color});

  final ProcessStep step;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color ?? AppColors.forActor(step.actor), shape: BoxShape.circle),
      child: Text(
        '${step.number}',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.42),
      ),
    );
  }
}
