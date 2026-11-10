import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
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
import '../shared/video_call/video_call_view.dart';
import 'clinical_notes_form.dart';

/// Consulta de telemedicina (paso 7, lado del médico): videollamada con notas clínicas.
/// Al colgar se confirma "¿Finalizar consulta?"; si faltan notas obligatorias, se abren para completarlas.
class ConsultationScreen extends StatelessWidget {
  const ConsultationScreen({super.key, required this.caseId});

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
        screenTitle: 'Consulta',
        title: 'Esta cita es de otro médico',
        message: 'Solo el médico asignado puede atender la consulta.',
      );
    }
    if (c.status != CaseStatus.active || c.currentStep != ProcessStep.consultation) {
      return CaseNotice(
        screenTitle: 'Consulta',
        title: 'La consulta ya terminó',
        message: 'El caso ${c.id} está en el paso ${c.currentStep.number}: ${c.currentStep.title}.',
      );
    }
    if (c.consultation == null) {
      return CaseNotice(
        screenTitle: 'Consulta',
        title: 'La consulta aún no empieza',
        message: 'El paciente ya firmó su consentimiento y está en la sala de espera.',
        action: FilledButton.icon(
          onPressed: () => context.read<CaseProvider>().startConsultation(c.id, doctor: doctor),
          icon: const Icon(Icons.video_call),
          label: const Text('Iniciar consulta'),
        ),
      );
    }
    return _ConsultationRoom(telemedicineCase: c, doctor: doctor);
  }
}

class _ConsultationRoom extends StatefulWidget {
  const _ConsultationRoom({required this.telemedicineCase, required this.doctor});

  final TelemedicineCase telemedicineCase;
  final Doctor doctor;

  @override
  State<_ConsultationRoom> createState() => _ConsultationRoomState();
}

class _ConsultationRoomState extends State<_ConsultationRoom> {
  late final TextEditingController _complaint = TextEditingController(text: widget.telemedicineCase.reason);
  final _assessment = TextEditingController();
  final _diagnosis = TextEditingController();
  final _plan = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_complaint, _assessment, _diagnosis, _plan]) {
      controller.dispose();
    }
    super.dispose();
  }

  ClinicalNotes get _notes => ClinicalNotes(
        chiefComplaint: _complaint.text.trim(),
        assessment: _assessment.text.trim(),
        diagnosis: _diagnosis.text.trim(),
        plan: _plan.text.trim(),
      );

  Widget get _form =>
      ClinicalNotesForm(complaint: _complaint, assessment: _assessment, diagnosis: _diagnosis, plan: _plan);

  /// Abre las notas en una hoja inferior. Con [error] (faltan notas al finalizar), lo muestra arriba:
  /// un `SnackBar` taparía la barra de controles de la videollamada.
  void _openNotes({String? error}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notas clínicas', style: Theme.of(sheetContext).textTheme.titleLarge),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error, style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
              ],
              const SizedBox(height: 12),
              _form,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    final cases = context.read<CaseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final id = widget.telemedicineCase.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Finalizar consulta?'),
        content: const Text('Se guardarán las notas clínicas y pasarás a emitir los resultados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Seguir en la consulta')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      cases.finishConsultation(id, doctor: widget.doctor, notes: _notes);
      messenger.showSnackBar(const SnackBar(content: Text('Consulta finalizada. Emite los resultados.')));
      router.pushReplacement(AppRoutes.caseAction(id, CaseAction.issueResults));
    } on ProcessException catch (e) {
      if (mounted) _openNotes(error: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.telemedicineCase;
    final call = VideoCallView(
      perspective: CallPerspective.doctor,
      doctor: widget.doctor,
      patient: context.read<CatalogRepository>().patientById(c.patientId),
      platform: c.appointment!.platform,
      onHangUp: _finish,
      extraControls: [
        CallControlButton(icon: Icons.note_alt_outlined, tooltip: 'Notas clínicas', onPressed: _openNotes),
      ],
    );
    // En pantallas anchas las notas quedan a la vista en un panel lateral.
    if (MediaQuery.sizeOf(context).width < 1000) return call;
    return Row(
      children: [
        Expanded(child: call),
        SizedBox(
          width: 380,
          child: Material(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Notas clínicas', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _form,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
