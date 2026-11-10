import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/case_records.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_step.dart';
import '../../../state/case_provider.dart';

/// Datos que ya tiene el caso: solicitud, seguro, cita, resultados y facturación.
class CaseSections extends StatelessWidget {
  const CaseSections({super.key, required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final insurance = c.insurance;
    final appointment = c.appointment;
    final results = c.results;
    final billing = c.billing;
    final sections = <Widget>[
      SectionCard(
        title: 'Solicitud',
        icon: Icons.edit_calendar,
        child: Column(
          children: [
            _InfoRow('Motivo', c.reason),
            _InfoRow('Canal', c.channel.label),
            _InfoRow('Fecha preferida', Formatters.date(c.preferredDate)),
            _InfoRow('Creada', Formatters.dateTime(c.createdAt)),
          ],
        ),
      ),
      if (insurance != null)
        SectionCard(
          title: 'Seguro',
          icon: Icons.verified_user_outlined,
          child: Column(
            children: [
              _InfoRow(
                'Respuesta',
                insurance.approved ? 'Aprobado (${insurance.coveragePercent}%)' : 'Rechazado: ${insurance.message}',
              ),
              if (insurance.authorizationNumber != null) _InfoRow('Autorización', insurance.authorizationNumber!),
              if (c.privatePay) const _InfoRow('Modalidad', 'Paciente privado (100%)'),
            ],
          ),
        ),
      if (appointment != null)
        SectionCard(
          title: 'Cita',
          icon: Icons.calendar_month_outlined,
          child: Column(
            children: [
              _InfoRow(
                'Médico',
                '${catalog.doctorById(appointment.doctorId).displayName} · '
                    '${catalog.doctorById(appointment.doctorId).specialty.label}',
              ),
              _InfoRow('Fecha', Formatters.dateTime(appointment.dateTime)),
              _InfoRow('Plataforma', appointment.platform.label),
              if (c.confirmation != null) _InfoRow('Enlace', c.confirmation!.link),
            ],
          ),
        ),
      if (results != null)
        SectionCard(
          title: 'Resultados',
          icon: Icons.receipt_long_outlined,
          child: Column(
            children: [
              _InfoRow(
                'Receta',
                results.prescription == null
                    ? 'Sin medicamentos'
                    : '${results.prescription!.items.length} medicamento(s)',
              ),
              _InfoRow(
                  'Órdenes', results.orders.isEmpty ? 'Ninguna' : results.orders.map((o) => o.description).join(', ')),
              if (results.referral != null) _InfoRow('Referimiento', results.referral!.specialty.label),
              _InfoRow('Indicaciones', results.instructions),
              if (results.followUpInDays != null) _InfoRow('Próxima cita', 'En ${results.followUpInDays} días'),
            ],
          ),
        ),
      if (billing != null || c.currentStep == ProcessStep.administrativeClosure)
        _billing(c, context.read<CaseProvider>().invoiceFor(c), billing),
    ];
    return Column(
      children: [
        for (final section in sections) Padding(padding: const EdgeInsets.only(bottom: 12), child: section),
      ],
    );
  }

  Widget _billing(TelemedicineCase c, Invoice invoice, BillingRecord? billing) {
    final claim = billing == null
        ? null
        : billing.claimNumber == null
            ? billing.claimStatus.label
            : '${billing.claimStatus.label} · ${billing.claimNumber}';
    return SectionCard(
      title: 'Facturación',
      icon: Icons.request_quote_outlined,
      child: Column(
        children: [
          _InfoRow('Tarifa', Formatters.money(invoice.fee)),
          _InfoRow('Cobertura', c.privatePay ? 'Privado' : '${invoice.coveragePercent}%'),
          _InfoRow('A cargo del seguro', Formatters.money(invoice.insurerAmount)),
          _InfoRow('Copago', Formatters.money(invoice.copay)),
          if (claim != null) _InfoRow('Reclamación', claim),
          if (billing?.payment != null) _InfoRow('Pago', billing!.payment!.method.label),
          if (billing?.closedAt != null) _InfoRow('Cerrado', Formatters.dateTime(billing!.closedAt!)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
