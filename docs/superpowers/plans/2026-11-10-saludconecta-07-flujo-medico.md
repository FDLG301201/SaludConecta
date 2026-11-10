# SaludConecta · Etapa 7: Flujo del Médico — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir las pantallas del médico (§6 Médico): la agenda, la consulta por videollamada con notas clínicas y "Emitir resultados".

**Architecture:**

- Pantallas en `lib/features/doctor/`, con el `Doctor` de la sesión.
- La consulta reutiliza `VideoCallView(perspective: doctor)` de la etapa 5. Agrega:
  - el botón "Notas clínicas" en `extraControls`;
  - las notas en una hoja inferior, y en pantallas anchas (≥ 1000 px) también en un panel lateral;
  - al colgar, la pregunta "¿Finalizar consulta?".
- "Iniciar consulta" (`startConsultation`, idempotente) se llama desde la agenda antes de abrir la consulta.
- Al finalizar se pasa a "Emitir resultados". Al emitir, el médico vuelve a su agenda.

**Tech Stack:** `VideoCallView` + `CallControlButton`, `FilterChip`, `ActionChip`, `SwitchListTile`, `SegmentedButton`, `DropdownButtonFormField`.

**Hoja de ruta:** [00-hoja-de-ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md) · **Spec:** §6 Médico, §6 Videollamada (variante médico), §4 (reglas de los pasos 7 y 8)

## Global Constraints

Las de la [hoja de ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md#global-constraints) y sus notas de pruebas:
- `scrollUntilVisible` + `pump()` antes de `tap`;
- `pump(duración)` mientras la videollamada está abierta.

Un solo commit al final (tarea 3).

## Archivos de la etapa

| Archivo | Responsabilidad |
|---|---|
| `lib/features/doctor/doctor_agenda_screen.dart` | Agenda: hoy y próximas, con el estado y la acción de cada cita |
| `lib/features/doctor/clinical_notes_form.dart` | Formulario de notas clínicas (motivo y diagnóstico obligatorios) |
| `lib/features/doctor/consultation_screen.dart` | Videollamada del médico con notas y "¿Finalizar consulta?" |
| `lib/features/doctor/issue_results_screen.dart` | Receta, órdenes, referimiento, indicaciones y próxima cita |
| `lib/core/router/app_router.dart` | Rutas del médico (ediciones) |
| `test/features/doctor/` | Pruebas |

---

### Task 1: Agenda y consulta

**Files:**
- Create: `saludconecta/lib/features/doctor/doctor_agenda_screen.dart`, `saludconecta/lib/features/doctor/clinical_notes_form.dart`, `saludconecta/lib/features/doctor/consultation_screen.dart`
- Modify: `saludconecta/lib/core/router/app_router.dart` (edición)
- Test: `saludconecta/test/features/doctor/consultation_test.dart`

**Interfaces:**
- Consumes: `CaseProvider.doctorAgenda`, `startConsultation(id, {doctor})` y `finishConsultation(id, {doctor, notes})`; `AppointmentStatusChip` (etapa 6); `VideoCallView`, `CallControlButton` (etapa 5); `staffDependencies` (etapa 6).
- Produces:
  - `DoctorAgendaScreen()` (título "Mi agenda"; secciones "Hoy" y "Próximas"; botones "Iniciar consulta" y "Emitir resultados").
  - `ClinicalNotesForm({complaint, assessment, diagnosis, plan})` con las etiquetas "Motivo de consulta *", "Evaluación", "Diagnóstico *" y "Plan".
  - `ConsultationScreen({required String caseId})` (tooltip "Notas clínicas"; diálogo con "Finalizar").

- [ ] **Step 1: Escribir la prueba**

Create `saludconecta/test/features/doctor/consultation_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  /// La videollamada tiene animaciones que no terminan: se avanza el reloj a mano.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('la agenda del Dr. Méndez separa hoy y próximas, con el estado de cada cita', (tester) async {
    await tester.pumpWidget(appWith(staffDependencies(UserRole.doctor, doctorId: SeedIds.mendez)));
    await tester.pumpAndSettle();
    expect(find.text('Mi agenda'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Paciente en sala de espera'), findsOneWidget);
    expect(find.text('Iniciar consulta'), findsOneWidget);
    expect(find.text('Emitir resultados'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Esperando consentimiento'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Próximas'), findsOneWidget);
  });

  testWidgets('el médico atiende a Carmen: sin diagnóstico no puede finalizar; con él pasa a los resultados',
      (tester) async {
    final deps = staffDependencies(UserRole.doctor, doctorId: SeedIds.mendez);
    final c = openCaseOf(deps, SeedIds.carmen, ProcessStep.consultation);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar consulta'));
    await settle(tester);
    expect(deps.cases.caseById(c.id)!.consultation, isNotNull);
    expect(find.text('Carmen Reyes'), findsOneWidget);

    await tester.tap(find.byTooltip('Colgar'));
    await settle(tester);
    await tester.tap(find.text('Finalizar'));
    await settle(tester);
    expect(find.text('Escribe el motivo de consulta y el diagnóstico antes de finalizar.'), findsOneWidget);
    expect(deps.cases.caseById(c.id)!.currentStep, ProcessStep.consultation);

    // La hoja de notas se abrió sola: se completa el diagnóstico.
    await tester.enterText(find.widgetWithText(TextField, 'Diagnóstico *'), 'Lumbalgia mecánica');
    // Cierra la hoja con "atrás" (ocupa casi toda la pantalla y no deja tocar fuera).
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.byTooltip('Colgar'));
    await settle(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    final updated = deps.cases.caseById(c.id)!;
    expect(updated.currentStep, ProcessStep.consultationResult);
    expect(updated.consultation!.notes.diagnosis, 'Lumbalgia mecánica');
    expect(find.text('Emitir resultados'), findsWidgets);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/doctor/consultation_test.dart
```

Expected: FAIL. La agenda todavía es `CaseListScreen` y no tiene "Hoy".

- [ ] **Step 3: Crear la agenda, las notas y la consulta**

Create `saludconecta/lib/features/doctor/doctor_agenda_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/appointment_status_chip.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/people.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_exception.dart';
import '../../domain/process/process_step.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';

/// Agenda del médico (§6): sus citas con los pasos 6 a 8 pendientes, hoy y próximas.
class DoctorAgendaScreen extends StatelessWidget {
  const DoctorAgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doctor = context.watch<SessionProvider>().currentDoctor;
    if (doctor == null) return const SizedBox.shrink();
    final cases = context.watch<CaseProvider>();
    final items = cases.doctorAgenda(doctor.id);
    final today = DateUtils.dateOnly(cases.now);
    bool isToday(TelemedicineCase c) => DateUtils.isSameDay(c.appointment!.dateTime, today);
    final todays = [
      for (final c in items)
        if (isToday(c)) c,
    ];
    final upcoming = [
      for (final c in items)
        if (!isToday(c)) c,
    ];
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Mi agenda', style: theme.textTheme.headlineSmall),
          Text('${doctor.displayName} · ${doctor.specialty.label}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final (title, group) in [('Hoy', todays), ('Próximas', upcoming)]) ...[
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (group.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Sin citas.', style: theme.textTheme.bodyMedium),
              )
            else
              for (final c in group) _AgendaCard(telemedicineCase: c, doctor: doctor),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.telemedicineCase, required this.doctor});

  final TelemedicineCase telemedicineCase;
  final Doctor doctor;

  /// Abre la consulta; antes la marca como iniciada (en modo demo no espera la hora agendada).
  void _startConsultation(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    try {
      context.read<CaseProvider>().startConsultation(telemedicineCase.id, doctor: doctor);
      context.push(AppRoutes.caseAction(telemedicineCase.id, CaseAction.consultation));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final patient = catalog.patientById(c.patientId);
    final appointment = c.appointment!;
    final theme = Theme.of(context);
    final Widget? action = switch (c.currentStep) {
      ProcessStep.consultation => FilledButton.icon(
          onPressed: () => _startConsultation(context),
          icon: const Icon(Icons.video_call),
          label: const Text('Iniciar consulta'),
        ),
      ProcessStep.consultationResult => FilledButton.icon(
          onPressed: () => context.push(AppRoutes.caseAction(c.id, CaseAction.issueResults)),
          icon: const Icon(Icons.receipt_long),
          label: const Text('Emitir resultados'),
        ),
      _ => null,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.caseDetail(c.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarImage(name: patient.fullName, asset: patient.avatarAsset, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient.fullName, style: theme.textTheme.titleMedium),
                        Text(
                          '${catalog.serviceById(c.serviceId).name} · ${c.id}',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // El estado va junto a la fecha: en el teléfono el nombre del paciente usa toda la fila.
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppointmentStatusChip(telemedicineCase: c),
                  Text(
                    '${Formatters.dateTime(appointment.dateTime)} · ${appointment.platform.label}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (action != null) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/features/doctor/clinical_notes_form.dart`:

```dart
import 'package:flutter/material.dart';

/// Notas clínicas de la consulta. El motivo y el diagnóstico son obligatorios para finalizar (regla del paso 7).
class ClinicalNotesForm extends StatelessWidget {
  const ClinicalNotesForm({
    super.key,
    required this.complaint,
    required this.assessment,
    required this.diagnosis,
    required this.plan,
  });

  final TextEditingController complaint;
  final TextEditingController assessment;
  final TextEditingController diagnosis;
  final TextEditingController plan;

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController controller, String label, int lines) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: controller,
            minLines: lines,
            maxLines: lines + 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(complaint, 'Motivo de consulta *', 2),
        field(assessment, 'Evaluación', 3),
        field(diagnosis, 'Diagnóstico *', 2),
        field(plan, 'Plan', 3),
        Text('* Obligatorios para finalizar la consulta.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
```

Create `saludconecta/lib/features/doctor/consultation_screen.dart`:

```dart
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
```

En `saludconecta/lib/core/router/app_router.dart`, agregar después de `import '../../features/auth/welcome_screen.dart';`:

```dart
import '../../features/doctor/consultation_screen.dart';
import '../../features/doctor/doctor_agenda_screen.dart';
```

cambiar la pestaña "Agenda" del médico:

```dart
            (context, state) => CaseListScreen(
              title: 'Mi agenda',
              subtitle: 'Citas con los pasos 6 a 8 pendientes',
              select: (cases, session) => cases.doctorAgenda(session.currentDoctor?.id ?? ''),
            ),
```

por:

```dart
            (context, state) => const DoctorAgendaScreen(),
```

y, en `_caseAction`:

```dart
        CaseAction.consultation => const ComingSoonScreen(title: 'Consulta', stage: 7),
```

por:

```dart
        CaseAction.consultation => ConsultationScreen(caseId: caseId),
```

- [ ] **Step 4: Ejecutar la prueba y verificar que pasa**

```powershell
& $flutter test test/features/doctor/consultation_test.dart
```

Expected: `All tests passed!` (2 pruebas).

---

### Task 2: Emitir resultados

**Files:**
- Create: `saludconecta/lib/features/doctor/issue_results_screen.dart`
- Modify: `saludconecta/lib/core/router/app_router.dart` (edición)
- Test: `saludconecta/test/features/doctor/issue_results_test.dart`

**Interfaces:**
- Consumes: `CaseProvider.issueResults(id, {doctor, instructions, medications, orders, referral, followUpInDays})`.
- Produces: `IssueResultsScreen({required String caseId})`, con:
  - sugerencias de medicamentos (`ActionChip`) y "Otro medicamento" (diálogo);
  - órdenes (`FilterChip`), referimiento (interruptor), indicaciones con sugerencias y próxima cita (`SegmentedButton`);
  - el botón "Emitir y notificar".

- [ ] **Step 1: Escribir la prueba**

Create `saludconecta/test/features/doctor/issue_results_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Future<(AppDependencies, String)> openForm(WidgetTester tester) async {
    final deps = staffDependencies(UserRole.doctor, doctorId: SeedIds.mendez);
    final c = openCaseOf(deps, SeedIds.luisa, ProcessStep.consultationResult);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.issueResults));
    await tester.pumpAndSettle();
    return (deps, c.id);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 150, scrollable: find.byType(Scrollable).first);
    // Espera a que la lista deje de moverse (el arrastre deja inercia) antes de tocar.
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('sin indicaciones no se pueden emitir los resultados', (tester) async {
    final (deps, id) = await openForm(tester);
    await tapVisible(tester, find.text('Emitir y notificar'));
    expect(find.text('Las indicaciones son obligatorias.'), findsOneWidget);
    expect(deps.cases.caseById(id)!.currentStep, ProcessStep.consultationResult);
  });

  testWidgets('el médico emite receta, una orden, indicaciones y cita a 15 días para Luisa', (tester) async {
    final (deps, id) = await openForm(tester);
    await tapVisible(tester, find.widgetWithText(ActionChip, 'Acetaminofén 500 mg'));
    await tapVisible(tester, find.widgetWithText(FilterChip, 'Perfil lipídico'));
    final instructions = find.widgetWithText(TextField, 'Indicaciones para el paciente');
    await tester.scrollUntilVisible(instructions, 150, scrollable: find.byType(Scrollable).first);
    await tester.enterText(instructions, 'Dieta baja en grasas y control en 3 meses.');
    await tapVisible(tester, find.text('15 días'));
    await tapVisible(tester, find.text('Emitir y notificar'));

    final results = deps.cases.caseById(id)!.results!;
    expect(results.prescription!.items.single.medication, 'Acetaminofén 500 mg');
    expect(results.ordersOf(OrderType.lab).single.description, 'Perfil lipídico');
    expect(results.followUpInDays, 15);
    expect(deps.cases.caseById(id)!.currentStep, ProcessStep.administrativeClosure);
    expect(find.text('Mi agenda'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
& $flutter test test/features/doctor/issue_results_test.dart
```

Expected: FAIL. "Emitir resultados" todavía es `ComingSoonScreen`.

- [ ] **Step 3: Crear la pantalla**

Create `saludconecta/lib/features/doctor/issue_results_screen.dart`:

```dart
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
```

En `saludconecta/lib/core/router/app_router.dart`, cambiar:

```dart
import '../../features/doctor/doctor_agenda_screen.dart';
```

por:

```dart
import '../../features/doctor/doctor_agenda_screen.dart';
import '../../features/doctor/issue_results_screen.dart';
```

y, en `_caseAction`:

```dart
        CaseAction.issueResults => const ComingSoonScreen(title: 'Emitir resultados', stage: 7),
```

por:

```dart
        CaseAction.issueResults => IssueResultsScreen(caseId: caseId),
```

- [ ] **Step 4: Ejecutar las pruebas y verificar que pasan**

```powershell
& $flutter test test/features
```

Expected: `All tests passed!`

---

### Task 3: Verificación y commit de la etapa

- [ ] **Step 1:** `dart format -l 120 lib test` (0 cambios), `flutter test` y `flutter analyze` (sin avisos).
- [ ] **Step 2: Web:**
  1. Dr. Carlos Méndez → "Mi agenda" (Hoy y Próximas).
  2. Carmen → "Iniciar consulta" → videollamada del médico con el panel de notas (ventana ancha) → "Colgar" → "Finalizar".
  3. "Emitir resultados" con receta, orden e indicaciones → vuelve a la agenda.
  4. Con Carmen como paciente, sus resultados aparecen con la receta.
- [ ] **Step 3: Android:** recompilar, instalar y capturar la agenda del médico y la hoja de notas clínicas.
- [ ] **Step 4: Hoja de ruta:** fila de la etapa 7 con el enlace a este plan y "hecha".
- [ ] **Step 5: Commit:** "feat: flujo del Médico de SaludConecta (etapa 7)".

Siguiente paso: el plan de la etapa 8, `2026-11-10-saludconecta-08-flujo-facturacion.md`.
