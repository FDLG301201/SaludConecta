# SaludConecta · Etapa 6: Flujo de Admisión — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir las pantallas de Admisión (§6 Admisión): bandeja con filtros, "Procesar solicitud" (pasos 2–5, con rechazo → privado o cancelar), agenda por día y médico, y seguimiento con llamadas.

**Architecture:**

- Pantallas en `lib/features/admission/`. Leen `CaseProvider` (bandejas, `isBusy`, `now`) y llaman a sus acciones con el `StaffMember` de la sesión.
- `AdmissionFilter` (filtros de la bandeja) y `AppointmentStatusChip` (estado de una cita) son piezas puras y probadas; la etapa 7 reutiliza el chip en la agenda del médico.
- "Procesar solicitud" es un `Stepper` vertical. Abre en el paso pendiente del caso y solo construye el contenido del paso actual.
- Agendar usa `ScheduleService` (dominio) para los días y turnos libres.
- Las rutas se cambian con ediciones exactas en `app_router.dart`.

**Tech Stack:** `Stepper`, `ChoiceChip`, `SegmentedButton`, `LoadingButton` con `isBusy`, `showDialog`, `intl` (`DateFormat`).

**Hoja de ruta:** [00-hoja-de-ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md) · **Spec:** §6 Admisión, §4 (reglas del rechazo), §12

## Global Constraints

Las de la [hoja de ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md#global-constraints), y las notas de pruebas de la etapa 5:

- **Desplazamiento:** en las pruebas, `scrollUntilVisible` y después `pump()` antes de `tap`.
- **Hojas y diálogos** desde una pestaña: sobre el Navigator raíz.
- **Errores:** las `ProcessException` se muestran en un `SnackBar`, y lo que se usa después de un `await` se captura antes.
- **Git:** un solo commit al final (tarea 4), que también incluye `.gitignore` (ignora `graphify-out/`).

## Archivos de la etapa

| Archivo | Responsabilidad |
|---|---|
| `lib/features/admission/admission_filter.dart` | Filtros de la bandeja (Todas, Nuevas, Por validar, Por agendar, Por confirmar) |
| `lib/core/widgets/appointment_status_chip.dart` | Estado de una cita para las agendas |
| `lib/features/admission/admission_inbox_screen.dart` | Bandeja con filtros y tiempo de espera |
| `lib/features/admission/process_case_screen.dart` | `Stepper` de los pasos 2–5 |
| `lib/features/admission/admission_agenda_screen.dart` | Citas de 7 días, agrupadas por médico |
| `lib/features/admission/follow_up_screen.dart` | Casos en el paso 10 y registro de llamadas |
| `lib/core/router/app_router.dart` | Rutas de Admisión (ediciones) |
| `test/support/app_harness.dart` | + `staffDependencies(role, {doctorId})` |
| `test/features/admission/` | Pruebas |

---

### Task 1: Filtros, estado de la cita y bandeja

**Files:**
- Create: `saludconecta/lib/features/admission/admission_filter.dart`, `saludconecta/lib/core/widgets/appointment_status_chip.dart`, `saludconecta/lib/features/admission/admission_inbox_screen.dart`
- Modify: `saludconecta/lib/core/router/app_router.dart` (edición)
- Test: `saludconecta/test/support/app_harness.dart` (archivo completo), `saludconecta/test/features/admission/admission_inbox_test.dart`

**Interfaces:**
- Produces:
  - `enum AdmissionFilter { all, newRequests, toValidate, toSchedule, toConfirm }`, con `label`, `step` y `matches(TelemedicineCase)`.
  - `AppointmentStatusChip({required TelemedicineCase telemedicineCase})` y `AppointmentStatusChip.labelOf(c)`.
  - `AdmissionInboxScreen()`.
  - En las pruebas, `staffDependencies(UserRole role, {String? doctorId})`: Ana (Admisión), Roberto (Facturación) o el médico indicado, en su inicio.

- [ ] **Step 1: Escribir las pruebas**

Replace the whole content of `saludconecta/test/support/app_harness.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:saludconecta/app.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/models/telemedicine_case.dart';
import 'package:saludconecta/domain/process/process_step.dart';

/// Hora fija de las pruebas de widgets: lunes 9 de noviembre de 2026, 10:00.
final testNow = DateTime(2026, 11, 9, 10);

/// Dependencias de la app con la hora fija y sin pausas en los gateways.
AppDependencies testDependencies({String initialLocation = AppRoutes.welcome}) => AppDependencies.create(
      clock: () => testNow,
      insuranceDelay: Duration.zero,
      confirmationDelay: Duration.zero,
      initialLocation: initialLocation,
    );

/// La app completa, lista para `tester.pumpWidget`.
Widget appWith(AppDependencies dependencies) => dependencies.provide(SaludConectaApp(router: dependencies.router));

/// Atajo: la app desde la bienvenida (u otra ruta inicial).
Widget buildTestApp({String initialLocation = AppRoutes.welcome}) =>
    appWith(testDependencies(initialLocation: initialLocation));

/// Dependencias con el paciente [patientId] en sesión; la app abre en su Inicio.
AppDependencies patientDependencies(String patientId) {
  final deps = testDependencies(initialLocation: AppRoutes.patientHome);
  deps.session.loginPatient(deps.catalog.patientById(patientId));
  return deps;
}

/// Dependencias con el personal de [role] en sesión (para el médico, el de [doctorId]); la app abre en su inicio.
AppDependencies staffDependencies(UserRole role, {String? doctorId}) {
  final deps = testDependencies(initialLocation: AppRoutes.home(role));
  switch (role) {
    case UserRole.admission:
      deps.session.loginStaff(deps.catalog.staffFor(Actor.admission));
    case UserRole.billing:
      deps.session.loginStaff(deps.catalog.staffFor(Actor.billing));
    case UserRole.doctor:
      deps.session.loginDoctor(deps.catalog.doctorById(doctorId!));
    case UserRole.patient:
      throw ArgumentError('Para el paciente se usa patientDependencies.');
  }
  return deps;
}

/// El caso abierto de [patientId] con [step] pendiente (los casos en vivo L1–L10 de la semilla).
TelemedicineCase openCaseOf(AppDependencies deps, String patientId, ProcessStep step) =>
    deps.cases.casesOfPatient(patientId).firstWhere((c) => c.isOpen && c.currentStep == step);
```

Create `saludconecta/test/features/admission/admission_inbox_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/widgets/appointment_status_chip.dart';
import 'package:saludconecta/core/widgets/case_card.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/features/admission/admission_filter.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('los filtros reparten la bandeja por paso pendiente (los rechazados van en "Por validar")', () {
    final inbox = testDependencies().cases.admissionInbox();
    int count(AdmissionFilter f) => inbox.where(f.matches).length;
    expect(count(AdmissionFilter.all), 5);
    expect(count(AdmissionFilter.newRequests), 1);
    expect(count(AdmissionFilter.toValidate), 2);
    expect(count(AdmissionFilter.toSchedule), 1);
    expect(count(AdmissionFilter.toConfirm), 1);
  });

  test('el estado de la cita depende del paso pendiente', () {
    final deps = testDependencies();
    String label(String patientId, ProcessStep step) =>
        AppointmentStatusChip.labelOf(openCaseOf(deps, patientId, step));
    expect(label(SeedIds.ramon, ProcessStep.patientConfirmation), 'Por confirmar');
    expect(label(SeedIds.jose, ProcessStep.consentAdmission), 'Esperando consentimiento');
    expect(label(SeedIds.carmen, ProcessStep.consultation), 'Paciente en sala de espera');
    expect(label(SeedIds.luisa, ProcessStep.consultationResult), 'Resultados pendientes');
    expect(label(SeedIds.ramon, ProcessStep.administrativeClosure), 'Atendida');
  });

  testWidgets('la bandeja filtra por paso y muestra cuánto espera cada caso', (tester) async {
    await tester.pumpWidget(appWith(staffDependencies(UserRole.admission)));
    await tester.pumpAndSettle();
    expect(find.text('Bandeja de Admisión'), findsOneWidget);
    expect(find.text('Todas (5)'), findsOneWidget);
    expect(find.textContaining('Hace '), findsWidgets);

    await tester.tap(find.text('Por validar (2)'));
    await tester.pumpAndSettle();
    expect(find.byType(CaseCard), findsNWidgets(2));
    expect(find.text('Carmen Reyes'), findsOneWidget);
    expect(find.text('Pedro Almonte'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar las pruebas y verificar que fallan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/admission/admission_inbox_test.dart
```

Expected: FAIL. `admission_filter.dart` no existe.

- [ ] **Step 3: Crear los filtros, el chip de estado y la bandeja**

Create `saludconecta/lib/features/admission/admission_filter.dart`:

```dart
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_step.dart';

/// Filtros de la bandeja de Admisión: uno por paso pendiente (los rechazados quedan en el paso 3).
enum AdmissionFilter {
  all('Todas', null),
  newRequests('Nuevas', ProcessStep.reception),
  toValidate('Por validar', ProcessStep.insuranceValidation),
  toSchedule('Por agendar', ProcessStep.scheduling),
  toConfirm('Por confirmar', ProcessStep.patientConfirmation);

  const AdmissionFilter(this.label, this.step);

  final String label;

  /// Paso pendiente que muestra el filtro; `null` = todos.
  final ProcessStep? step;

  bool matches(TelemedicineCase c) => step == null || c.currentStep == step;
}
```

Create `saludconecta/lib/core/widgets/appointment_status_chip.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_step.dart';
import '../theme/app_colors.dart';

/// Estado de una cita en las agendas de Admisión y del médico.
class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  /// Texto del estado según el paso pendiente del caso.
  static String labelOf(TelemedicineCase c) {
    if (c.status == CaseStatus.cancelled) return 'Cancelada';
    if (c.status == CaseStatus.completed) return 'Atendida';
    return switch (c.currentStep) {
      ProcessStep.patientConfirmation => 'Por confirmar',
      ProcessStep.consentAdmission => 'Esperando consentimiento',
      ProcessStep.consultation => 'Paciente en sala de espera',
      ProcessStep.consultationResult => 'Resultados pendientes',
      ProcessStep.administrativeClosure || ProcessStep.followUp => 'Atendida',
      _ => c.currentStep.title,
    };
  }

  static Color colorOf(TelemedicineCase c) {
    if (c.status == CaseStatus.cancelled) return AppColors.danger;
    if (c.status == CaseStatus.completed || c.currentStep.number >= ProcessStep.administrativeClosure.number) {
      return AppColors.done;
    }
    return AppColors.forActor(c.currentStep.actor);
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(telemedicineCase);
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          labelOf(telemedicineCase),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/features/admission/admission_inbox_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/case_card.dart';
import '../../core/widgets/page_body.dart';
import '../../state/case_provider.dart';
import 'admission_filter.dart';

/// Bandeja de Admisión (§6): solicitudes con los pasos 2 a 5 pendientes, con filtros y su tiempo de espera.
class AdmissionInboxScreen extends StatefulWidget {
  const AdmissionInboxScreen({super.key});

  @override
  State<AdmissionInboxScreen> createState() => _AdmissionInboxScreenState();
}

class _AdmissionInboxScreenState extends State<AdmissionInboxScreen> {
  AdmissionFilter _filter = AdmissionFilter.all;

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final inbox = cases.admissionInbox();
    final shown = [
      for (final c in inbox)
        if (_filter.matches(c)) c,
    ];
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Bandeja de Admisión', style: theme.textTheme.headlineSmall),
          Text('Solicitudes con los pasos 2 a 5 pendientes; primero la más antigua', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in AdmissionFilter.values)
                ChoiceChip(
                  label: Text('${f.label} (${inbox.where(f.matches).length})'),
                  selected: f == _filter,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay solicitudes con este filtro.', textAlign: TextAlign.center),
              ),
            )
          else
            for (final c in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CaseCard(
                  telemedicineCase: c,
                  onTap: () => context.push(AppRoutes.caseDetail(c.id)),
                  trailing: Text(
                    'Hace ${Formatters.duration(cases.now.difference(c.updatedAt))}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
```

En `saludconecta/lib/core/router/app_router.dart`, agregar después de `import '../../domain/models/enums.dart';`:

```dart
import '../../features/admission/admission_inbox_screen.dart';
```

y cambiar la pestaña "Bandeja":

```dart
            (context, state) => CaseListScreen(
              title: 'Bandeja de Admisión',
              subtitle: 'Solicitudes con los pasos 2 a 5 pendientes',
              select: (cases, session) => cases.admissionInbox(),
            ),
```

por:

```dart
            (context, state) => const AdmissionInboxScreen(),
```

- [ ] **Step 4: Ejecutar las pruebas y verificar que pasan**

```powershell
& $flutter test test/features/admission/admission_inbox_test.dart test/features/login_flow_test.dart test/features/role_switcher_test.dart test/features/patient/request_appointment_test.dart
```

Expected: `All tests passed!` (3 de la bandeja, y las de ingreso, cambio de rol y solicitud, que pasan por la bandeja).

---

### Task 2: "Procesar solicitud" (pasos 2 a 5)

**Files:**
- Create: `saludconecta/lib/features/admission/process_case_screen.dart`
- Modify: `saludconecta/lib/core/router/app_router.dart` (edición)
- Test: `saludconecta/test/features/admission/process_case_test.dart`

**Interfaces:**
- Consumes: `registerReception`, `validateInsurance` (lenta), `continueAsPrivate`, `cancelCase`, `scheduleAppointment`, `sendConfirmation` (lenta) e `isBusy` de `CaseProvider`; `ScheduleService.availableDays` y `availableSlots`; `CaseNotice` (etapa 5).
- Produces: `ProcessCaseScreen({required String caseId})`. Botones: "Registrar solicitud", "Consultar al seguro", "Continuar como privado", "Cancelar solicitud", "Agendar cita" y "Enviar confirmación". Los turnos tienen las claves `ValueKey('slot_0')`, `ValueKey('slot_1')`…

- [ ] **Step 1: Escribir la prueba**

Create `saludconecta/test/features/admission/process_case_test.dart`:

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

  /// Ana abre "Procesar solicitud" del caso de [patientId] que tiene [step] pendiente.
  Future<(AppDependencies, String)> openProcess(WidgetTester tester, String patientId, ProcessStep step) async {
    final deps = staffDependencies(UserRole.admission);
    final c = openCaseOf(deps, patientId, step);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.process));
    await tester.pumpAndSettle();
    return (deps, c.id);
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 100, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('paso 2: Admisión registra la solicitud de José', (tester) async {
    final (deps, id) = await openProcess(tester, SeedIds.jose, ProcessStep.reception);
    expect(find.text('Procesar $id'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Paciente confirma síntomas por teléfono');
    await tapButton(tester, 'Registrar solicitud');
    final c = deps.cases.caseById(id)!;
    expect(c.currentStep, ProcessStep.insuranceValidation);
    expect(c.reception!.notes, 'Paciente confirma síntomas por teléfono');
    expect(find.text('Consultar al seguro'), findsOneWidget);
  });

  testWidgets('paso 3: el seguro aprueba la cobertura de Carmen', (tester) async {
    final (deps, id) = await openProcess(tester, SeedIds.carmen, ProcessStep.insuranceValidation);
    await tapButton(tester, 'Consultar al seguro');
    expect(deps.cases.caseById(id)!.currentStep, ProcessStep.scheduling);
    expect(find.textContaining('Seguro aprobado'), findsOneWidget);
  });

  testWidgets('paso 3: el seguro rechaza a Pedro y continúa como privado', (tester) async {
    final (deps, id) = await openProcess(tester, SeedIds.pedro, ProcessStep.insuranceValidation);
    await tapButton(tester, 'Consultar al seguro');
    expect(deps.cases.caseById(id)!.status, CaseStatus.insuranceRejected);
    expect(find.text('Afiliación inactiva'), findsWidgets);

    await tapButton(tester, 'Continuar como privado');
    final c = deps.cases.caseById(id)!;
    expect(c.privatePay, isTrue);
    expect(c.currentStep, ProcessStep.scheduling);
  });

  testWidgets('paso 4: Admisión agenda la cita de Luisa en el primer turno libre', (tester) async {
    final (deps, id) = await openProcess(tester, SeedIds.luisa, ProcessStep.scheduling);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('slot_0')), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('slot_0')));
    await tester.pump();
    await tapButton(tester, 'Agendar cita');
    final c = deps.cases.caseById(id)!;
    expect(c.currentStep, ProcessStep.patientConfirmation);
    expect(c.appointment!.platform, VideoPlatform.teams);
    expect(find.text('Vista previa del mensaje'), findsOneWidget);
  });

  testWidgets('paso 5: Admisión envía el enlace a Ramón y vuelve a la bandeja', (tester) async {
    final (deps, id) = await openProcess(tester, SeedIds.ramon, ProcessStep.patientConfirmation);
    await tapButton(tester, 'Enviar confirmación');
    final c = deps.cases.caseById(id)!;
    expect(c.currentStep, ProcessStep.consentAdmission);
    expect(c.confirmation!.sentVia, RequestChannel.whatsapp);
    expect(find.text('Bandeja de Admisión'), findsOneWidget);
  });

  testWidgets('un caso ya procesado muestra un aviso', (tester) async {
    await openProcess(tester, SeedIds.jose, ProcessStep.consentAdmission);
    expect(find.text('Esta solicitud ya fue procesada'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
& $flutter test test/features/admission/process_case_test.dart
```

Expected: FAIL. "Procesar solicitud" todavía es `ComingSoonScreen`.

- [ ] **Step 3: Crear la pantalla**

Create `saludconecta/lib/features/admission/process_case_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/loading_button.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/people.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_exception.dart';
import '../../domain/services/schedule_service.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';
import '../patient/patient_case_builder.dart';
import '../shared/not_found_screen.dart';

/// "Procesar solicitud" (§6 Admisión): `Stepper` vertical de los pasos 2 a 5.
/// Abre en el paso pendiente del caso; cada botón confirma una transición.
class ProcessCaseScreen extends StatelessWidget {
  const ProcessCaseScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CaseProvider>().caseById(caseId);
    if (c == null) {
      return const NotFoundScreen(title: 'Caso no encontrado', message: 'El caso que buscas no existe.');
    }
    final step = c.currentStep.number;
    if (!c.isOpen || step < 2 || step > 5) {
      return CaseNotice(
        screenTitle: 'Procesar solicitud',
        title: 'Esta solicitud ya fue procesada',
        message: 'El caso ${c.id} está en el paso $step: ${c.currentStep.title}.',
      );
    }
    return _ProcessForm(telemedicineCase: c);
  }
}

class _ProcessForm extends StatefulWidget {
  const _ProcessForm({required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  @override
  State<_ProcessForm> createState() => _ProcessFormState();
}

class _ProcessFormState extends State<_ProcessForm> {
  final _notes = TextEditingController();
  Doctor? _doctor;
  DateTime? _day;
  DateTime? _slot;
  VideoPlatform _platform = VideoPlatform.teams;
  RequestChannel _via = RequestChannel.whatsapp;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  TelemedicineCase get _case => widget.telemedicineCase;

  StaffMember get _staff => context.read<SessionProvider>().currentStaff!;

  /// Ejecuta una transición y avisa el resultado (o el error de la regla) en un `SnackBar`.
  void _run(void Function() action, String success) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    try {
      action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _validateInsurance() async {
    final cases = context.read<CaseProvider>();
    final staff = _staff;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await cases.validateInsurance(_case.id, staff: staff);
      messenger.showSnackBar(SnackBar(
        content: Text(r.approved
            ? 'Seguro aprobado: ${r.coveragePercent}% de cobertura (${r.authorizationNumber}).'
            : 'El seguro rechazó la cobertura: ${r.message}.'),
      ));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _sendConfirmation() async {
    final cases = context.read<CaseProvider>();
    final staff = _staff;
    final via = _via;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final link = await cases.sendConfirmation(_case.id, staff: staff, via: via);
      messenger.showSnackBar(SnackBar(content: Text('Enlace enviado por ${via.label}: $link')));
      router.go(AppRoutes.admissionInbox);
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _case.currentStep.number - 2;
    Step step(int index, String title, Widget Function() content) => Step(
          title: Text(title),
          isActive: index <= current,
          state: index < current ? StepState.complete : StepState.indexed,
          // Solo se construye el paso actual: los demás no tienen nada que hacer.
          content: index == current ? content() : const SizedBox.shrink(),
        );
    return Scaffold(
      appBar: AppBar(title: Text('Procesar ${_case.id}')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Stepper(
            currentStep: current,
            controlsBuilder: (context, details) => const SizedBox.shrink(),
            steps: [
              step(0, 'Registrar', _register),
              step(1, 'Validar seguro', _validate),
              step(2, 'Agendar', _schedule),
              step(3, 'Confirmar', _confirm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _register() {
    final catalog = context.read<CatalogRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Info('Paciente', catalog.patientById(_case.patientId).fullName),
        _Info('Servicio', catalog.serviceById(_case.serviceId).name),
        _Info('Canal', _case.channel.label),
        _Info('Motivo', _case.reason),
        _Info('Fecha preferida', Formatters.date(_case.preferredDate)),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notas de recepción (opcional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _run(
            () => context.read<CaseProvider>().registerReception(_case.id, staff: _staff, notes: _notes.text.trim()),
            'Solicitud registrada.',
          ),
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Registrar solicitud'),
        ),
      ],
    );
  }

  Widget _validate() {
    final catalog = context.read<CatalogRepository>();
    final patient = catalog.patientById(_case.patientId);
    final affiliation = patient.affiliation;
    final busy = context.watch<CaseProvider>().isBusy(_case.id);
    final result = _case.insurance;
    final rejected = _case.status == CaseStatus.insuranceRejected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Info('Aseguradora', catalog.insurerById(affiliation.insurerId).name),
        _Info('Plan', affiliation.plan),
        _Info('Carnet', affiliation.affiliateNumber),
        _Info('Afiliación', affiliation.active ? 'Activa' : 'Inactiva'),
        const SizedBox(height: 12),
        if (!rejected)
          LoadingButton(
            label: busy ? 'Consultando al seguro…' : 'Consultar al seguro',
            icon: Icons.verified_user_outlined,
            loading: busy,
            onPressed: _validateInsurance,
          ),
        if (rejected && result != null) ...[
          Card(
            color: AppColors.danger.withOpacity(0.08),
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.gpp_bad_outlined, color: AppColors.danger),
              title: const Text('Rechazado por el seguro'),
              subtitle: Text(result.message),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _run(
                  () => context.read<CaseProvider>().continueAsPrivate(_case.id, staff: _staff),
                  'El paciente continúa como privado (100%).',
                ),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Continuar como privado'),
              ),
              OutlinedButton.icon(
                onPressed: () => _run(
                  () => context.read<CaseProvider>().cancelCase(
                        _case.id,
                        role: UserRole.admission,
                        actorName: _staff.fullName,
                        reason: 'Rechazo del seguro',
                      ),
                  'La solicitud fue cancelada.',
                ),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar solicitud'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _schedule() {
    final cases = context.read<CaseProvider>();
    final catalog = context.read<CatalogRepository>();
    final theme = Theme.of(context);
    final service = catalog.serviceById(_case.serviceId);
    final specialty = service.specialty;
    final doctors = specialty == null ? const <Doctor>[] : catalog.doctorsFor(specialty);
    final doctor = _doctor ?? (doctors.isEmpty ? null : doctors.first);
    final days = doctor == null
        ? const <DateTime>[]
        : ScheduleService.availableDays(doctor: doctor, cases: cases.cases, now: cases.now);
    final chosenDay = _day;
    final day = chosenDay != null && days.any((d) => DateUtils.isSameDay(d, chosenDay))
        ? chosenDay
        : (days.isEmpty ? null : days.first);
    final slots = doctor == null || day == null
        ? const <DateTime>[]
        : ScheduleService.availableSlots(doctor: doctor, day: day, cases: cases.cases, now: cases.now);
    final slot = slots.contains(_slot) ? _slot : null;
    final dayFormat = DateFormat('EEE d MMM', 'es');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Médico (${specialty?.label ?? 'sin especialidad'})', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in doctors)
              ChoiceChip(
                avatar: AvatarImage(name: d.displayName, asset: d.avatarAsset, size: 24),
                label: Text(d.displayName),
                selected: d.id == doctor?.id,
                onSelected: (_) => setState(() {
                  _doctor = d;
                  _day = null;
                  _slot = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Día (próximos ${ScheduleService.horizonDays} días con turnos libres)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in days)
              ChoiceChip(
                label: Text(dayFormat.format(d)),
                selected: day != null && DateUtils.isSameDay(d, day),
                onSelected: (_) => setState(() {
                  _day = d;
                  _slot = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Hora', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          const Text('No hay turnos libres para ese médico.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < slots.length; i++)
                ChoiceChip(
                  key: ValueKey('slot_$i'),
                  label: Text(Formatters.time(slots[i])),
                  selected: slots[i] == slot,
                  onSelected: (_) => setState(() => _slot = slots[i]),
                ),
            ],
          ),
        const SizedBox(height: 16),
        Text('Plataforma', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<VideoPlatform>(
          showSelectedIcon: false,
          segments: [
            for (final p in VideoPlatform.values)
              ButtonSegment(value: p, label: Text(p.label), icon: Icon(AppIcons.platform(p))),
          ],
          selected: {_platform},
          onSelectionChanged: (selection) => setState(() => _platform = selection.first),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: doctor == null || slot == null
              ? null
              : () => _run(
                    () => cases.scheduleAppointment(
                      _case.id,
                      staff: _staff,
                      doctor: doctor,
                      dateTime: slot,
                      platform: _platform,
                    ),
                    'Cita agendada: ${Formatters.dateTime(slot)} con ${doctor.displayName}.',
                  ),
          icon: const Icon(Icons.event_available),
          label: const Text('Agendar cita'),
        ),
      ],
    );
  }

  Widget _confirm() {
    final catalog = context.read<CatalogRepository>();
    final busy = context.watch<CaseProvider>().isBusy(_case.id);
    final appointment = _case.appointment!;
    final patient = catalog.patientById(_case.patientId);
    final doctor = catalog.doctorById(appointment.doctorId);
    final theme = Theme.of(context);
    final message = 'Hola, ${patient.firstName}. Tu cita de ${catalog.serviceById(_case.serviceId).name} es el '
        '${Formatters.dateTime(appointment.dateTime)} con ${doctor.displayName} por ${appointment.platform.label}. '
        'Ingresa 10 minutos antes con el enlace de este mensaje y firma tu consentimiento en la app SaludConecta.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vista previa del mensaje', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(padding: const EdgeInsets.all(14), child: Text(message)),
        ),
        const SizedBox(height: 16),
        Text('Enviar por', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<RequestChannel>(
          showSelectedIcon: false,
          segments: [
            for (final channel in [RequestChannel.whatsapp, RequestChannel.email])
              ButtonSegment(value: channel, label: Text(channel.label), icon: Icon(AppIcons.channel(channel))),
          ],
          selected: {_via},
          onSelectionChanged: (selection) => setState(() => _via = selection.first),
        ),
        const SizedBox(height: 16),
        LoadingButton(
          label: busy ? 'Enviando…' : 'Enviar confirmación',
          icon: Icons.send,
          loading: busy,
          onPressed: _sendConfirmation,
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
```

En `saludconecta/lib/core/router/app_router.dart`, cambiar:

```dart
import '../../features/admission/admission_inbox_screen.dart';
```

por:

```dart
import '../../features/admission/admission_inbox_screen.dart';
import '../../features/admission/process_case_screen.dart';
```

y, en `_caseAction`:

```dart
        CaseAction.process => const ComingSoonScreen(title: 'Procesar solicitud', stage: 6),
```

por:

```dart
        CaseAction.process => ProcessCaseScreen(caseId: caseId),
```

- [ ] **Step 4: Ejecutar la prueba y verificar que pasa**

```powershell
& $flutter test test/features/admission/process_case_test.dart
```

Expected: `All tests passed!` (6 pruebas).

---

### Task 3: Agenda y seguimiento

**Files:**
- Create: `saludconecta/lib/features/admission/admission_agenda_screen.dart`, `saludconecta/lib/features/admission/follow_up_screen.dart`
- Modify: `saludconecta/lib/core/router/app_router.dart` (edición)
- Test: `saludconecta/test/features/admission/agenda_and_follow_up_test.dart`

**Interfaces:**
- Consumes: `AppointmentStatusChip` (tarea 1), `CaseProvider.followUpCases()` y `logFollowUpCall(id, {staff, note})`.
- Produces: `AdmissionAgendaScreen()` (selector de 7 días; citas del día agrupadas por médico) y `FollowUpScreen()` (botón "Registrar llamada", diálogo con "Guardar").

- [ ] **Step 1: Escribir la prueba**

Create `saludconecta/test/features/admission/agenda_and_follow_up_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('la agenda de hoy agrupa las citas por médico con su estado', (tester) async {
    final deps = staffDependencies(UserRole.admission);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(AppRoutes.admissionAgenda);
    await tester.pumpAndSettle();
    expect(find.text('Agenda'), findsWidgets);
    expect(find.text('Dr. Carlos Méndez'), findsOneWidget);
    expect(find.text('Paciente en sala de espera'), findsWidgets);
  });

  testWidgets('Admisión registra una llamada de seguimiento a José', (tester) async {
    final deps = staffDependencies(UserRole.admission);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.followUp);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(AppRoutes.admissionFollowUp);
    await tester.pumpAndSettle();
    expect(find.text('Encuesta pendiente'), findsWidgets);

    await tester.tap(find.text('Registrar llamada').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Se siente mejor; recordó su vacuna');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final calls = deps.cases.caseById(c.id)!.followUp!.calls;
    expect(calls.last.note, 'Se siente mejor; recordó su vacuna');
    expect(find.textContaining('Se siente mejor'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
& $flutter test test/features/admission/agenda_and_follow_up_test.dart
```

Expected: FAIL. La agenda todavía es `ComingSoonScreen`.

- [ ] **Step 3: Crear la agenda y el seguimiento**

Create `saludconecta/lib/features/admission/admission_agenda_screen.dart`:

```dart
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
```

Create `saludconecta/lib/features/admission/follow_up_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_exception.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';

/// Seguimiento (§6 Admisión): casos con el paso 10 pendiente, sus llamadas y el estado de la encuesta.
class FollowUpScreen extends StatelessWidget {
  const FollowUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<CaseProvider>().followUpCases();
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Seguimiento', style: theme.textTheme.headlineSmall),
          Text('Casos con el paso 10 pendiente: llamadas y encuesta', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay casos en seguimiento.', textAlign: TextAlign.center),
              ),
            )
          else
            for (final c in items) _FollowUpCard(telemedicineCase: c),
        ],
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  Future<void> _logCall(BuildContext context) async {
    final cases = context.read<CaseProvider>();
    final staff = context.read<SessionProvider>().currentStaff!;
    final messenger = ScaffoldMessenger.of(context);
    final note = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => const _CallDialog(),
    );
    if (note == null) return;
    try {
      cases.logFollowUpCall(telemedicineCase.id, staff: staff, note: note);
      messenger.showSnackBar(const SnackBar(content: Text('Llamada registrada.')));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final patient = catalog.patientById(c.patientId);
    final calls = c.followUp?.calls ?? const [];
    final theme = Theme.of(context);
    return Card(
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
                      Text('${catalog.serviceById(c.serviceId).name} · ${c.id}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.current.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      'Encuesta pendiente',
                      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.currentText),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (calls.isEmpty)
              Text('Sin llamadas registradas.', style: theme.textTheme.bodySmall)
            else
              for (final call in calls)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${Formatters.dateTime(call.at)} · ${call.byName}: ${call.note}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _logCall(context),
                  icon: const Icon(Icons.call),
                  label: const Text('Registrar llamada'),
                ),
                TextButton(onPressed: () => context.push(AppRoutes.caseDetail(c.id)), child: const Text('Ver caso')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para escribir la nota de la llamada; devuelve el texto o `null` si se cancela.
class _CallDialog extends StatefulWidget {
  const _CallDialog();

  @override
  State<_CallDialog> createState() => _CallDialogState();
}

class _CallDialogState extends State<_CallDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar llamada'),
      content: TextField(
        controller: _note,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Nota de la llamada', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, _note.text.trim()), child: const Text('Guardar')),
      ],
    );
  }
}
```

En `saludconecta/lib/core/router/app_router.dart`, cambiar:

```dart
import '../../features/admission/admission_inbox_screen.dart';
import '../../features/admission/process_case_screen.dart';
```

por:

```dart
import '../../features/admission/admission_agenda_screen.dart';
import '../../features/admission/admission_inbox_screen.dart';
import '../../features/admission/follow_up_screen.dart';
import '../../features/admission/process_case_screen.dart';
```

la pestaña "Agenda":

```dart
          _Tab(AppRoutes.admissionAgenda, 'Agenda', Icons.calendar_month_outlined, Icons.calendar_month,
              (context, state) => const ComingSoonScreen(title: 'Agenda', stage: 6, inShell: true)),
```

por:

```dart
          _Tab(AppRoutes.admissionAgenda, 'Agenda', Icons.calendar_month_outlined, Icons.calendar_month,
              (context, state) => const AdmissionAgendaScreen()),
```

y la pestaña "Seguimiento":

```dart
            (context, state) => CaseListScreen(
              title: 'Seguimiento',
              subtitle: 'Casos con el paso 10 pendiente',
              select: (cases, session) => cases.followUpCases(),
            ),
```

por:

```dart
            (context, state) => const FollowUpScreen(),
```

- [ ] **Step 4: Ejecutar las pruebas y verificar que pasan**

```powershell
& $flutter test test/features
```

Expected: `All tests passed!`

---

### Task 4: Verificación y commit de la etapa

- [ ] **Step 1: Formato, suite completa y análisis:** `dart format -l 120 lib test` (0 cambios), `flutter test` y `flutter analyze` (sin avisos).
- [ ] **Step 2: Recorrido en la web** (`saludconecta-web`):
  1. Ana Peña → bandeja con los filtros y sus contadores.
  2. "Por validar" → Pedro → "Procesar solicitud" → "Consultar al seguro" (rechazo, "Afiliación inactiva") → "Continuar como privado" → agendar → confirmar por WhatsApp; vuelve a la bandeja con el aviso.
  3. Agenda de hoy y de otro día.
  4. Seguimiento → "Registrar llamada".
- [ ] **Step 3: Android:** recompilar e instalar el APK, entrar como Ana y capturar la bandeja y "Procesar solicitud" (diseño angosto).
- [ ] **Step 4: Hoja de ruta:** fila de la etapa 6 con el enlace a este plan y "hecha".
- [ ] **Step 5: Commit:**

```powershell
git -C $repo add .gitignore saludconecta docs/superpowers/plans
git -C $repo commit -m "feat: flujo de Admisión de SaludConecta (etapa 6)" -m "Bandeja con filtros, procesar solicitud (registro, validación con rechazo a privado o cancelación, agendamiento con turnos libres y confirmación), agenda por médico y seguimiento con llamadas."
```

Siguiente paso: el plan de la etapa 7, `2026-11-10-saludconecta-07-flujo-medico.md`.
