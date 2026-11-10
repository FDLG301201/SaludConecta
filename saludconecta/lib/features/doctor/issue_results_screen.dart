import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/section_card.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/case_records.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/people.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_exception.dart';
import '../../domain/process/process_step.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';
import '../patient/patient_case_builder.dart';
import '../shared/not_found_screen.dart';

/// Emitir resultados (paso 8): receta, órdenes, referimiento, indicaciones (obligatorias) y próxima cita.
class IssueResultsScreen extends StatelessWidget {
  const IssueResultsScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CaseProvider>().caseById(caseId);
    final doctor = context.watch<SessionProvider>().currentDoctor;
    if (c == null) {
      return const NotFoundScreen(title: 'Caso no encontrado', message: 'El caso que buscas no existe.');
    }
    if (doctor == null || c.appointment?.doctorId != doctor.id) {
      return const CaseNotice(
        screenTitle: 'Emitir resultados',
        title: 'Esta cita es de otro médico',
        message: 'Solo el médico asignado emite los resultados.',
      );
    }
    if (c.status != CaseStatus.active || c.currentStep != ProcessStep.consultationResult) {
      return CaseNotice(
        screenTitle: 'Emitir resultados',
        title: c.results != null ? 'Los resultados ya se emitieron' : 'Aún no se pueden emitir',
        message: 'El caso ${c.id} está en el paso ${c.currentStep.number}: ${c.currentStep.title}.',
      );
    }
    return _ResultsForm(telemedicineCase: c, doctor: doctor);
  }
}

class _ResultsForm extends StatefulWidget {
  const _ResultsForm({required this.telemedicineCase, required this.doctor});

  final TelemedicineCase telemedicineCase;
  final Doctor doctor;

  @override
  State<_ResultsForm> createState() => _ResultsFormState();
}

class _ResultsFormState extends State<_ResultsForm> {
  static const _medicationSuggestions = [
    PrescriptionItem(
        medication: 'Acetaminofén 500 mg', dose: '1 tableta', frequency: 'Cada 8 horas', duration: '5 días'),
    PrescriptionItem(medication: 'Ibuprofeno 400 mg', dose: '1 tableta', frequency: 'Cada 8 horas', duration: '3 días'),
    PrescriptionItem(medication: 'Omeprazol 20 mg', dose: '1 cápsula', frequency: 'Cada 24 horas', duration: '14 días'),
    PrescriptionItem(medication: 'Loratadina 10 mg', dose: '1 tableta', frequency: 'Cada 24 horas', duration: '7 días'),
    PrescriptionItem(
        medication: 'Amoxicilina 500 mg', dose: '1 cápsula', frequency: 'Cada 8 horas', duration: '7 días'),
  ];
  static const _labs = ['Hemograma', 'Glicemia', 'Perfil lipídico', 'Creatinina', 'Examen de orina', 'TSH'];
  static const _imaging = ['Radiografía de tórax', 'Sonografía abdominal', 'Electrocardiograma', 'Mamografía'];
  static const _instructionSuggestions = [
    'Reposo relativo por 48 horas.',
    'Tomar abundante líquido.',
    'Dieta balanceada y baja en sal.',
    'Volver a consulta si aparecen signos de alarma.',
  ];

  final _medications = <PrescriptionItem>[];
  final _orders = <String>{};
  final _referralReason = TextEditingController();
  final _instructions = TextEditingController();
  bool _refer = false;
  Specialty _referralSpecialty = Specialty.internalMedicine;
  int _followUp = 0;

  @override
  void dispose() {
    _referralReason.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _emit() {
    final cases = context.read<CaseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    messenger.removeCurrentSnackBar();
    try {
      cases.issueResults(
        widget.telemedicineCase.id,
        doctor: widget.doctor,
        instructions: _instructions.text.trim(),
        medications: List.of(_medications),
        orders: [
          for (final lab in _labs)
            if (_orders.contains(lab)) MedicalOrder(type: OrderType.lab, description: lab),
          for (final image in _imaging)
            if (_orders.contains(image)) MedicalOrder(type: OrderType.imaging, description: image),
        ],
        referral: _refer ? Referral(specialty: _referralSpecialty, reason: _referralReason.text.trim()) : null,
        followUpInDays: _followUp == 0 ? null : _followUp,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Resultados emitidos. El paciente ya puede verlos.')));
      router.go(AppRoutes.doctorAgenda);
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addCustomMedication() async {
    final item = await showDialog<PrescriptionItem>(context: context, builder: (_) => const _MedicationDialog());
    if (item != null) setState(() => _medications.add(item));
  }

  Widget _orderChips(List<String> names) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in names)
          FilterChip(
            label: Text(name),
            selected: _orders.contains(name),
            onSelected: (on) => setState(() => on ? _orders.add(name) : _orders.remove(name)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final theme = Theme.of(context);
    final diagnosis = c.consultation?.notes.diagnosis ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Emitir resultados')),
      body: PageBody(
        child: ListView(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(catalog.patientById(c.patientId).fullName),
                subtitle: Text('${catalog.serviceById(c.serviceId).name} · Diagnóstico: $diagnosis'),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Receta',
              icon: Icons.medication_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_medications.isEmpty)
                    Text('Sin medicamentos.', style: theme.textTheme.bodyMedium)
                  else
                    for (var i = 0; i < _medications.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_medications[i].medication),
                        subtitle: Text(
                          '${_medications[i].dose} · ${_medications[i].frequency} · ${_medications[i].duration}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar',
                          onPressed: () => setState(() => _medications.removeAt(i)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                  const SizedBox(height: 8),
                  Text('Sugerencias', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in _medicationSuggestions)
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: Text(item.medication),
                          onPressed: _medications.any((m) => m.medication == item.medication)
                              ? null
                              : () => setState(() => _medications.add(item)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _addCustomMedication,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Otro medicamento'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Órdenes',
              icon: Icons.science_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Laboratorio', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  _orderChips(_labs),
                  const SizedBox(height: 12),
                  Text('Imágenes', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  _orderChips(_imaging),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Referimiento',
              icon: Icons.alt_route,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Referir a consulta presencial'),
                    value: _refer,
                    onChanged: (value) => setState(() => _refer = value),
                  ),
                  if (_refer) ...[
                    DropdownButtonFormField<Specialty>(
                      value: _referralSpecialty,
                      decoration: const InputDecoration(labelText: 'Especialidad', border: OutlineInputBorder()),
                      items: [
                        for (final s in Specialty.values) DropdownMenuItem(value: s, child: Text(s.label)),
                      ],
                      onChanged: (value) => setState(() => _referralSpecialty = value ?? _referralSpecialty),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _referralReason,
                      decoration: const InputDecoration(
                        labelText: 'Motivo del referimiento',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Indicaciones *',
              icon: Icons.assignment_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _instructions,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Indicaciones para el paciente',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in _instructionSuggestions)
                        ActionChip(
                          label: Text(s),
                          onPressed: () => setState(() {
                            _instructions.text = [_instructions.text.trim(), s].where((t) => t.isNotEmpty).join(' ');
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Próxima cita',
              icon: Icons.event_repeat,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('No requiere')),
                  ButtonSegment(value: 7, label: Text('7 días')),
                  ButtonSegment(value: 15, label: Text('15 días')),
                  ButtonSegment(value: 30, label: Text('30 días')),
                ],
                selected: {_followUp},
                onSelectionChanged: (selection) => setState(() => _followUp = selection.first),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _emit, icon: const Icon(Icons.send), label: const Text('Emitir y notificar')),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para un medicamento que no está en las sugerencias.
class _MedicationDialog extends StatefulWidget {
  const _MedicationDialog();

  @override
  State<_MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends State<_MedicationDialog> {
  final _fields = List.generate(4, (_) => TextEditingController());
  static const _labels = ['Medicamento y concentración', 'Dosis', 'Frecuencia', 'Duración'];

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Otro medicamento'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(controller: _fields[i], decoration: InputDecoration(labelText: _labels[i])),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final values = [for (final f in _fields) f.text.trim()];
            if (values.first.isEmpty) return;
            Navigator.pop(
              context,
              PrescriptionItem(medication: values[0], dose: values[1], frequency: values[2], duration: values[3]),
            );
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
