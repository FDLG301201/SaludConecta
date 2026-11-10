import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';
import '../theme/app_colors.dart';

/// Estado del caso: En proceso, Rechazado por el seguro, Cancelado o Completado.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final CaseStatus status;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status);
    final textColor = status == CaseStatus.active ? AppColors.currentText : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
