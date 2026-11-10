import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_illustration.dart';
import '../../../domain/models/catalog.dart';
import '../../../domain/models/people.dart';

/// Carnet del seguro dibujado con widgets: degradado, símbolo de la aseguradora, plan, número y estado.
class InsuranceCard extends StatelessWidget {
  const InsuranceCard({super.key, required this.patient, required this.insurer});

  final Patient patient;
  final Insurer insurer;

  @override
  Widget build(BuildContext context) {
    final affiliation = patient.affiliation;
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: AspectRatio(
        // Proporción de una tarjeta física (85.6 × 54 mm).
        aspectRatio: 1.586,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.navy, AppColors.primary, AppColors.secondary],
            ),
            boxShadow: [
              BoxShadow(color: AppColors.navy.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: AppIllustration(insurer.symbolAsset, width: 30, height: 30),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        insurer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _StatusPill(active: affiliation.active),
                  ],
                ),
                const Spacer(),
                Text('Plan ${affiliation.plan}', style: text.bodyMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 2),
                Text(
                  affiliation.affiliateNumber,
                  style: text.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        patient.fullName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(color: Colors.white, letterSpacing: 1),
                      ),
                    ),
                    Text('Cédula ${patient.cedula}', style: text.bodySmall?.copyWith(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(0.2) : AppColors.danger,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          active ? 'Activa' : 'Inactiva',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }
}
