import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_illustrations.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_illustration.dart';
import '../../../domain/models/case_records.dart';
import '../../../domain/models/people.dart';

/// Receta con aspecto de documento: encabezado, médico, paciente, medicamentos y QR de verificación.
class PrescriptionDocument extends StatelessWidget {
  const PrescriptionDocument({
    super.key,
    required this.caseId,
    required this.prescription,
    required this.doctor,
    required this.patient,
    required this.issuedAt,
  });

  final String caseId;
  final Prescription prescription;
  final Doctor doctor;
  final Patient patient;
  final DateTime issuedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.pending.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIllustration(AppIllustrations.logo, width: 40, height: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppInfo.appName,
                      style: theme.textTheme.titleMedium?.copyWith(color: AppColors.navy, fontWeight: FontWeight.bold),
                    ),
                    Text('Receta médica · Telemedicina', style: muted),
                  ],
                ),
              ),
              Text(caseId, style: muted),
            ],
          ),
          const Divider(height: 28),
          Text(doctor.displayName, style: theme.textTheme.titleSmall),
          Text('${doctor.specialty.label} · Exequátur ${doctor.exequatur}', style: muted),
          const SizedBox(height: 10),
          Text('Paciente: ${patient.fullName}', style: theme.textTheme.bodyMedium),
          Text(
            'Cédula ${patient.cedula} · ${patient.ageOn(issuedAt)} años · ${Formatters.date(issuedAt)}',
            style: muted,
          ),
          const Divider(height: 28),
          Text('Rp.', style: theme.textTheme.titleLarge?.copyWith(color: AppColors.navy, fontStyle: FontStyle.italic)),
          for (final item in prescription.items)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.medication, style: theme.textTheme.titleSmall),
                  Text('${item.dose} · ${item.frequency} · ${item.duration}', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          const Divider(height: 28),
          Row(
            children: [
              QrImageView(
                data: 'SALUDCONECTA|${prescription.verificationCode}',
                size: 104,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Código de verificación', style: muted),
                    Text(
                      prescription.verificationCode,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text('La farmacia escanea el código para comprobar la receta.', style: muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Firmado digitalmente por', style: muted),
                Text(doctor.displayName, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
