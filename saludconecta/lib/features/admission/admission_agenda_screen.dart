import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/appointment_status_chip.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/section_card.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../state/case_provider.dart';

/// Agenda de Admisión (§6): las citas de un día (de hoy a 7 días), agrupadas por médico.
class AdmissionAgendaScreen extends StatefulWidget {
  const AdmissionAgendaScreen({super.key});

  @override
  State<AdmissionAgendaScreen> createState() => _AdmissionAgendaScreenState();
}

class _AdmissionAgendaScreenState extends State<AdmissionAgendaScreen> {
  DateTime? _day;

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final catalog = context.read<CatalogRepository>();
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(cases.now);
    final days = [for (var i = 0; i < 7; i++) DateUtils.addDaysToDate(today, i)];
    final day = _day ?? today;
    final appointments = [
      for (final c in cases.cases)
        if (c.appointment != null &&
            c.status != CaseStatus.cancelled &&
            DateUtils.isSameDay(c.appointment!.dateTime, day))
          c,
    ]..sort((a, b) => a.appointment!.dateTime.compareTo(b.appointment!.dateTime));
    final byDoctor = <String, List<TelemedicineCase>>{};
    for (final c in appointments) {
      byDoctor.putIfAbsent(c.appointment!.doctorId, () => []).add(c);
    }
    final dayFormat = DateFormat('EEE d', 'es');
    return PageBody(
      child: ListView(
        children: [
          Text('Agenda', style: theme.textTheme.headlineSmall),
          Text('${appointments.length} citas el ${Formatters.date(day)}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in days)
                ChoiceChip(
                  label: Text(DateUtils.isSameDay(d, today) ? 'Hoy' : dayFormat.format(d)),
                  selected: DateUtils.isSameDay(d, day),
                  onSelected: (_) => setState(() => _day = d),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (byDoctor.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay citas este día.', textAlign: TextAlign.center),
              ),
            )
          else
            for (final entry in byDoctor.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  title: catalog.doctorById(entry.key).displayName,
                  icon: Icons.medical_services_outlined,
                  trailing: Text('${entry.value.length} citas', style: theme.textTheme.labelMedium),
                  child: Column(
                    children: [
                      for (final c in entry.value)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Text(Formatters.time(c.appointment!.dateTime), style: theme.textTheme.titleSmall),
                          title: Text(catalog.patientById(c.patientId).fullName),
                          subtitle: Text('${catalog.serviceById(c.serviceId).name} · ${c.appointment!.platform.label}'),
                          trailing: AppointmentStatusChip(telemedicineCase: c),
                          onTap: () => context.push(AppRoutes.caseDetail(c.id)),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
