# SaludConecta · Etapa 5: Flujo del paciente — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir todas las pantallas del paciente (§6 Paciente): solicitar cita, Inicio con avisos, Mis citas, Servicios, Perfil, consentimiento con firma, sala de espera, videollamada, resultados con QR y encuesta.

**Architecture:**

- **Pantallas del paciente** en `lib/features/patient/`. Solo leen el estado (`CaseProvider`, `SessionProvider`) y llaman a sus acciones; el catálogo se consulta con `context.read<CatalogRepository>()`.
- **Acciones sobre un caso** (`/caso/:id/<acción>`): `PatientCaseBuilder` busca el caso del paciente en sesión (o muestra "Caso no encontrado") y `CaseNotice` explica cuándo la acción no corresponde al paso actual.
- **Videollamada:** `VideoCallView(perspective)` vive en `features/shared/` porque la etapa 7 la reutiliza para el médico (con `extraControls` y su propio `onHangUp`).
- **Rutas:** cada tarea cambia `app_router.dart` con ediciones exactas (no con el archivo completo), para que cada tarea compile y pruebe sola.

**Tech Stack:** `Stepper` + `Form`, `PageView`, `TabBar`, `CustomPainter` (firma), `AnimationController` (prueba de conexión y anillo de la videollamada), `Badge`, `qr_flutter` (QR de la receta), `url_launcher` (`tel:` de soporte).

**Hoja de ruta:** [00-hoja-de-ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md) · **Spec:** §6 Paciente, §6 Pantallas comunes (videollamada), §9, §12

## Global Constraints

Las de la [hoja de ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md#global-constraints). Las más relevantes para esta etapa:

- **APIs de Flutter 3.19:** `withOpacity`, `surfaceVariant`, `RadioListTile.groupValue`; nada de `WidgetState*` ni `Color.withValues`.
- **Capas:** la UI no toca repositorios ni gateways. La única constante de datos que usa es `SeedIds.postConsultFollowUp` (el servicio de las citas de seguimiento).
- **Errores:** las `ProcessException` se muestran en un `SnackBar`. Después de un `await` no se usa `context`: se capturan antes `ScaffoldMessenger`, `GoRouter` y los providers.
- **Animaciones y pruebas:** la videollamada tiene animaciones que no terminan, así que sus pruebas usan `pump(duración)` en lugar de `pumpAndSettle`. La prueba de conexión sí termina (2.4 s).
- **Formato:** `dart format -l 120`. Las llamadas que no caben en una línea llevan coma final.
- **Git:** un solo commit al final de la etapa (tarea 7).

## Archivos de la etapa

| Archivo | Responsabilidad |
|---|---|
| `lib/core/router/app_routes.dart` | + `requestAppointment({serviceId, preferredDate})` e `isoDate` |
| `lib/core/router/app_router.dart` | Rutas del paciente apuntando a sus pantallas (ediciones por tarea) |
| `lib/features/patient/request/request_appointment_screen.dart` | Asistente "Solicitar cita" (3 pasos) |
| `lib/features/patient/patient_notifications.dart` | Avisos del paciente y cuántos no ha leído |
| `lib/features/patient/home/` | `notification_bell.dart`, `active_case_card.dart`, `health_tips_carousel.dart` |
| `lib/features/patient/patient_home_screen.dart` | Inicio completo |
| `lib/features/patient/appointments_screen.dart` | Mis citas (Activas / Historial) |
| `lib/features/patient/services_screen.dart` | Los 24 servicios y los canales |
| `lib/features/patient/profile/` | `insurance_card.dart` (carnet) y `profile_screen.dart` |
| `lib/features/patient/patient_case_builder.dart` | `PatientCaseBuilder` y `CaseNotice` |
| `lib/features/patient/consent/` | `signature_pad.dart` (firma) y `consent_screen.dart` |
| `lib/features/patient/waiting_room/` | `connection_check.dart` y `waiting_room_screen.dart` |
| `lib/features/shared/video_call/video_call_view.dart` | Videollamada simulada (paciente y médico) |
| `lib/features/patient/call/patient_video_call_screen.dart` | Videollamada del paciente |
| `lib/features/patient/results/` | `prescription_document.dart` (receta con QR) y `results_screen.dart` |
| `lib/features/patient/survey/survey_screen.dart` | Encuesta de satisfacción |
| `lib/features/shared/case_detail/case_detail_screen.dart` | + botón "Ver mis resultados" |
| `test/support/app_harness.dart` | + `patientDependencies` y `openCaseOf` |
| `test/core/router/app_routes_test.dart`, `test/features/patient/` | Pruebas |

---

### Task 1: Asistente "Solicitar cita"

**Files:**
- Modify: `saludconecta/lib/core/router/app_routes.dart` (archivo completo), `saludconecta/lib/core/router/app_router.dart` (edición)
- Create: `saludconecta/lib/features/patient/request/request_appointment_screen.dart`
- Test: `saludconecta/test/support/app_harness.dart` (archivo completo), `saludconecta/test/core/router/app_routes_test.dart`, `saludconecta/test/features/patient/request_appointment_test.dart`

**Interfaces:**
- Consumes: `CaseProvider.requestAppointment(...)` y `now`, `SessionProvider.currentPatient`, `CatalogRepository` (etapa 4).
- Produces:
  - `AppRoutes.requestAppointment({String? serviceId, DateTime? preferredDate})` → `/paciente/solicitar?servicio=…&fecha=aaaa-mm-dd`, y `AppRoutes.isoDate(DateTime)`.
  - `RequestAppointmentScreen({String? initialServiceId, DateTime? initialDate})`: con servicio, abre en "Canal y motivo".
  - Pruebas: `patientDependencies(String patientId)` (paciente en sesión, en su Inicio) y `openCaseOf(deps, patientId, step)` (su caso en vivo con ese paso pendiente).

- [ ] **Step 1: Escribir las pruebas**

Replace the whole content of `saludconecta/test/support/app_harness.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:saludconecta/app.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';
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

/// El caso abierto de [patientId] con [step] pendiente (los casos en vivo L1–L10 de la semilla).
TelemedicineCase openCaseOf(AppDependencies deps, String patientId, ProcessStep step) =>
    deps.cases.casesOfPatient(patientId).firstWhere((c) => c.isOpen && c.currentStep == step);
```

Create `saludconecta/test/core/router/app_routes_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/router/app_routes.dart';

void main() {
  test('el asistente recibe el servicio y la fecha preferida por la URL', () {
    expect(AppRoutes.requestAppointment(), '/paciente/solicitar');
    expect(AppRoutes.requestAppointment(serviceId: 'nutricion'), '/paciente/solicitar?servicio=nutricion');
    expect(
      AppRoutes.requestAppointment(serviceId: 'seguimiento-postconsulta', preferredDate: DateTime(2026, 12, 9)),
      '/paciente/solicitar?servicio=seguimiento-postconsulta&fecha=2026-12-09',
    );
    expect(AppRoutes.isoDate(DateTime(2027, 1, 5)), '2027-01-05');
    expect(DateTime.tryParse(AppRoutes.isoDate(DateTime(2027, 1, 5))), DateTime(2027, 1, 5));
  });
}
```

Create `saludconecta/test/features/patient/request_appointment_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Future<AppDependencies> openWizard(WidgetTester tester, {String? serviceId}) async {
    final deps = patientDependencies(SeedIds.maria);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.requestAppointment(serviceId: serviceId));
    await tester.pumpAndSettle();
    return deps;
  }

  testWidgets('valida cada paso, crea la solicitud y esta llega a la bandeja de Admisión', (tester) async {
    final deps = await openWizard(tester);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Elige un servicio.'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consulta médica general').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Fiebre');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Elige un canal.'), findsOneWidget);
    expect(find.text('Describe el motivo de consulta con al menos 10 caracteres.'), findsOneWidget);

    await tester.tap(find.text('WhatsApp'));
    await tester.enterText(find.byType(TextFormField), 'Fiebre y dolor de garganta desde ayer');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('80% con ARS Salud Plena (plan Plus), sujeto a validación'), findsOneWidget);

    // El resumen es largo: se desplaza la lista hasta ver el botón.
    await tester.scrollUntilVisible(find.text('Enviar solicitud'), 100, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();
    final created = deps.cases.casesOfPatient(SeedIds.maria).first;
    expect(created.isOpen, isTrue);
    expect(find.text('Caso ${created.id}'), findsOneWidget);
    expect(find.text('Esperando a Admisión: Recepción en Hospital / PSS'), findsOneWidget);

    // La solicitud nueva aparece en la bandeja de Admisión (al final: la bandeja va de la más antigua a la más nueva).
    deps.session.loginStaff(deps.catalog.staffFor(Actor.admission));
    deps.router.go(AppRoutes.admissionInbox);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('María Fernández'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('María Fernández'), findsOneWidget);
  });

  testWidgets('con un servicio en la URL, el asistente abre en "Canal y motivo"', (tester) async {
    await openWizard(tester, serviceId: SeedIds.nutrition);
    expect(find.text('¿Por qué canal nos contactas?'), findsOneWidget);

    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    final field = tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
    expect(field.initialValue, SeedIds.nutrition);
  });

  testWidgets('en un teléfono el asistente es vertical y empieza arriba', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openWizard(tester);
    expect(tester.widget<Stepper>(find.byType(Stepper)).type, StepperType.vertical);
    expect(tester.getTopLeft(find.text('¿Qué servicio necesitas?')).dy, lessThan(200));
  });
}
```

- [ ] **Step 2: Ejecutar las pruebas y verificar que fallan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/core/router/app_routes_test.dart test/features/patient/request_appointment_test.dart
```

Expected: FAIL. `AppRoutes.isoDate` no existe y la ruta `/paciente/solicitar` todavía es `ComingSoonScreen`.

- [ ] **Step 3: Crear las rutas con fecha y el asistente**

Replace the whole content of `saludconecta/lib/core/router/app_routes.dart`:

```dart
import '../../domain/models/enums.dart';

/// Rutas de la app (§6 del spec). Las pantallas navegan con estas constantes, nunca con texto suelto.
class AppRoutes {
  const AppRoutes._();

  // Ingreso (públicas).
  static const welcome = '/bienvenida';
  static const login = '/ingreso';
  static const patientLogin = '/ingreso/paciente';
  static String staffLogin(UserRole role) => '/ingreso/personal/${role.slug}';

  // Paciente.
  static const patientHome = '/paciente';
  static const patientAppointments = '/paciente/citas';
  static const patientServices = '/paciente/servicios';
  static const patientProfile = '/paciente/perfil';
  static const requestAppointmentPath = '/paciente/solicitar';

  /// Asistente "Solicitar cita". Puede llevar el servicio y la fecha preferida ya elegidos
  /// (desde Servicios, o desde los resultados para la cita de seguimiento).
  static String requestAppointment({String? serviceId, DateTime? preferredDate}) {
    final query = <String, String>{
      if (serviceId != null) 'servicio': serviceId,
      if (preferredDate != null) 'fecha': isoDate(preferredDate),
    };
    return Uri(path: requestAppointmentPath, queryParameters: query.isEmpty ? null : query).toString();
  }

  /// Fecha para la URL, p. ej. "2026-12-09"; `DateTime.tryParse` la lee de vuelta.
  static String isoDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  // Admisión.
  static const admissionInbox = '/admision';
  static const admissionAgenda = '/admision/agenda';
  static const admissionFollowUp = '/admision/seguimiento';
  static const admissionIndicators = '/admision/indicadores';

  // Médico.
  static const doctorAgenda = '/medico';
  static const doctorIndicators = '/medico/indicadores';

  // Facturación.
  static const billingPending = '/facturacion';
  static const billingClaims = '/facturacion/reclamaciones';
  static const billingIndicators = '/facturacion/indicadores';

  // Comunes a todos los roles.
  static const process = '/proceso';
  static const about = '/acerca';

  static String caseDetail(String id) => '/caso/$id';
  static String caseDiagram(String id) => '/caso/$id/diagrama';
  static String caseAction(String id, CaseAction action) => '/caso/$id/${action.segment}';

  /// Inicio de cada rol.
  static String home(UserRole role) => switch (role) {
        UserRole.patient => patientHome,
        UserRole.admission => admissionInbox,
        UserRole.doctor => doctorAgenda,
        UserRole.billing => billingPending,
      };
}

/// Pantallas de acción sobre un caso (`/caso/:id/<segmento>`) y el rol que puede abrirlas.
enum CaseAction {
  consent('consentimiento', UserRole.patient),
  waitingRoom('sala-espera', UserRole.patient),
  videoCall('videollamada', UserRole.patient),
  results('resultados', UserRole.patient),
  survey('encuesta', UserRole.patient),
  process('procesar', UserRole.admission),
  consultation('consulta', UserRole.doctor),
  issueResults('emitir-resultados', UserRole.doctor),
  closure('cierre', UserRole.billing);

  const CaseAction(this.segment, this.role);

  final String segment;
  final UserRole role;

  static CaseAction? fromSegment(String segment) {
    for (final action in CaseAction.values) {
      if (action.segment == segment) return action;
    }
    return null;
  }
}
```

Create `saludconecta/lib/features/patient/request/request_appointment_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/catalog.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/people.dart';
import '../../../domain/process/process_exception.dart';
import '../../../state/case_provider.dart';
import '../../../state/session_provider.dart';

/// Asistente "Solicitar cita" (paso 1 del proceso): servicio → canal y motivo → fecha y resumen.
///
/// Cada paso tiene su `Form` con validaciones (el servicio se elige en una lista desplegable).
/// En pantallas angostas el `Stepper` es vertical.
class RequestAppointmentScreen extends StatefulWidget {
  const RequestAppointmentScreen({super.key, this.initialServiceId, this.initialDate});

  /// Servicio ya elegido (desde Servicios o desde los resultados): el asistente abre en "Canal y motivo".
  final String? initialServiceId;

  /// Fecha preferida sugerida (cita de seguimiento).
  final DateTime? initialDate;

  @override
  State<RequestAppointmentScreen> createState() => _RequestAppointmentScreenState();
}

class _RequestAppointmentScreenState extends State<RequestAppointmentScreen> {
  static const _lastStep = 2;

  final _formKeys = [GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>()];
  final _reason = TextEditingController();
  int _step = 0;
  String? _serviceId;
  RequestChannel? _channel;
  late DateTime _firstDate;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final catalog = context.read<CatalogRepository>();
    final now = context.read<CaseProvider>().now;
    // La fecha preferida va de mañana a 60 días.
    _firstDate = DateTime(now.year, now.month, now.day + 1);
    final preset = widget.initialServiceId;
    if (preset != null && catalog.services.any((s) => s.id == preset && s.requestable)) {
      _serviceId = preset;
      _step = 1;
    }
    final suggested = widget.initialDate;
    _date = suggested != null && !suggested.isBefore(_firstDate) ? DateUtils.dateOnly(suggested) : _nextWorkingDay();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Mañana, o el lunes si mañana es domingo.
  DateTime _nextWorkingDay() =>
      _firstDate.weekday == DateTime.sunday ? DateUtils.addDaysToDate(_firstDate, 1) : _firstDate;

  void _continue() {
    if (!(_formKeys[_step].currentState?.validate() ?? false)) return;
    if (_step < _lastStep) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _submit() {
    final patient = context.read<SessionProvider>().currentPatient;
    final serviceId = _serviceId;
    final channel = _channel;
    if (patient == null || serviceId == null || channel == null) return;
    final cases = context.read<CaseProvider>();
    final catalog = context.read<CatalogRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final c = cases.requestAppointment(
        patient: patient,
        service: catalog.serviceById(serviceId),
        channel: channel,
        reason: _reason.text.trim(),
        preferredDate: _date,
      );
      messenger.showSnackBar(SnackBar(content: Text('Solicitud ${c.id} enviada. Admisión la revisará pronto.')));
      // Reemplaza el asistente: al volver desde el detalle no se regresa al formulario ya enviado.
      context.pushReplacement(AppRoutes.caseDetail(c.id));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _firstDate,
      lastDate: DateUtils.addDaysToDate(_firstDate, 60),
      helpText: 'Fecha preferida',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogRepository>();
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar cita')),
      // Arriba y no al centro: el Stepper vertical se ajusta a su contenido y quedaría a media pantalla.
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Stepper(
            type: wide ? StepperType.horizontal : StepperType.vertical,
            currentStep: _step,
            onStepContinue: _continue,
            onStepCancel: _step == 0 ? null : () => setState(() => _step--),
            onStepTapped: (index) {
              // Solo se vuelve a pasos ya hechos; para avanzar hay que validar con "Continuar".
              if (index < _step) setState(() => _step = index);
            },
            controlsBuilder: _controls,
            steps: [
              Step(
                title: const Text('Servicio'),
                isActive: _step >= 0,
                state: _step > 0 ? StepState.complete : StepState.indexed,
                content: Form(key: _formKeys[0], child: _serviceStep(catalog)),
              ),
              Step(
                title: const Text('Canal y motivo'),
                isActive: _step >= 1,
                state: _step > 1 ? StepState.complete : StepState.indexed,
                content: Form(key: _formKeys[1], child: _channelStep()),
              ),
              Step(
                title: const Text('Fecha'),
                isActive: _step >= 2,
                content: Form(key: _formKeys[2], child: _dateStep(catalog)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, ControlsDetails details) {
    final last = details.stepIndex == _lastStep;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: details.onStepContinue,
            icon: Icon(last ? Icons.send : Icons.arrow_forward),
            label: Text(last ? 'Enviar solicitud' : 'Continuar'),
          ),
          const SizedBox(width: 12),
          if (details.onStepCancel != null) TextButton(onPressed: details.onStepCancel, child: const Text('Atrás')),
        ],
      ),
    );
  }

  Widget _serviceStep(CatalogRepository catalog) {
    final theme = Theme.of(context);
    final serviceId = _serviceId;
    final selected = serviceId == null ? null : catalog.serviceById(serviceId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Qué servicio necesitas?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        // Una lista desplegable mantiene el paso compacto aunque haya 13 servicios.
        DropdownButtonFormField<String>(
          value: _serviceId,
          isExpanded: true,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Servicio', border: OutlineInputBorder()),
          items: [
            for (final s in catalog.services)
              if (s.requestable)
                DropdownMenuItem(
                  value: s.id,
                  child: Row(
                    children: [
                      Icon(AppIcons.service(s.iconKey), size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
          ],
          onChanged: (value) => setState(() => _serviceId = value),
          validator: (value) => value == null ? 'Elige un servicio.' : null,
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(AppIcons.service(selected.iconKey), color: AppColors.primary),
              title: Text(selected.name),
              subtitle: Text(
                '${selected.specialty?.label ?? ''} · ${Formatters.money(selected.fee ?? 0)}\n${selected.description}',
              ),
              isThreeLine: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _channelStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Por qué canal nos contactas?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        FormField<RequestChannel>(
          validator: (_) => _channel == null ? 'Elige un canal.' : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final channel in RequestChannel.values)
                    ChoiceChip(
                      avatar: Icon(AppIcons.channel(channel), size: 18),
                      label: Text(channel.label),
                      selected: _channel == channel,
                      onSelected: (_) {
                        setState(() => _channel = channel);
                        if (field.hasError) field.validate();
                      },
                    ),
                ],
              ),
              if (field.hasError) ...[
                const SizedBox(height: 6),
                Text(field.errorText!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _reason,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Motivo de consulta',
            hintText: 'Describe tus síntomas o lo que necesitas',
            border: OutlineInputBorder(),
          ),
          validator: (value) =>
              (value ?? '').trim().length < 10 ? 'Describe el motivo de consulta con al menos 10 caracteres.' : null,
        ),
      ],
    );
  }

  Widget _dateStep(CatalogRepository catalog) {
    final theme = Theme.of(context);
    final patient = context.read<SessionProvider>().currentPatient;
    final serviceId = _serviceId;
    final service = serviceId == null ? null : catalog.serviceById(serviceId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Qué día prefieres?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.event),
            title: Text(Formatters.date(_date)),
            subtitle: const Text('Admisión confirmará la hora según la agenda del médico.'),
            trailing: TextButton(onPressed: _pickDate, child: const Text('Cambiar')),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Resumen',
          icon: Icons.fact_check_outlined,
          child: Column(
            children: [
              _SummaryRow('Servicio', service?.name ?? '-'),
              _SummaryRow('Tarifa', Formatters.money(service?.fee ?? 0)),
              _SummaryRow('Canal', _channel?.label ?? '-'),
              _SummaryRow('Motivo', _reason.text.trim()),
              if (patient != null && service != null) _SummaryRow('Cobertura', _coverage(catalog, patient, service)),
            ],
          ),
        ),
      ],
    );
  }

  /// Cobertura estimada del plan del paciente (Admisión la confirma al validar con el seguro).
  String _coverage(CatalogRepository catalog, Patient patient, MedicalService service) {
    final affiliation = patient.affiliation;
    if (!affiliation.active) return 'Afiliación inactiva: Admisión revisará tu caso';
    final insurer = catalog.insurerById(affiliation.insurerId);
    return '${insurer.coverageFor(affiliation.plan, service)}% con ${insurer.name} (plan ${affiliation.plan}), '
        'sujeto a validación';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: muted)),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
```

En `saludconecta/lib/core/router/app_router.dart`, cambiar el import:

```dart
import '../../features/patient/patient_home_screen.dart';
```

por:

```dart
import '../../features/patient/patient_home_screen.dart';
import '../../features/patient/request/request_appointment_screen.dart';
```

y la ruta del asistente:

```dart
        GoRoute(
          path: AppRoutes.requestAppointmentPath,
          builder: (context, state) => const ComingSoonScreen(title: 'Solicitar cita', stage: 5),
        ),
```

por:

```dart
        GoRoute(
          path: AppRoutes.requestAppointmentPath,
          // `?servicio=` y `?fecha=` llegan desde Servicios y desde los resultados (cita de seguimiento).
          builder: (context, state) => RequestAppointmentScreen(
            initialServiceId: state.uri.queryParameters['servicio'],
            initialDate: DateTime.tryParse(state.uri.queryParameters['fecha'] ?? ''),
          ),
        ),
```

- [ ] **Step 4: Ejecutar las pruebas y verificar que pasan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/core/router test/features/patient/request_appointment_test.dart
```

Expected: `All tests passed!` (las 5 de `route_guard_test`, 1 de `app_routes_test` y 3 del asistente).

---

### Task 2: Inicio con avisos, citas en curso, accesos rápidos y consejos

**Files:**
- Create: `saludconecta/lib/features/patient/patient_notifications.dart`, `saludconecta/lib/features/patient/home/notification_bell.dart`, `saludconecta/lib/features/patient/home/active_case_card.dart`, `saludconecta/lib/features/patient/home/health_tips_carousel.dart`
- Modify: `saludconecta/lib/features/patient/patient_home_screen.dart` (archivo completo)
- Test: `saludconecta/test/features/patient/patient_notifications_test.dart`, `saludconecta/test/features/patient/patient_home_test.dart`

**Interfaces:**
- Consumes: `NotificationBuilder` y `PatientNotification` (etapa 2), `SessionProvider.notificationsSeenAt` y `markNotificationsSeen` (etapa 4), `nextActionFor` y `waitingText` (etapa 4), `patientDependencies` (tarea 1).
- Produces:
  - `PatientNotifications.build(Iterable<TelemedicineCase>, CatalogRepository) → List<PatientNotification>` y `PatientNotifications.unreadCount(items, DateTime? seenAt) → int`.
  - `NotificationBell({required Patient patient})`: tooltip "Avisos"; marca los avisos como leídos al cerrar la hoja.
  - `ActiveCaseCard({required TelemedicineCase telemedicineCase, NextAction? action})`.
  - `HealthTipsCarousel()` y la lista `healthTips` (5 `HealthTip`).

- [ ] **Step 1: Escribir las pruebas**

Create `saludconecta/test/features/patient/patient_notifications_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/services/notification_builder.dart';
import 'package:saludconecta/features/patient/patient_notifications.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('cuenta como no leídos los avisos posteriores a la última lectura', () {
    final at = DateTime(2026, 11, 9, 10);
    final items = [
      PatientNotification(caseId: 'TM-1', at: at.add(const Duration(hours: 2)), title: 'Cita agendada', body: ''),
      PatientNotification(caseId: 'TM-1', at: at, title: 'Recibimos tu solicitud', body: ''),
    ];
    expect(PatientNotifications.unreadCount(items, null), 2);
    expect(PatientNotifications.unreadCount(items, at), 1);
    expect(PatientNotifications.unreadCount(items, at.add(const Duration(hours: 2))), 0);
  });

  test('arma los avisos de los casos del paciente con el nombre del médico', () {
    final deps = testDependencies();
    final items = PatientNotifications.build(deps.cases.casesOfPatient(SeedIds.ramon), deps.catalog);
    expect(
      items.where((n) => n.title == 'Cita agendada' && n.body.contains('Dra. Laura Jiménez')),
      isNotEmpty,
    );
  });
}
```

Create `saludconecta/test/features/patient/patient_home_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('José ve sus citas en curso con lo que le toca hacer', (tester) async {
    await tester.pumpWidget(appWith(patientDependencies(SeedIds.jose)));
    await tester.pumpAndSettle();
    expect(find.text('Hola, José'), findsOneWidget);
    expect(find.text('Tus citas en curso'), findsOneWidget);
    expect(find.text('Responder la encuesta'), findsOneWidget);
    expect(find.text('Firmar consentimiento'), findsOneWidget);
  });

  testWidgets('María, sin citas en curso, ve los accesos rápidos y los consejos de salud', (tester) async {
    await tester.pumpWidget(appWith(patientDependencies(SeedIds.maria)));
    await tester.pumpAndSettle();
    expect(find.text('No tienes citas en curso'), findsOneWidget);
    expect(find.text('Mis resultados'), findsOneWidget);
    expect(find.text('Acerca del proceso'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Toma agua durante el día'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Educación en salud'), findsOneWidget);
  });

  testWidgets('"Mis resultados" avisa cuando todavía no hay resultados', (tester) async {
    await tester.pumpWidget(appWith(patientDependencies(SeedIds.pedro)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis resultados'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes resultados'), findsOneWidget);
  });

  testWidgets('la campana cuenta los avisos nuevos y los marca como leídos al cerrar', (tester) async {
    var now = testNow;
    final deps = AppDependencies.create(
      clock: () => now,
      insuranceDelay: Duration.zero,
      confirmationDelay: Duration.zero,
      initialLocation: AppRoutes.patientHome,
    );
    final maria = deps.catalog.patientById(SeedIds.maria);
    deps.session.loginPatient(maria);
    final c = deps.cases.requestAppointment(
      patient: maria,
      service: deps.catalog.serviceById(SeedIds.generalConsult),
      channel: RequestChannel.whatsapp,
      reason: 'Dolor de cabeza desde hace días',
      preferredDate: testNow.add(const Duration(days: 1)),
    );
    // Una hora después, Admisión registra la solicitud: eso genera un aviso nuevo.
    now = testNow.add(const Duration(hours: 1));
    deps.cases.registerReception(c.id, staff: deps.catalog.staffFor(Actor.admission));
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();

    final unread = find.descendant(of: find.byType(Badge), matching: find.text('1'));
    expect(unread, findsOneWidget);
    await tester.tap(find.byTooltip('Avisos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Admisión registró tu caso ${c.id}'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(unread, findsNothing);
  });
}
```

- [ ] **Step 2: Ejecutar las pruebas y verificar que fallan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/patient/patient_notifications_test.dart test/features/patient/patient_home_test.dart
```

Expected: FAIL. `patient_notifications.dart` no existe.

- [ ] **Step 3: Crear los avisos, las tarjetas y el Inicio**

Create `saludconecta/lib/features/patient/patient_notifications.dart`:

```dart
import '../../core/utils/formatters.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/services/notification_builder.dart';

/// Avisos del paciente (campana del Inicio) y cuántos no ha leído.
class PatientNotifications {
  const PatientNotifications._();

  /// Avisos de los casos del paciente, del más reciente al más antiguo.
  static List<PatientNotification> build(Iterable<TelemedicineCase> cases, CatalogRepository catalog) {
    final builder = NotificationBuilder(
      formatDateTime: Formatters.dateTime,
      doctorName: (doctorId) => catalog.doctorById(doctorId).displayName,
    );
    return builder.forPatient(cases);
  }

  /// Avisos posteriores a la última vez que el paciente abrió la campana ([seenAt]).
  static int unreadCount(List<PatientNotification> items, DateTime? seenAt) {
    if (seenAt == null) return items.length;
    return items.where((n) => n.at.isAfter(seenAt)).length;
  }
}
```

Create `saludconecta/lib/features/patient/home/notification_bell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/people.dart';
import '../../../domain/services/notification_builder.dart';
import '../../../state/case_provider.dart';
import '../../../state/session_provider.dart';
import '../patient_notifications.dart';

/// Campana del Inicio: cuenta los avisos que el paciente no ha leído y los abre en una hoja.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>().casesOfPatient(patient.id);
    final seenAt = context.watch<SessionProvider>().notificationsSeenAt(patient.id);
    final items = PatientNotifications.build(cases, context.read<CatalogRepository>());
    final unread = PatientNotifications.unreadCount(items, seenAt);
    return IconButton(
      tooltip: 'Avisos',
      onPressed: () => _open(context, items, seenAt),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }

  Future<void> _open(BuildContext context, List<PatientNotification> items, DateTime? seenAt) async {
    // Se capturan antes del await: después no se usa `context`.
    final session = context.read<SessionProvider>();
    final router = GoRouter.of(context);
    final caseId = await showModalBottomSheet<String>(
      context: context,
      // Sobre toda la app, no solo sobre la pestaña (cada pestaña del shell tiene su propio Navigator).
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _NotificationsSheet(items: items, seenAt: seenAt),
    );
    // Al cerrar la hoja, los avisos quedan leídos; si eligió uno, se abre su caso.
    session.markNotificationsSeen();
    if (caseId != null) router.push(AppRoutes.caseDetail(caseId));
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({required this.items, required this.seenAt});

  final List<PatientNotification> items;
  final DateTime? seenAt;

  bool _isNew(PatientNotification n) {
    final seen = seenAt;
    return seen == null || n.at.isAfter(seen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(title: Text('Avisos', style: theme.textTheme.titleLarge)),
          if (items.isEmpty)
            const ListTile(title: Text('Aún no tienes avisos.'))
          else
            for (final n in items)
              ListTile(
                leading: Icon(
                  _isNew(n) ? Icons.mark_email_unread_outlined : Icons.notifications_none,
                  color: _isNew(n) ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(n.title),
                subtitle: Text('${n.body}\n${Formatters.dateTime(n.at)}'),
                isThreeLine: true,
                onTap: () => Navigator.pop(context, n.caseId),
              ),
        ],
      ),
    );
  }
}
```

Create `saludconecta/lib/features/patient/home/active_case_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/case_records.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../shared/case_detail/next_action.dart';

/// Tarjeta de un caso en curso: avance "Paso X de 10", la cita y el botón de lo que le toca al paciente.
class ActiveCaseCard extends StatelessWidget {
  const ActiveCaseCard({super.key, required this.telemedicineCase, this.action});

  final TelemedicineCase telemedicineCase;

  /// Lo que puede hacer ahora el paciente; `null` si le toca a otro actor.
  final NextAction? action;

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final service = catalog.serviceById(c.serviceId);
    final appointment = c.appointment;
    final step = c.currentStep;
    final next = action;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
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
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: Icon(AppIcons.service(service.iconKey), color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(c.id, style: muted),
                      ],
                    ),
                  ),
                  StatusChip(status: c.status),
                ],
              ),
              const SizedBox(height: 14),
              Text('Paso ${step.number} de 10: ${step.title}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: c.completedSteps.length / 10,
                  minHeight: 8,
                  color: AppColors.forActor(step.actor),
                  backgroundColor: theme.colorScheme.surfaceVariant,
                ),
              ),
              if (appointment != null) ...[
                const SizedBox(height: 10),
                Text(_appointmentText(catalog, appointment), style: muted),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (next != null)
                    FilledButton.icon(
                      onPressed: () => context.push(next.route),
                      icon: Icon(next.icon),
                      label: Text(next.label),
                    )
                  else
                    Text(waitingText(c), style: muted),
                  if (c.results != null)
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.caseAction(c.id, CaseAction.results)),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Ver mis resultados'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _appointmentText(CatalogRepository catalog, Appointment appointment) =>
      '${Formatters.dateTime(appointment.dateTime)} · ${catalog.doctorById(appointment.doctorId).displayName}';
}
```

Create `saludconecta/lib/features/patient/home/health_tips_carousel.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Un consejo de "Educación en salud" (servicio incluido en la app).
class HealthTip {
  const HealthTip(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

/// Los 5 consejos del carrusel del Inicio.
const healthTips = [
  HealthTip(
    Icons.water_drop_outlined,
    'Toma agua durante el día',
    'Unos 8 vasos al día ayudan a tu energía, a tu piel y a tus riñones.',
  ),
  HealthTip(
    Icons.directions_walk,
    'Muévete 30 minutos al día',
    'Caminar a paso rápido cinco días a la semana cuida tu corazón.',
  ),
  HealthTip(
    Icons.bedtime_outlined,
    'Duerme de 7 a 8 horas',
    'El buen descanso mejora tu ánimo, tu memoria y tus defensas.',
  ),
  HealthTip(
    Icons.restaurant_outlined,
    'Llena medio plato de vegetales',
    'Las frutas y los vegetales de colores aportan fibra y vitaminas.',
  ),
  HealthTip(
    Icons.medication_outlined,
    'Toma tus medicamentos a tiempo',
    'Usa alarmas y no suspendas un tratamiento sin consultar a tu médico.',
  ),
];

/// Carrusel "Educación en salud": los consejos en un `PageView` con indicador de puntos.
class HealthTipsCarousel extends StatefulWidget {
  const HealthTipsCarousel({super.key});

  @override
  State<HealthTipsCarousel> createState() => _HealthTipsCarouselState();
}

class _HealthTipsCarouselState extends State<HealthTipsCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _controller,
            itemCount: healthTips.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final tip = healthTips[index];
              return Card(
                color: AppColors.secondary.withOpacity(0.08),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.secondary,
                        child: Icon(tip.icon, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tip.title,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tip.body,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < healthTips.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.secondary : theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
```

Replace the whole content of `saludconecta/lib/features/patient/patient_home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_body.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';
import '../shared/case_detail/next_action.dart';
import 'home/active_case_card.dart';
import 'home/health_tips_carousel.dart';
import 'home/notification_bell.dart';

/// Inicio del paciente (§6): saludo con avisos, citas en curso, accesos rápidos y consejos de salud.
class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<SessionProvider>().currentPatient;
    if (patient == null) return const SizedBox.shrink();
    final mine = context.watch<CaseProvider>().casesOfPatient(patient.id);
    NextAction? actionOf(TelemedicineCase c) => nextActionFor(c, UserRole.patient, patientId: patient.id);
    int priority(TelemedicineCase c) => actionOf(c) == null ? 1 : 0;
    final open = [
      for (final c in mine)
        if (c.isOpen) c,
    ];
    // Primero los casos en los que le toca actuar al paciente; después, el movimiento más reciente.
    open.sort((a, b) {
      final byAction = priority(a).compareTo(priority(b));
      return byAction != 0 ? byAction : b.updatedAt.compareTo(a.updatedAt);
    });
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Row(
            children: [
              AvatarImage(name: patient.fullName, asset: patient.avatarAsset, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hola, ${patient.firstName}', style: theme.textTheme.headlineSmall),
                    Text('Carnet ${patient.affiliation.affiliateNumber}', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              NotificationBell(patient: patient),
            ],
          ),
          const SizedBox(height: 20),
          Text(open.isEmpty ? 'Tus citas' : 'Tus citas en curso', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (open.isEmpty)
            const _NoActiveCase()
          else
            for (final c in open)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ActiveCaseCard(telemedicineCase: c, action: actionOf(c)),
              ),
          const SizedBox(height: 16),
          Text('Accesos rápidos', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          _QuickActions(patientCases: mine),
          const SizedBox(height: 20),
          Text('Educación en salud', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const HealthTipsCarousel(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Aviso cuando el paciente no tiene citas en curso.
class _NoActiveCase extends StatelessWidget {
  const _NoActiveCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const AppIllustration(AppIllustrations.emptyCases, width: 80, height: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No tienes citas en curso', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('Pide una consulta virtual cuando la necesites.', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un acceso rápido del Inicio.
class _QuickAction {
  const _QuickAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Accesos rápidos: Solicitar cita, Mis resultados, Servicios y Acerca del proceso.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.patientCases});

  /// Casos del paciente, del más reciente al más antiguo.
  final List<TelemedicineCase> patientCases;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(Icons.edit_calendar, 'Solicitar cita', () => context.push(AppRoutes.requestAppointment())),
      _QuickAction(Icons.receipt_long, 'Mis resultados', () => _openLatestResults(context)),
      _QuickAction(Icons.medical_services_outlined, 'Servicios', () => context.go(AppRoutes.patientServices)),
      _QuickAction(Icons.account_tree_outlined, 'Acerca del proceso', () => context.push(AppRoutes.process)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth >= 560 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [for (final action in actions) _QuickActionTile(action: action)],
        );
      },
    );
  }

  /// Abre los resultados del caso más reciente que los tenga, o avisa que todavía no hay.
  void _openLatestResults(BuildContext context) {
    final withResults = patientCases.where((c) => c.results != null);
    if (withResults.isNotEmpty) {
      context.push(AppRoutes.caseAction(withResults.first.id, CaseAction.results));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => const EmptyState(
        illustration: AppIllustrations.emptyResults,
        title: 'Aún no tienes resultados',
        message: 'Aquí verás tu receta, tus órdenes y tus indicaciones cuando tu médico las emita.',
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Icon(action.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Ejecutar las pruebas y verificar que pasan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/patient test/features/login_flow_test.dart test/features/role_switcher_test.dart
```

Expected: `All tests passed!` (las 9 del paciente de las tareas 1 y 2, y las 4 de ingreso y cambio de rol, que siguen viendo "Hola, María").

---

### Task 3: Mis citas, Servicios y Perfil

**Files:**
- Create: `saludconecta/lib/features/patient/appointments_screen.dart`, `saludconecta/lib/features/patient/services_screen.dart`, `saludconecta/lib/features/patient/profile/insurance_card.dart`, `saludconecta/lib/features/patient/profile/profile_screen.dart`
- Modify: `saludconecta/lib/core/router/app_router.dart` (edición)
- Test: `saludconecta/test/features/patient/patient_tabs_test.dart`

**Interfaces:**
- Consumes: `CaseCard`, `EmptyState`, `SectionCard`, `PageBody`, `RoleSwitcherSheet` (etapa 4); `AppRoutes.requestAppointment(serviceId:)` (tarea 1).
- Produces: `AppointmentsScreen()`, `ServicesScreen()`, `ProfileScreen()` e `InsuranceCard({required Patient patient, required Insurer insurer})`.

- [ ] **Step 1: Escribir la prueba**

Create `saludconecta/test/features/patient/patient_tabs_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/core/widgets/case_card.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Future<AppDependencies> openTab(WidgetTester tester, String patientId, String route) async {
    final deps = patientDependencies(patientId);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(route);
    await tester.pumpAndSettle();
    return deps;
  }

  testWidgets('Mis citas separa las activas del historial', (tester) async {
    await openTab(tester, SeedIds.maria, AppRoutes.patientAppointments);
    expect(find.text('Activas (0)'), findsOneWidget);
    expect(find.text('No tienes citas en curso'), findsOneWidget);

    await tester.tap(find.text('Historial (4)'));
    await tester.pumpAndSettle();
    expect(find.byType(CaseCard), findsNWidgets(4));
  });

  testWidgets('Servicios muestra los canales y los 3 grupos con sus chips', (tester) async {
    await openTab(tester, SeedIds.maria, AppRoutes.patientServices);
    expect(find.text('Canales disponibles'), findsOneWidget);
    expect(find.text('Videoconferencia'), findsOneWidget);
    expect(find.text('Servicios clínicos'), findsOneWidget);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Encuesta de satisfacción'), 300, scrollable: list);
    expect(find.text('Incluido en el proceso'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Receta médica'), 300, scrollable: list);
    expect(find.text('Se genera en tu consulta'), findsWidgets);
  });

  testWidgets('"Solicitar" en un servicio abre el asistente con ese servicio', (tester) async {
    await openTab(tester, SeedIds.maria, AppRoutes.patientServices);
    await tester.tap(find.text('Solicitar').first);
    await tester.pumpAndSettle();
    expect(find.text('¿Por qué canal nos contactas?'), findsOneWidget);
  });

  testWidgets('Perfil muestra el carnet y cierra la sesión', (tester) async {
    final deps = await openTab(tester, SeedIds.maria, AppRoutes.patientProfile);
    expect(find.text('ARS Salud Plena'), findsOneWidget);
    expect(find.text('Plan Plus'), findsOneWidget);
    expect(find.text('SP-100245'), findsOneWidget);
    expect(find.text('Activa'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Cerrar sesión'), 200, scrollable: find.byType(Scrollable).first);
    // Un cuadro más para que `tap` use la posición nueva, ya desplazada.
    await tester.pump();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(deps.session.isLoggedIn, isFalse);
    expect(find.text('¿Quién usa la app?'), findsOneWidget);
  });

  testWidgets('el carnet de Pedro muestra la afiliación inactiva', (tester) async {
    await openTab(tester, SeedIds.pedro, AppRoutes.patientProfile);
    expect(find.text('Inactiva'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/patient/patient_tabs_test.dart
```

Expected: FAIL. Las pestañas todavía muestran `ComingSoonScreen`.

- [ ] **Step 3: Crear las tres pestañas**

Create `saludconecta/lib/features/patient/appointments_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/case_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_body.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';

/// "Mis citas": pestañas Activas e Historial con los casos del paciente.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<SessionProvider>().currentPatient;
    if (patient == null) return const SizedBox.shrink();
    final mine = context.watch<CaseProvider>().casesOfPatient(patient.id);
    final active = [
      for (final c in mine)
        if (c.isOpen) c,
    ];
    final history = [
      for (final c in mine)
        if (!c.isOpen) c,
    ];
    return DefaultTabController(
      length: 2,
      child: PageBody(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mis citas', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            TabBar(
              tabs: [
                Tab(text: 'Activas (${active.length})'),
                Tab(text: 'Historial (${history.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _CaseList(
                    cases: active,
                    empty: EmptyState(
                      illustration: AppIllustrations.emptyCases,
                      title: 'No tienes citas en curso',
                      message: 'Cuando solicites una cita, aquí verás cómo avanza.',
                      action: FilledButton.icon(
                        onPressed: () => context.push(AppRoutes.requestAppointment()),
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text('Solicitar cita'),
                      ),
                    ),
                  ),
                  _CaseList(
                    cases: history,
                    empty: const EmptyState(
                      illustration: AppIllustrations.emptyResults,
                      title: 'Aún no tienes historial',
                      message: 'Aquí quedarán tus citas completadas y canceladas.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseList extends StatelessWidget {
  const _CaseList({required this.cases, required this.empty});

  final List<TelemedicineCase> cases;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) return empty;
    final dateStyle = Theme.of(context).textTheme.bodySmall;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: cases.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = cases[index];
        return CaseCard(
          telemedicineCase: c,
          showPatient: false,
          onTap: () => context.push(AppRoutes.caseDetail(c.id)),
          trailing: Text(Formatters.shortDate(c.updatedAt), style: dateStyle),
        );
      },
    );
  }
}
```

Create `saludconecta/lib/features/patient/services_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/catalog.dart';
import '../../domain/models/enums.dart';
import '../../domain/process/process_step.dart';

/// "Servicios": los 24 servicios de la infografía 2 en sus 3 grupos, y los canales de atención.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  /// Canales de la infografía de servicios.
  static const _channels = [
    (Icons.smartphone, 'Celular'),
    (Icons.email_outlined, 'Correo'),
    (Icons.chat_outlined, 'WhatsApp'),
    (Icons.language, 'Portal web'),
    (Icons.videocam_outlined, 'Videoconferencia'),
  ];

  @override
  Widget build(BuildContext context) {
    final services = context.read<CatalogRepository>().services;
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Servicios', style: theme.textTheme.headlineSmall),
          Text('${services.length} servicios de telemedicina en 3 grupos', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Canales disponibles', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (icon, label) in _channels) Chip(avatar: Icon(icon, size: 18), label: Text(label)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          for (final group in ServiceGroup.values) ...[
            const SizedBox(height: 16),
            Text(group.label, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final service in services)
              if (service.group == group) _ServiceCard(service: service),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Un servicio con su ícono, su descripción y lo que el paciente puede hacer con él.
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final MedicalService service;

  @override
  Widget build(BuildContext context) {
    final s = service;
    final fee = s.fee;
    final theme = Theme.of(context);
    final Widget chip;
    if (s.requestable) {
      chip = ActionChip(
        avatar: const Icon(Icons.add, size: 18),
        label: const Text('Solicitar'),
        onPressed: () => context.push(AppRoutes.requestAppointment(serviceId: s.id)),
      );
    } else if (s.relatedStep == ProcessStep.consultationResult) {
      chip = const Chip(avatar: Icon(Icons.receipt_long, size: 18), label: Text('Se genera en tu consulta'));
    } else {
      chip = const Chip(avatar: Icon(Icons.check_circle_outline, size: 18), label: Text('Incluido en el proceso'));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(AppIcons.service(s.iconKey), color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(s.description, style: theme.textTheme.bodyMedium),
                  if (fee != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${s.specialty?.label ?? ''} · ${Formatters.money(fee)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 8),
                  chip,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/features/patient/profile/insurance_card.dart`:

```dart
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
```

Create `saludconecta/lib/features/patient/profile/profile_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/role_switcher_sheet.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../state/case_provider.dart';
import '../../../state/session_provider.dart';
import 'insurance_card.dart';

/// "Perfil": carnet del seguro, datos personales y enlaces (Acerca de, Cambiar de rol, Cerrar sesión).
/// La etapa 9 agrega "Mi resumen" con sus gráficas.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final patient = session.currentPatient;
    if (patient == null) return const SizedBox.shrink();
    final insurer = context.read<CatalogRepository>().insurerById(patient.affiliation.insurerId);
    final age = patient.ageOn(context.read<CaseProvider>().now);
    final birth = '${Formatters.shortDate(patient.birthDate)} ($age años)';
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Mi perfil', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: InsuranceCard(patient: patient, insurer: insurer)),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Datos personales',
            icon: Icons.badge_outlined,
            child: Column(
              children: [
                _DataRow(Icons.person_outline, 'Nombre', patient.fullName),
                _DataRow(Icons.credit_card, 'Cédula', patient.cedula),
                _DataRow(Icons.cake_outlined, 'Nacimiento', birth),
                _DataRow(Icons.wc, 'Sexo', patient.gender.label),
                _DataRow(Icons.phone_outlined, 'Teléfono', patient.phone),
                _DataRow(Icons.email_outlined, 'Correo', patient.email),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Acerca de SaludConecta'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.about),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.switch_account_outlined),
                  title: const Text('Cambiar de rol'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => RoleSwitcherSheet.show(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger),
                  title: const Text('Cerrar sesión', style: TextStyle(color: AppColors.danger)),
                  onTap: () {
                    session.logout();
                    context.go(AppRoutes.login);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: Text(label, style: theme.textTheme.bodyMedium)),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
```

En `saludconecta/lib/core/router/app_router.dart`, cambiar los imports:

```dart
import '../../features/patient/patient_home_screen.dart';
import '../../features/patient/request/request_appointment_screen.dart';
```

por:

```dart
import '../../features/patient/appointments_screen.dart';
import '../../features/patient/patient_home_screen.dart';
import '../../features/patient/profile/profile_screen.dart';
import '../../features/patient/request/request_appointment_screen.dart';
import '../../features/patient/services_screen.dart';
```

y las tres pestañas:

```dart
          _Tab(AppRoutes.patientAppointments, 'Mis citas', Icons.event_note_outlined, Icons.event_note,
              (context, state) => const ComingSoonScreen(title: 'Mis citas', stage: 5, inShell: true)),
          _Tab(AppRoutes.patientServices, 'Servicios', Icons.medical_services_outlined, Icons.medical_services,
              (context, state) => const ComingSoonScreen(title: 'Servicios', stage: 5, inShell: true)),
          _Tab(AppRoutes.patientProfile, 'Perfil', Icons.person_outline, Icons.person,
              (context, state) => const ComingSoonScreen(title: 'Perfil', stage: 5, inShell: true)),
```

por:

```dart
          _Tab(AppRoutes.patientAppointments, 'Mis citas', Icons.event_note_outlined, Icons.event_note,
              (context, state) => const AppointmentsScreen()),
          _Tab(AppRoutes.patientServices, 'Servicios', Icons.medical_services_outlined, Icons.medical_services,
              (context, state) => const ServicesScreen()),
          _Tab(AppRoutes.patientProfile, 'Perfil', Icons.person_outline, Icons.person,
              (context, state) => const ProfileScreen()),
```

En `saludconecta/lib/core/widgets/role_switcher_sheet.dart`, cambiar:

```dart
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
```

por:

```dart
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        // Desde Perfil se abre dentro de una pestaña: con el Navigator raíz cubre toda la app.
        useRootNavigator: true,
        showDragHandle: true,
```

- [ ] **Step 4: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/patient/patient_tabs_test.dart test/features/role_switcher_test.dart
```

Expected: `All tests passed!` (5 pruebas de las pestañas y la del cambio de rol).

---

### Task 4: Consentimiento con firma

**Files:**
- Create: `saludconecta/lib/features/patient/patient_case_builder.dart`, `saludconecta/lib/features/patient/consent/signature_pad.dart`, `saludconecta/lib/features/patient/consent/consent_screen.dart`
- Modify: `saludconecta/lib/core/router/app_router.dart` (edición)
- Test: `saludconecta/test/features/patient/signature_pad_test.dart`, `saludconecta/test/features/patient/consent_test.dart`

**Interfaces:**
- Consumes: `CaseProvider.signConsent(id, {patient, acceptedTerms, acceptedDataUse, identityConfirmed, signature})`, `SignaturePoint` (etapa 2), `NotFoundScreen` y `EmptyState` (etapa 4).
- Produces:
  - `PatientCaseBuilder({required String caseId, required Widget Function(BuildContext, TelemedicineCase, Patient) builder})`.
  - `CaseNotice({required String screenTitle, required String title, required String message, String illustration, Widget? action})`.
  - `SignatureController` (`strokes`, `hasSignature`, `begin(Offset, Size)`, `extend(Offset, Size)`, `clear()`), `SignaturePad({required SignatureController controller, double height})` y `SignaturePainter`.
  - `ConsentScreen({required String caseId})`; en el router, `_caseAction(CaseAction, String caseId)` reemplaza a `_pendingAction`.

- [ ] **Step 1: Escribir las pruebas**

Create `saludconecta/test/features/patient/signature_pad_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/features/patient/consent/signature_pad.dart';

void main() {
  test('guarda los puntos normalizados al tamaño del lienzo y exige dos puntos', () {
    final controller = SignatureController();
    const size = Size(200, 100);
    controller.begin(const Offset(50, 25), size);
    expect(controller.hasSignature, isFalse);

    controller.extend(const Offset(250, 120), size);
    expect(controller.hasSignature, isTrue);
    final stroke = controller.strokes.single;
    expect(stroke.first.x, 0.25);
    expect(stroke.first.y, 0.25);
    // Lo que sale del recuadro se recorta al borde.
    expect(stroke.last.x, 1.0);
    expect(stroke.last.y, 1.0);

    controller.clear();
    expect(controller.strokes, isEmpty);
  });

  testWidgets('dibujar sobre el recuadro crea un trazo', (tester) async {
    final controller = SignatureController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: SignaturePad(controller: controller)),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SignaturePad)));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(12, 4));
    }
    await gesture.up();
    await tester.pump();
    expect(controller.hasSignature, isTrue);
    expect(controller.strokes.single.length, greaterThan(2));
  });
}
```

Create `saludconecta/test/features/patient/consent_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/features/patient/consent/signature_pad.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  /// Marca la casilla con ese texto (desplaza la lista hasta verla).
  Future<void> check(WidgetTester tester, String label) async {
    final box = find.text(label);
    await tester.scrollUntilVisible(box, 100, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(box);
    await tester.pump();
  }

  testWidgets('José firma el consentimiento y pasa a la sala de espera', (tester) async {
    final deps = patientDependencies(SeedIds.jose);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.consentAdmission);
    final jose = deps.catalog.patientById(SeedIds.jose);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.consent));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Firmar y continuar'));
    await tester.pump();
    expect(find.text('Marca las tres casillas del consentimiento.'), findsOneWidget);

    await check(tester, 'He leído y acepto el consentimiento informado');
    await check(tester, 'Autorizo el uso de mis datos de salud para esta atención');
    await check(tester, 'Confirmo mi identidad: ${jose.fullName}, cédula ${jose.cedula}');
    await tester.tap(find.text('Firmar y continuar'));
    await tester.pump();
    expect(find.text('La firma es obligatoria.'), findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(SignaturePad)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(15, 4));
    }
    await gesture.up();
    await tester.tap(find.text('Firmar y continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(deps.cases.caseById(c.id)!.currentStep, ProcessStep.consultation);
    expect(find.text('Sala de espera'), findsWidgets);
  });

  testWidgets('otro paciente no puede abrir el consentimiento de José', (tester) async {
    final deps = patientDependencies(SeedIds.carmen);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.consentAdmission);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.consent));
    await tester.pumpAndSettle();
    expect(find.text('Caso no encontrado'), findsWidgets);
  });
}
```

- [ ] **Step 2: Ejecutar las pruebas y verificar que fallan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/patient/signature_pad_test.dart test/features/patient/consent_test.dart
```

Expected: FAIL. `signature_pad.dart` no existe.

- [ ] **Step 3: Crear el acceso al caso, la firma y el consentimiento**

Create `saludconecta/lib/features/patient/patient_case_builder.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/models/people.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';
import '../shared/not_found_screen.dart';

/// Busca un caso del paciente en sesión y construye la pantalla con él.
/// Si el caso no existe o es de otro paciente, muestra "Caso no encontrado".
class PatientCaseBuilder extends StatelessWidget {
  const PatientCaseBuilder({super.key, required this.caseId, required this.builder});

  final String caseId;
  final Widget Function(BuildContext context, TelemedicineCase c, Patient patient) builder;

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<SessionProvider>().currentPatient;
    final c = context.watch<CaseProvider>().caseById(caseId);
    if (patient == null || c == null || c.patientId != patient.id) {
      return const NotFoundScreen(title: 'Caso no encontrado', message: 'El caso que buscas no existe.');
    }
    return builder(context, c, patient);
  }
}

/// Aviso cuando la acción no corresponde al paso del caso (p. ej., la encuesta ya se respondió).
class CaseNotice extends StatelessWidget {
  const CaseNotice({
    super.key,
    required this.screenTitle,
    required this.title,
    required this.message,
    this.illustration = AppIllustrations.emptyCases,
    this.action,
  });

  final String screenTitle;
  final String title;
  final String message;
  final String illustration;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),
      body: EmptyState(illustration: illustration, title: title, message: message, action: action),
    );
  }
}
```

Create `saludconecta/lib/features/patient/consent/signature_pad.dart`:

```dart
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/case_records.dart';

/// Trazos de la firma en coordenadas normalizadas (de 0 a 1), como los guarda `ConsentRecord`.
class SignatureController extends ChangeNotifier {
  final List<List<SignaturePoint>> _strokes = [];

  /// Copia de los trazos: cada trazo es una lista de puntos.
  List<List<SignaturePoint>> get strokes => [for (final stroke in _strokes) List.unmodifiable(stroke)];

  /// Hay firma si algún trazo tiene al menos dos puntos (la misma regla del dominio).
  bool get hasSignature => _strokes.any((stroke) => stroke.length >= 2);

  /// Empieza un trazo en [position], dentro de un lienzo de tamaño [size].
  void begin(Offset position, Size size) {
    _strokes.add([_normalize(position, size)]);
    notifyListeners();
  }

  /// Agrega [position] al trazo actual.
  void extend(Offset position, Size size) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(_normalize(position, size));
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  static SignaturePoint _normalize(Offset position, Size size) =>
      SignaturePoint(_unit(position.dx / size.width), _unit(position.dy / size.height));

  static double _unit(double value) => value < 0 ? 0.0 : (value > 1 ? 1.0 : value);
}

/// Recuadro para firmar con el dedo (o con el mouse en la web).
class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.controller, this.height = 160});

  final SignatureController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, height);
        return GestureDetector(
          // El trazo empieza donde se apoya el dedo, no cuando el gesto se reconoce.
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (details) => controller.begin(details.localPosition, size),
          onPanUpdate: (details) => controller.extend(details.localPosition, size),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.pending.withOpacity(0.6)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(size: size, painter: SignaturePainter(controller)),
            ),
          ),
        );
      },
    );
  }
}

/// Pinta la línea base y los trazos; se repinta cada vez que cambia el controlador.
class SignaturePainter extends CustomPainter {
  SignaturePainter(this.controller) : super(repaint: controller);

  final SignatureController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = AppColors.pending.withOpacity(0.5)
      ..strokeWidth = 1;
    final y = size.height * 0.78;
    canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), baseline);

    final ink = Paint()
      ..color = AppColors.navy
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in controller.strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.x * size.width, stroke.first.y * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.x * size.width, point.y * size.height);
      }
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => oldDelegate.controller != controller;
}
```

Create `saludconecta/lib/features/patient/consent/consent_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/people.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_exception.dart';
import '../../../domain/process/process_step.dart';
import '../../../state/case_provider.dart';
import '../patient_case_builder.dart';
import 'signature_pad.dart';

/// Texto del consentimiento informado (redactado para la demostración).
const consentText = 'Autorizo a SaludConecta y a su equipo de salud a atenderme por telemedicina: una consulta '
    'por videollamada en la que el médico evalúa mis síntomas, me orienta y puede emitir recetas, órdenes de '
    'estudios, indicaciones o un referimiento a consulta presencial.\n\n'
    'Entiendo que la telemedicina no sustituye la atención de emergencias y que, si el médico lo considera '
    'necesario, me indicará acudir a un centro de salud. La videollamada no se graba. Mis datos de salud son '
    'confidenciales y solo los usa el personal que participa en mi atención.\n\n'
    'Puedo retirar este consentimiento antes de la consulta cancelando la cita desde la app.\n\n'
    'Documento de demostración del proyecto académico SaludConecta (ISO910, UNAPEC).';

/// Paso 6: consentimiento informado y admisión virtual. Las tres casillas y la firma son obligatorias.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return PatientCaseBuilder(
      caseId: caseId,
      builder: (context, c, patient) {
        final consent = c.consent;
        if (consent != null) {
          final inWaitingRoom = c.status == CaseStatus.active && c.currentStep == ProcessStep.consultation;
          return CaseNotice(
            screenTitle: 'Consentimiento informado',
            title: 'Ya firmaste el consentimiento',
            message: 'Lo firmaste el ${Formatters.dateTime(consent.at)}.',
            action: inWaitingRoom
                ? FilledButton.icon(
                    onPressed: () => context.pushReplacement(AppRoutes.caseAction(c.id, CaseAction.waitingRoom)),
                    icon: const Icon(Icons.meeting_room),
                    label: const Text('Ir a la sala de espera'),
                  )
                : null,
          );
        }
        if (c.status != CaseStatus.active || c.currentStep != ProcessStep.consentAdmission) {
          return const CaseNotice(
            screenTitle: 'Consentimiento informado',
            title: 'Aún no puedes firmar',
            message: 'El consentimiento se firma después de que Admisión te confirme la cita.',
          );
        }
        return _ConsentForm(telemedicineCase: c, patient: patient);
      },
    );
  }
}

class _ConsentForm extends StatefulWidget {
  const _ConsentForm({required this.telemedicineCase, required this.patient});

  final TelemedicineCase telemedicineCase;
  final Patient patient;

  @override
  State<_ConsentForm> createState() => _ConsentFormState();
}

class _ConsentFormState extends State<_ConsentForm> {
  final _signature = SignatureController();
  bool _terms = false;
  bool _dataUse = false;
  bool _identity = false;

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  void _sign() {
    final c = widget.telemedicineCase;
    final cases = context.read<CaseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    // Un mensaje nuevo reemplaza al anterior en lugar de esperar su turno.
    messenger.removeCurrentSnackBar();
    try {
      cases.signConsent(
        c.id,
        patient: widget.patient,
        acceptedTerms: _terms,
        acceptedDataUse: _dataUse,
        identityConfirmed: _identity,
        signature: _signature.strokes,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Consentimiento firmado. Pasa a la sala de espera.')));
      context.pushReplacement(AppRoutes.caseAction(c.id, CaseAction.waitingRoom));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.telemedicineCase;
    final patient = widget.patient;
    final catalog = context.read<CatalogRepository>();
    final appointment = c.appointment;
    final doctor = appointment == null ? null : catalog.doctorById(appointment.doctorId);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Consentimiento informado')),
      body: PageBody(
        child: ListView(
          children: [
            if (appointment != null && doctor != null)
              Card(
                child: ListTile(
                  leading: AvatarImage(name: doctor.displayName, asset: doctor.avatarAsset, size: 44),
                  title: Text('${catalog.serviceById(c.serviceId).name} con ${doctor.displayName}'),
                  subtitle: Text('${Formatters.dateTime(appointment.dateTime)} · ${appointment.platform.label}'),
                ),
              ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Consentimiento informado para telemedicina',
              icon: Icons.description_outlined,
              child: Text(consentText, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _terms,
              onChanged: (value) => setState(() => _terms = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('He leído y acepto el consentimiento informado'),
            ),
            CheckboxListTile(
              value: _dataUse,
              onChanged: (value) => setState(() => _dataUse = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Autorizo el uso de mis datos de salud para esta atención'),
            ),
            CheckboxListTile(
              value: _identity,
              onChanged: (value) => setState(() => _identity = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('Confirmo mi identidad: ${patient.fullName}, cédula ${patient.cedula}'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      // La firma va fija abajo, fuera de la lista: así el gesto de firmar no desplaza la pantalla
      // y los avisos (`SnackBar`) aparecen encima, sin tapar el botón.
      bottomNavigationBar: Material(
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: PageBody.maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Tu firma', style: theme.textTheme.titleMedium),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _signature.clear,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Borrar'),
                        ),
                      ],
                    ),
                    SignaturePad(controller: _signature, height: 130),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _sign,
                      icon: const Icon(Icons.draw),
                      label: const Text('Firmar y continuar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

En `saludconecta/lib/core/router/app_router.dart`, cambiar los imports:

```dart
import '../../features/patient/appointments_screen.dart';
import '../../features/patient/patient_home_screen.dart';
```

por:

```dart
import '../../features/patient/appointments_screen.dart';
import '../../features/patient/consent/consent_screen.dart';
import '../../features/patient/patient_home_screen.dart';
```

las rutas de las acciones sobre un caso:

```dart
            for (final action in CaseAction.values)
              GoRoute(path: action.segment, builder: (context, state) => _pendingAction(action)),
```

por:

```dart
            for (final action in CaseAction.values)
              GoRoute(
                path: action.segment,
                builder: (context, state) => _caseAction(action, state.pathParameters['id']!),
              ),
```

y el comienzo de la función que elige la pantalla de cada acción:

```dart
  /// Pantalla provisional de cada acción sobre un caso, hasta la etapa que la construye.
  static Widget _pendingAction(CaseAction action) => switch (action) {
        CaseAction.consent => const ComingSoonScreen(title: 'Consentimiento informado', stage: 5),
```

por:

```dart
  /// Pantalla de cada acción sobre un caso; las que aún no se construyen apuntan a `ComingSoonScreen`.
  static Widget _caseAction(CaseAction action, String caseId) => switch (action) {
        CaseAction.consent => ConsentScreen(caseId: caseId),
```

- [ ] **Step 4: Ejecutar las pruebas y verificar que pasan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/patient/signature_pad_test.dart test/features/patient/consent_test.dart
```

Expected: `All tests passed!` (4 pruebas).

---

### Task 5: Sala de espera y videollamada

**Files:**
- Create: `saludconecta/lib/features/patient/waiting_room/connection_check.dart`, `saludconecta/lib/features/patient/waiting_room/waiting_room_screen.dart`, `saludconecta/lib/features/shared/video_call/video_call_view.dart`, `saludconecta/lib/features/patient/call/patient_video_call_screen.dart`
- Modify: `saludconecta/lib/core/router/app_router.dart` (edición)
- Test: `saludconecta/test/features/patient/waiting_room_and_call_test.dart`

**Interfaces:**
- Consumes: `PatientCaseBuilder` y `CaseNotice` (tarea 4); `CatalogRepository.staffFor(Actor.support)` (Luis Castillo, con teléfono); `launchUrl` de `url_launcher`.
- Produces:
  - `ConnectionCheck({required VideoPlatform platform, required VoidCallback onFinished})`: revisa un elemento cada `ConnectionCheck.stepDuration` (600 ms) y termina a los 2.4 s.
  - `WaitingRoomScreen({required String caseId})` y `PatientVideoCallScreen({required String caseId})`.
  - `VideoCallView({required CallPerspective perspective, required Doctor doctor, required Patient patient, required VideoPlatform platform, required VoidCallback onHangUp, List<Widget> extraControls})`, `enum CallPerspective { patient, doctor }`, `CallMessage` y `CallControlButton` (para que el médico agregue "Notas clínicas" en la etapa 7). Tooltips: "Silenciar micrófono", "Apagar cámara", "Chat", "Colgar".

- [ ] **Step 1: Escribir la prueba**

Create `saludconecta/test/features/patient/waiting_room_and_call_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  /// La videollamada tiene animaciones que no terminan: se avanza el reloj a mano.
  Future<void> settleCall(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('Carmen prueba su conexión, entra a la videollamada y sale', (tester) async {
    final deps = patientDependencies(SeedIds.carmen);
    final c = openCaseOf(deps, SeedIds.carmen, ProcessStep.consultation);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseDetail(c.id));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ir a la sala de espera'));
    await settleCall(tester);
    expect(find.text('Comprobando tu conexión…'), findsOneWidget);
    // La prueba de conexión termina en 2.4 s y entonces se detienen sus animaciones.
    await tester.pumpAndSettle();
    expect(find.text('Unirse a la consulta'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Luis Castillo'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('Llamar a soporte'), findsOneWidget);

    await tester.tap(find.text('Unirse a la consulta'));
    await settleCall(tester);
    expect(find.text('Dr. Carlos Méndez'), findsOneWidget);
    expect(find.text('Google Meet'), findsOneWidget);
    // La plataforma y el cronómetro van en la barra superior, no a media pantalla.
    expect(tester.getTopLeft(find.text('Google Meet')).dy, lessThan(100));

    await tester.tap(find.byTooltip('Apagar cámara'));
    await tester.pump();
    expect(find.text('CR'), findsOneWidget);

    await tester.tap(find.byTooltip('Chat'));
    await settleCall(tester);
    await tester.enterText(find.byType(TextField), 'Me duele al sentarme');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();
    expect(find.text('Me duele al sentarme'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await settleCall(tester);

    await tester.tap(find.byTooltip('Colgar'));
    await settleCall(tester);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.text('Caso ${c.id}'), findsOneWidget);
    // La vista del paciente es solo visual: el caso sigue en el paso 7.
    expect(deps.cases.caseById(c.id)!.currentStep, ProcessStep.consultation);
  });

  testWidgets('sin el consentimiento firmado, la sala de espera lo pide primero', (tester) async {
    final deps = patientDependencies(SeedIds.jose);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.consentAdmission);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.waitingRoom));
    await tester.pumpAndSettle();
    expect(find.text('Primero firma tu consentimiento'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/patient/waiting_room_and_call_test.dart
```

Expected: FAIL. La sala de espera todavía es `ComingSoonScreen`.

- [ ] **Step 3: Crear la prueba de conexión, la sala de espera y la videollamada**

Create `saludconecta/lib/features/patient/waiting_room/connection_check.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../domain/models/enums.dart';

/// Prueba de conexión de la sala de espera (simulada): internet, cámara, micrófono y plataforma.
/// Revisa un elemento cada [stepDuration] y avisa con [onFinished] al terminar.
class ConnectionCheck extends StatefulWidget {
  const ConnectionCheck({super.key, required this.platform, required this.onFinished});

  static const stepDuration = Duration(milliseconds: 600);

  final VideoPlatform platform;
  final VoidCallback onFinished;

  @override
  State<ConnectionCheck> createState() => _ConnectionCheckState();
}

class _ConnectionCheckState extends State<ConnectionCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _levels;
  Timer? _timer;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _levels = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _timer = Timer.periodic(ConnectionCheck.stepDuration, (timer) {
      setState(() => _done++);
      if (_done == 4) {
        timer.cancel();
        _levels.stop();
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _levels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checks = [
      (Icons.wifi, 'Internet', 'Latencia de 42 ms: conexión estable'),
      (Icons.videocam_outlined, 'Cámara', 'Imagen nítida'),
      (Icons.mic_none, 'Micrófono', 'Nivel de audio correcto'),
      (AppIcons.platform(widget.platform), widget.platform.label, 'Plataforma operativa'),
    ];
    return Column(
      children: [
        for (var i = 0; i < checks.length; i++)
          _CheckRow(
            icon: checks[i].$1,
            title: checks[i].$2,
            detail: checks[i].$3,
            done: i < _done,
            checking: i == _done,
            levels: i == 2 ? _levels : null,
          ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.done,
    required this.checking,
    this.levels,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool done;
  final bool checking;

  /// Animación de las barras de nivel (solo el micrófono).
  final Animation<double>? levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final animation = levels;
    final color = done ? AppColors.done : AppColors.primary;
    final Widget status;
    if (done) {
      status = const Icon(Icons.check_circle, color: AppColors.done);
    } else if (checking) {
      status = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4));
    } else {
      status = Icon(Icons.radio_button_unchecked, color: theme.colorScheme.outlineVariant);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(done ? detail : (checking ? 'Comprobando…' : 'En espera'), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (animation != null) ...[_LevelBars(animation: animation), const SizedBox(width: 12)],
          status,
        ],
      ),
    );
  }
}

/// Barras de nivel del micrófono que suben y bajan con la animación.
class _LevelBars extends AnimatedWidget {
  const _LevelBars({required Animation<double> animation}) : super(listenable: animation);

  static const _base = [0.35, 0.8, 0.55, 1.0, 0.45];

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _base.length; i++)
            Container(
              width: 4,
              height: 4 + 20 * _base[i] * (i.isEven ? t : 1 - t),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(color: AppColors.done, borderRadius: BorderRadius.circular(2)),
            ),
        ],
      ),
    );
  }
}
```

Create `saludconecta/lib/features/patient/waiting_room/waiting_room_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_step.dart';
import '../patient_case_builder.dart';
import 'connection_check.dart';

/// Sala de espera (paso 7, lado del paciente): prueba de conexión, Soporte TI y "Unirse a la consulta".
class WaitingRoomScreen extends StatelessWidget {
  const WaitingRoomScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return PatientCaseBuilder(
      caseId: caseId,
      builder: (context, c, patient) {
        if (c.status == CaseStatus.active && c.currentStep == ProcessStep.consultation && c.appointment != null) {
          return _WaitingRoom(telemedicineCase: c);
        }
        final needsConsent = c.status == CaseStatus.active && c.currentStep == ProcessStep.consentAdmission;
        return CaseNotice(
          screenTitle: 'Sala de espera',
          title: needsConsent ? 'Primero firma tu consentimiento' : 'La sala de espera no está disponible',
          message: needsConsent
              ? 'Después de firmarlo podrás entrar a la sala de espera.'
              : 'Tu consulta ya terminó o todavía no está agendada.',
          action: needsConsent
              ? FilledButton.icon(
                  onPressed: () => context.pushReplacement(AppRoutes.caseAction(c.id, CaseAction.consent)),
                  icon: const Icon(Icons.draw),
                  label: const Text('Firmar consentimiento'),
                )
              : null,
        );
      },
    );
  }
}

class _WaitingRoom extends StatefulWidget {
  const _WaitingRoom({required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  @override
  State<_WaitingRoom> createState() => _WaitingRoomState();
}

class _WaitingRoomState extends State<_WaitingRoom> {
  bool _ready = false;

  /// Reemplaza la sala de espera: al colgar se vuelve a la pantalla anterior.
  void _join() => context.pushReplacement(AppRoutes.caseAction(widget.telemedicineCase.id, CaseAction.videoCall));

  /// Llama a Soporte TI con el marcador del teléfono (`url_launcher` con `tel:`).
  Future<void> _callSupport(String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll('-', '')));
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo abrir el marcador. Llama al $phone.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.telemedicineCase.appointment!;
    final catalog = context.read<CatalogRepository>();
    final doctor = catalog.doctorById(appointment.doctorId);
    final support = catalog.staffFor(Actor.support);
    final phone = support.phone;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sala de espera')),
      body: PageBody(
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AvatarImage(name: doctor.displayName, asset: doctor.avatarAsset, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doctor.displayName, style: theme.textTheme.titleMedium),
                          Text(doctor.specialty.label, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 4),
                          Text(Formatters.dateTime(appointment.dateTime), style: theme.textTheme.bodySmall),
                          const SizedBox(height: 8),
                          Chip(
                            avatar: Icon(AppIcons.platform(appointment.platform), size: 18),
                            label: Text(appointment.platform.label),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Prueba de conexión',
              icon: Icons.network_check,
              child: ConnectionCheck(
                platform: appointment.platform,
                onFinished: () => setState(() => _ready = true),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '¿Problemas para conectarte?',
              icon: Icons.support_agent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarImage(name: support.fullName, asset: support.avatarAsset, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(support.fullName, style: theme.textTheme.titleSmall),
                            Text(
                              '${Actor.support.label} · ${phone ?? 'sin teléfono'}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: phone == null ? null : () => _callSupport(phone),
                    icon: const Icon(Icons.call),
                    label: const Text('Llamar a soporte'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      // "Unirse a la consulta" queda fijo abajo: siempre a la vista, aunque la lista sea larga.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PageBody.maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _ready ? _join : null,
                  icon: const Icon(Icons.video_call),
                  label: Text(_ready ? 'Unirse a la consulta' : 'Comprobando tu conexión…'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/features/shared/video_call/video_call_view.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_illustrations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_illustration.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/people.dart';

/// Desde qué lado se ve la videollamada.
enum CallPerspective { patient, doctor }

/// Un mensaje del chat de la videollamada (simulado: no sale de la app).
class CallMessage {
  const CallMessage({required this.fromMe, required this.text});

  final bool fromMe;
  final String text;
}

/// Videollamada simulada (§6 del spec): el otro participante a pantalla completa, el propio video en un
/// recuadro, cronómetro, plataforma, conexión y controles. La usan el paciente (etapa 5) y el médico
/// (etapa 7, que agrega sus notas clínicas en [extraControls]).
class VideoCallView extends StatefulWidget {
  const VideoCallView({
    super.key,
    required this.perspective,
    required this.doctor,
    required this.patient,
    required this.platform,
    required this.onHangUp,
    this.extraControls = const [],
  });

  final CallPerspective perspective;
  final Doctor doctor;
  final Patient patient;
  final VideoPlatform platform;

  /// Qué pasa al colgar: el paciente sale; el médico finaliza la consulta.
  final VoidCallback onHangUp;

  /// Botones extra de la barra inferior, antes de "Colgar".
  final List<Widget> extraControls;

  @override
  State<VideoCallView> createState() => _VideoCallViewState();
}

class _VideoCallViewState extends State<VideoCallView> with SingleTickerProviderStateMixin {
  late final AnimationController _speaking;
  late final ValueNotifier<List<CallMessage>> _messages;
  Timer? _clock;
  int _seconds = 0;
  bool _micOn = true;
  bool _cameraOn = true;

  bool get _isPatient => widget.perspective == CallPerspective.patient;

  @override
  void initState() {
    super.initState();
    _speaking = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _messages = ValueNotifier([
      CallMessage(
        fromMe: !_isPatient,
        text: 'Hola, ${widget.patient.firstName}. Soy ${widget.doctor.displayName}. ¿Me escuchas bien?',
      ),
      CallMessage(fromMe: _isPatient, text: 'Sí, se escucha bien. Gracias.'),
    ]);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _speaking.dispose();
    _messages.dispose();
    super.dispose();
  }

  /// Cronómetro "mm:ss".
  String get _elapsed {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(_seconds ~/ 60)}:${two(_seconds % 60)}';
  }

  void _openChat() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        // Sube la hoja cuando aparece el teclado.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: _ChatSheet(messages: _messages),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final patient = widget.patient;
    final remoteName = _isPatient ? doctor.displayName : patient.fullName;
    final remoteSubtitle = _isPatient ? doctor.specialty.label : 'Carnet ${patient.affiliation.affiliateNumber}';
    final remoteAvatar = _isPatient ? doctor.avatarAsset : patient.avatarAsset;
    final remoteRoom = _isPatient ? AppIllustrations.roomClinic : AppIllustrations.roomHome;
    final localName = _isPatient ? patient.fullName : doctor.displayName;
    final localAvatar = _isPatient ? patient.avatarAsset : doctor.avatarAsset;
    final localRoom = _isPatient ? AppIllustrations.roomHome : AppIllustrations.roomClinic;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          Positioned.fill(child: AppIllustration(remoteRoom, fit: BoxFit.cover)),
          Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(0.2))),
          Center(child: _SpeakingAvatar(animation: _speaking, name: remoteName, asset: remoteAvatar)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Degradado oscuro detrás de la barra: el texto blanco se lee sobre cualquier fondo.
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                  child: _TopBar(
                    name: remoteName,
                    subtitle: remoteSubtitle,
                    platform: widget.platform,
                    elapsed: _elapsed,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 104,
            child: _SelfView(name: localName, asset: localAvatar, room: localRoom, cameraOn: _cameraOn, micOn: _micOn),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    CallControlButton(
                      icon: _micOn ? Icons.mic : Icons.mic_off,
                      tooltip: _micOn ? 'Silenciar micrófono' : 'Activar micrófono',
                      active: _micOn,
                      onPressed: () => setState(() => _micOn = !_micOn),
                    ),
                    CallControlButton(
                      icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
                      tooltip: _cameraOn ? 'Apagar cámara' : 'Encender cámara',
                      active: _cameraOn,
                      onPressed: () => setState(() => _cameraOn = !_cameraOn),
                    ),
                    CallControlButton(icon: Icons.chat_bubble_outline, tooltip: 'Chat', onPressed: _openChat),
                    ...widget.extraControls,
                    CallControlButton(
                      icon: Icons.call_end,
                      tooltip: 'Colgar',
                      color: AppColors.danger,
                      onPressed: widget.onHangUp,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón redondo de la barra de la videollamada.
class CallControlButton extends StatelessWidget {
  const CallControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = true,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// `false` cuando el micrófono o la cámara están apagados: el botón se ve blanco.
  final bool active;

  /// Color de fondo fijo (p. ej., rojo para colgar).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final background = color ?? (active ? Colors.white24 : Colors.white);
    final foreground = color != null || active ? Colors.white : AppColors.navy;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 26,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        fixedSize: const Size(56, 56),
      ),
      icon: Icon(icon),
    );
  }
}

/// Avatar del otro participante con un anillo que "respira" mientras habla.
class _SpeakingAvatar extends AnimatedWidget {
  const _SpeakingAvatar({required Animation<double> animation, required this.name, required this.asset})
      : super(listenable: animation);

  final String name;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: 1 + 0.12 * t,
            child: Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary.withOpacity(0.35 + 0.5 * t), width: 4),
              ),
            ),
          ),
          AvatarImage(name: name, asset: asset, size: 150),
        ],
      ),
    );
  }
}

/// Nombre y especialidad del otro participante, plataforma, cronómetro y conexión.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.name, required this.subtitle, required this.platform, required this.elapsed});

  final String name;
  final String subtitle;
  final VideoPlatform platform;
  final String elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            // Sin esto, la columna ocupa toda la altura y la fila centra las píldoras a media pantalla.
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ],
          ),
        ),
        _Pill(icon: AppIcons.platform(platform), label: platform.label),
        const SizedBox(width: 8),
        _Pill(icon: Icons.fiber_manual_record, label: elapsed, iconColor: Colors.redAccent),
        const SizedBox(width: 8),
        const Tooltip(
          message: 'Conexión estable',
          child: Icon(Icons.signal_cellular_alt, color: Colors.greenAccent),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.iconColor = Colors.white});

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// El propio video en un recuadro: con la cámara apagada se ven las iniciales.
class _SelfView extends StatelessWidget {
  const _SelfView({
    required this.name,
    required this.asset,
    required this.room,
    required this.cameraOn,
    required this.micOn,
  });

  final String name;
  final String? asset;
  final String room;
  final bool cameraOn;
  final bool micOn;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 110,
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraOn) AppIllustration(room, fit: BoxFit.cover) else const ColoredBox(color: Color(0xFF263238)),
            Center(child: AvatarImage(name: name, asset: cameraOn ? asset : null, size: 64)),
            if (!micOn) const Positioned(top: 6, right: 6, child: Icon(Icons.mic_off, color: Colors.white, size: 18)),
            const Positioned(
              left: 8,
              bottom: 6,
              child: Text('Tú', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat de la consulta: mensajes simulados en los que se puede escribir.
class _ChatSheet extends StatefulWidget {
  const _ChatSheet({required this.messages});

  final ValueNotifier<List<CallMessage>> messages;

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    widget.messages.value = [...widget.messages.value, CallMessage(fromMe: true, text: text)];
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Chat de la consulta', style: theme.textTheme.titleMedium),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<CallMessage>>(
              valueListenable: widget.messages,
              builder: (context, messages, _) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final m in messages)
                    Align(
                      alignment: m.fromMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: m.fromMe ? AppColors.primary : theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(m.text, style: TextStyle(color: m.fromMe ? Colors.white : null)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _send, tooltip: 'Enviar', icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

Create `saludconecta/lib/features/patient/call/patient_video_call_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/process/process_step.dart';
import '../../shared/video_call/video_call_view.dart';
import '../patient_case_builder.dart';

/// Videollamada del paciente (paso 7). Es solo visual: el médico es quien finaliza la consulta.
class PatientVideoCallScreen extends StatelessWidget {
  const PatientVideoCallScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return PatientCaseBuilder(
      caseId: caseId,
      builder: (context, c, patient) {
        final appointment = c.appointment;
        if (appointment == null || c.status != CaseStatus.active || c.currentStep != ProcessStep.consultation) {
          return const CaseNotice(
            screenTitle: 'Videollamada',
            title: 'La videollamada no está disponible',
            message: 'Tu consulta ya terminó o todavía no está lista.',
          );
        }
        return VideoCallView(
          perspective: CallPerspective.patient,
          doctor: context.read<CatalogRepository>().doctorById(appointment.doctorId),
          patient: patient,
          platform: appointment.platform,
          onHangUp: () => _confirmLeave(context),
        );
      },
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final router = GoRouter.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir de la videollamada?'),
        content: const Text('Tu médico finalizará la consulta y te avisaremos cuando tus resultados estén listos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Seguir en la llamada')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salir')),
        ],
      ),
    );
    if (leave != true) return;
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.caseDetail(caseId));
    }
  }
}
```

En `saludconecta/lib/core/router/app_router.dart`, cambiar los imports:

```dart
import '../../features/patient/appointments_screen.dart';
import '../../features/patient/consent/consent_screen.dart';
```

por:

```dart
import '../../features/patient/appointments_screen.dart';
import '../../features/patient/call/patient_video_call_screen.dart';
import '../../features/patient/consent/consent_screen.dart';
```

y:

```dart
import '../../features/patient/services_screen.dart';
```

por:

```dart
import '../../features/patient/services_screen.dart';
import '../../features/patient/waiting_room/waiting_room_screen.dart';
```

y, en `_caseAction`:

```dart
        CaseAction.waitingRoom => const ComingSoonScreen(title: 'Sala de espera', stage: 5),
        CaseAction.videoCall => const ComingSoonScreen(title: 'Videollamada', stage: 5),
```

por:

```dart
        CaseAction.waitingRoom => WaitingRoomScreen(caseId: caseId),
        CaseAction.videoCall => PatientVideoCallScreen(caseId: caseId),
```

- [ ] **Step 4: Ejecutar las pruebas y verificar que pasan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/patient/waiting_room_and_call_test.dart test/features/patient/consent_test.dart
```

Expected: `All tests passed!` (4 pruebas; la del consentimiento ahora termina en la sala de espera real).

---

### Task 6: Resultados con receta y QR, y encuesta

**Files:**
- Create: `saludconecta/lib/features/patient/results/prescription_document.dart`, `saludconecta/lib/features/patient/results/results_screen.dart`, `saludconecta/lib/features/patient/survey/survey_screen.dart`
- Modify: `saludconecta/lib/core/router/app_router.dart` y `saludconecta/lib/features/shared/case_detail/case_detail_screen.dart` (ediciones)
- Test: `saludconecta/test/features/patient/results_and_survey_test.dart`

**Interfaces:**
- Consumes: `ConsultationResults` (`prescription`, `ordersOf`, `referral`, `instructions`, `followUpInDays`), `TelemedicineCase.completedAt`, `CaseProvider.submitSurvey(id, {patient, rating, nps, comment})`, `PatientCaseBuilder` y `CaseNotice` (tarea 4).
- Produces: `PrescriptionDocument({caseId, prescription, doctor, patient, issuedAt})`, `ResultsScreen({required String caseId})` (título "Mis resultados") y `SurveyScreen({required String caseId})`. El detalle del caso muestra "Ver mis resultados" al paciente cuando su caso tiene resultados.

- [ ] **Step 1: Escribir la prueba**

Create `saludconecta/test/features/patient/results_and_survey_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/core/utils/formatters.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('Ramón ve su receta con QR y pide la cita de seguimiento', (tester) async {
    final deps = patientDependencies(SeedIds.ramon);
    final c = openCaseOf(deps, SeedIds.ramon, ProcessStep.administrativeClosure);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver mis resultados'));
    await tester.pump();
    await tester.tap(find.text('Ver mis resultados'));
    await tester.pumpAndSettle();

    expect(find.text('Metformina 850 mg'), findsOneWidget);
    expect(find.text('Losartán 50 mg'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(c.results!.prescription!.verificationCode), findsOneWidget);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Hemograma'), 200, scrollable: list);
    await tester.scrollUntilVisible(find.text('Solicitar cita de seguimiento'), 200, scrollable: list);
    await tester.pump();
    await tester.tap(find.text('Solicitar cita de seguimiento'));
    await tester.pumpAndSettle();

    // El asistente abre con "Seguimiento postconsulta" y la fecha que indicó el médico (30 días).
    expect(find.text('¿Por qué canal nos contactas?'), findsOneWidget);
    await tester.tap(find.text('WhatsApp'));
    await tester.enterText(find.byType(TextFormField), 'Control mensual de la glicemia');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final issued = c.completedAt(ProcessStep.consultationResult)!;
    expect(find.text(Formatters.date(DateTime(issued.year, issued.month, issued.day + 30))), findsOneWidget);
    expect(find.text('Seguimiento postconsulta'), findsWidgets);
  });

  testWidgets('"Mis resultados" del Inicio abre los resultados más recientes de María', (tester) async {
    final deps = patientDependencies(SeedIds.maria);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis resultados'));
    await tester.pumpAndSettle();

    final latest = deps.cases.casesOfPatient(SeedIds.maria).firstWhere((c) => c.results != null);
    expect(find.text('Mis resultados'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(latest.results!.instructions),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Indicaciones'), findsOneWidget);
  });

  testWidgets('el detalle del caso abre los resultados de José, que no tienen receta', (tester) async {
    final deps = patientDependencies(SeedIds.jose);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.followUp);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseDetail(c.id));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Ver mis resultados'), 300, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.text('Ver mis resultados'));
    await tester.pumpAndSettle();
    expect(find.text('Tu médico no indicó medicamentos en esta consulta.'), findsOneWidget);
    expect(find.text(c.results!.instructions), findsOneWidget);
  });

  testWidgets('José responde la encuesta y su caso queda completado', (tester) async {
    final deps = patientDependencies(SeedIds.jose);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.followUp);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Responder la encuesta'));
    await tester.pumpAndSettle();

    // Sin estrellas ni recomendación, el botón está deshabilitado.
    await tester.tap(find.text('Enviar encuesta'));
    await tester.pump();
    expect(deps.cases.caseById(c.id)!.status, CaseStatus.active);

    await tester.tap(find.byTooltip('5 de 5'));
    await tester.tap(find.text('10'));
    await tester.enterText(find.byType(TextField), 'Muy buena orientación');
    await tester.pump();
    await tester.ensureVisible(find.text('Enviar encuesta'));
    await tester.pump();
    await tester.tap(find.text('Enviar encuesta'));
    await tester.pumpAndSettle();

    final updated = deps.cases.caseById(c.id)!;
    expect(updated.status, CaseStatus.completed);
    expect(updated.followUp!.survey!.rating, 5);
    expect(updated.followUp!.survey!.nps, 10);
    expect(find.text('¡Gracias por tu opinión!'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/patient/results_and_survey_test.dart
```

Expected: FAIL. Los resultados y la encuesta todavía son `ComingSoonScreen`.

- [ ] **Step 3: Crear la receta, los resultados y la encuesta**

Create `saludconecta/lib/features/patient/results/prescription_document.dart`:

```dart
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
```

Create `saludconecta/lib/features/patient/results/results_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_illustrations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/seed/seed_catalog.dart';
import '../../../domain/models/case_records.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/process/process_step.dart';
import '../patient_case_builder.dart';
import 'prescription_document.dart';

/// Resultados de la consulta (paso 8): receta con QR, órdenes, referimiento, indicaciones
/// y, si el médico la indicó, la cita de seguimiento.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return PatientCaseBuilder(
      caseId: caseId,
      builder: (context, c, patient) {
        final results = c.results;
        final appointment = c.appointment;
        if (results == null || appointment == null) {
          return const CaseNotice(
            screenTitle: 'Mis resultados',
            title: 'Aún no hay resultados',
            message: 'Tu médico los emitirá al terminar la consulta.',
            illustration: AppIllustrations.emptyResults,
          );
        }
        final doctor = context.read<CatalogRepository>().doctorById(appointment.doctorId);
        final issuedAt = c.completedAt(ProcessStep.consultationResult) ?? c.updatedAt;
        final prescription = results.prescription;
        final labs = results.ordersOf(OrderType.lab);
        final imaging = results.ordersOf(OrderType.imaging);
        final referral = results.referral;
        final followUpDays = results.followUpInDays;
        return Scaffold(
          appBar: AppBar(title: const Text('Mis resultados')),
          body: PageBody(
            child: ListView(
              children: [
                if (prescription != null)
                  PrescriptionDocument(
                    caseId: c.id,
                    prescription: prescription,
                    doctor: doctor,
                    patient: patient,
                    issuedAt: issuedAt,
                  )
                else
                  const SectionCard(
                    title: 'Receta',
                    icon: Icons.medication_outlined,
                    child: Text('Tu médico no indicó medicamentos en esta consulta.'),
                  ),
                if (labs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _OrdersCard(title: 'Órdenes de laboratorio', icon: Icons.science_outlined, orders: labs),
                ],
                if (imaging.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _OrdersCard(title: 'Órdenes de imágenes', icon: Icons.image_search, orders: imaging),
                ],
                if (referral != null) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Referimiento',
                    icon: Icons.alt_route,
                    child: Text('${referral.specialty.label} (consulta presencial): ${referral.reason}'),
                  ),
                ],
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Indicaciones',
                  icon: Icons.assignment_outlined,
                  child: Text(results.instructions),
                ),
                if (followUpDays != null) ...[
                  const SizedBox(height: 12),
                  _FollowUpCard(days: followUpDays, issuedAt: issuedAt),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrdersCard extends StatelessWidget {
  const _OrdersCard({required this.title, required this.icon, required this.orders});

  final String title;
  final IconData icon;
  final List<MedicalOrder> orders;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      icon: icon,
      child: Column(
        children: [
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.check_box_outlined, size: 18, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.description)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// La cita de seguimiento que indicó el médico: abre el asistente con el servicio y la fecha sugerida.
class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.days, required this.issuedAt});

  final int days;
  final DateTime issuedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggested = DateTime(issuedAt.year, issuedAt.month, issuedAt.day + days);
    return Card(
      color: AppColors.secondary.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Próxima cita', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Tu médico recomienda una cita de seguimiento en $days días.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              // "Seguimiento postconsulta" es el servicio de las citas de seguimiento.
              onPressed: () => context.push(
                AppRoutes.requestAppointment(serviceId: SeedIds.postConsultFollowUp, preferredDate: suggested),
              ),
              icon: const Icon(Icons.event_repeat),
              label: const Text('Solicitar cita de seguimiento'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/features/patient/survey/survey_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_illustrations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_illustration.dart';
import '../../../core/widgets/page_body.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/people.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_exception.dart';
import '../../../domain/process/process_step.dart';
import '../../../state/case_provider.dart';
import '../patient_case_builder.dart';

/// Encuesta de satisfacción (paso 10): estrellas, recomendación de 0 a 10 y comentario opcional.
/// Al enviarla, el caso queda completado y la pantalla muestra el agradecimiento.
class SurveyScreen extends StatelessWidget {
  const SurveyScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return PatientCaseBuilder(
      caseId: caseId,
      builder: (context, c, patient) {
        final survey = c.followUp?.survey;
        if (survey != null) {
          return CaseNotice(
            screenTitle: 'Encuesta de satisfacción',
            title: '¡Gracias por tu opinión!',
            message: 'Calificaste tu atención con ${survey.rating} de 5 estrellas.',
            illustration: AppIllustrations.onboardingFollowUp,
          );
        }
        if (c.status != CaseStatus.active || c.currentStep != ProcessStep.followUp) {
          return const CaseNotice(
            screenTitle: 'Encuesta de satisfacción',
            title: 'La encuesta aún no está disponible',
            message: 'Podrás responderla cuando se cierre tu atención.',
          );
        }
        return _SurveyForm(telemedicineCase: c, patient: patient);
      },
    );
  }
}

class _SurveyForm extends StatefulWidget {
  const _SurveyForm({required this.telemedicineCase, required this.patient});

  final TelemedicineCase telemedicineCase;
  final Patient patient;

  @override
  State<_SurveyForm> createState() => _SurveyFormState();
}

class _SurveyFormState extends State<_SurveyForm> {
  final _comment = TextEditingController();
  int _rating = 0;
  int? _nps;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    final nps = _nps;
    if (_rating == 0 || nps == null) return;
    final cases = context.read<CaseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      cases.submitSurvey(
        widget.telemedicineCase.id,
        patient: widget.patient,
        rating: _rating,
        nps: nps,
        comment: _comment.text.trim(),
      );
      messenger.showSnackBar(const SnackBar(content: Text('¡Gracias! Tu atención quedó completada.')));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final appointment = c.appointment;
    final doctorName = appointment == null ? '' : ' con ${catalog.doctorById(appointment.doctorId).displayName}';
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Encuesta de satisfacción')),
      body: PageBody(
        child: ListView(
          children: [
            Row(
              children: [
                const AppIllustration(AppIllustrations.onboardingFollowUp, width: 96, height: 72),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¿Cómo fue tu atención?', style: theme.textTheme.titleLarge),
                      Text('${catalog.serviceById(c.serviceId).name}$doctorName', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Califica tu experiencia', style: theme.textTheme.titleMedium),
            Row(
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    tooltip: '$star de 5',
                    iconSize: 40,
                    onPressed: () => setState(() => _rating = star),
                    icon: Icon(
                      star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppColors.current,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('¿Qué tan probable es que nos recomiendes?', style: theme.textTheme.titleMedium),
            Text('0 = nada probable · 10 = muy probable', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var score = 0; score <= 10; score++)
                  ChoiceChip(
                    label: Text('$score'),
                    selected: _nps == score,
                    onSelected: (_) => setState(() => _nps = score),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _comment,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _rating > 0 && _nps != null ? _submit : null,
              icon: const Icon(Icons.send),
              label: const Text('Enviar encuesta'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
```

En `saludconecta/lib/core/router/app_router.dart`, cambiar los imports:

```dart
import '../../features/patient/request/request_appointment_screen.dart';
import '../../features/patient/services_screen.dart';
import '../../features/patient/waiting_room/waiting_room_screen.dart';
```

por:

```dart
import '../../features/patient/request/request_appointment_screen.dart';
import '../../features/patient/results/results_screen.dart';
import '../../features/patient/services_screen.dart';
import '../../features/patient/survey/survey_screen.dart';
import '../../features/patient/waiting_room/waiting_room_screen.dart';
```

y, en `_caseAction`:

```dart
        CaseAction.results => const ComingSoonScreen(title: 'Resultados', stage: 5),
        CaseAction.survey => const ComingSoonScreen(title: 'Encuesta de satisfacción', stage: 5),
```

por:

```dart
        CaseAction.results => ResultsScreen(caseId: caseId),
        CaseAction.survey => SurveyScreen(caseId: caseId),
```

En `saludconecta/lib/features/shared/case_detail/case_detail_screen.dart`, cambiar:

```dart
    final canCancel =
        role == UserRole.patient && c.patientId == session.currentPatient?.id && ProcessRules.canPatientCancel(c);
```

por:

```dart
    final ownCase = role == UserRole.patient && c.patientId == session.currentPatient?.id;
    final canCancel = ownCase && ProcessRules.canPatientCancel(c);
```

y, al comienzo de los botones del final:

```dart
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.caseDiagram(c.id)),
```

por:

```dart
              children: [
                if (ownCase && c.results != null)
                  FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.caseAction(c.id, CaseAction.results)),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Ver mis resultados'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.caseDiagram(c.id)),
```

- [ ] **Step 4: Ejecutar las pruebas y verificar que pasan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features
```

Expected: `All tests passed!` (las 24 del paciente y las de las etapas anteriores en `test/features`).

---

### Task 7: Verificación y commit de la etapa

**Files:**
- Modify: `docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md` (enlace al plan y estado de la etapa 5)

- [ ] **Step 1: Formato, suite completa y análisis**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
$dart = 'C:\Users\Helen\dev\flutter\bin\dart.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $dart format -l 120 lib test
& $flutter test
& $flutter analyze
```

Expected:
- `dart format` no cambia ningún archivo (el código del plan ya viene formateado);
- `All tests passed!` (unas 170 pruebas);
- `No issues found!`.

- [ ] **Step 2: Recorrido en la web**

Con `preview_start` (`saludconecta-web`), esperar unos 20 s, recargar y recorrer la app capturando cada pantalla:

1. **Ingreso → Paciente → María Fernández:** el Inicio muestra el saludo, la campana, "No tienes citas en curso", los 4 accesos rápidos y el carrusel de consejos.
2. **"Solicitar cita":** Consulta médica general → WhatsApp y un motivo → la fecha y el resumen con "80% con ARS Salud Plena". "Enviar solicitud" abre el detalle con "Esperando a Admisión".
3. **"Mis citas":** Activas (1) e Historial (4).
4. **"Servicios":** los canales y los 3 grupos con sus chips.
5. **"Perfil":** el carnet con degradado, plan Plus y "Activa".
6. **"Cambiar de rol" → José Martínez:** "Firmar consentimiento" → casillas y firma con el mouse → sala de espera → la prueba de conexión termina → "Unirse a la consulta" → videollamada (cronómetro, cámara apagada con iniciales, chat) → "Colgar".
7. **José → "Responder la encuesta":** 5 estrellas y 10 → "¡Gracias por tu opinión!".
8. **"Cambiar de rol" → Ramón Ortiz → "Ver mis resultados":** la receta con QR, las órdenes y "Solicitar cita de seguimiento".

Expected: cada pantalla se ve completa y la consola del navegador no muestra errores nuevos. Si el panel del navegador está oculto, las animaciones se frenan: esperar 1 o 2 s antes de capturar.

Al terminar, se detiene el servidor con `preview_stop`.

- [ ] **Step 3: Revisar en el emulador Android**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
$adb = 'C:\Users\Helen\AppData\Local\Android\Sdk\platform-tools\adb.exe'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter build apk --debug --target-platform android-x64
& $adb install -r build\app\outputs\flutter-apk\app-debug.apk
& $adb shell am force-stop edu.unapec.iso910.saludconecta
& $adb shell input keyevent KEYCODE_WAKEUP
& $adb shell am start -n edu.unapec.iso910.saludconecta/.MainActivity
Start-Sleep -Seconds 10
& $adb shell screencap -p /sdcard/saludconecta.png
& $adb pull /sdcard/saludconecta.png <scratchpad>\saludconecta-etapa5.png
```

Después, con `adb shell input tap` sobre las coordenadas de cada captura: Omitir → Paciente → María Fernández → Ingresar, y capturar el Inicio de María en el teléfono (diseño angosto). Repetir con el asistente "Solicitar cita" (`Stepper` vertical) y con la videollamada.

Expected: el Inicio, el asistente y la videollamada se ven completos en el teléfono, sin desbordes.

- [ ] **Step 4: Actualizar la hoja de ruta**

En `docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md`, en la fila de la etapa 5:
- cambiar `al cerrar la 4` por `[05-flujo-paciente](2026-11-09-saludconecta-05-flujo-paciente.md)`;
- cambiar el estado `pendiente` por `hecha`.

- [ ] **Step 5: Commit de la etapa 5**

```powershell
$repo = 'C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial'
git -C $repo add saludconecta docs/superpowers/plans
git -C $repo status --short
git -C $repo commit -m "feat: flujo del paciente de SaludConecta (etapa 5)" -m "Asistente para solicitar cita, Inicio con avisos y accesos rápidos, Mis citas, Servicios, Perfil con carnet, consentimiento con firma, sala de espera con prueba de conexión, videollamada simulada, resultados con receta y QR, y encuesta. 170 pruebas en verde."
git -C $repo log --oneline -3
```

Expected: el commit tiene como autor `FDLG301201`.

Siguiente paso: escribir el plan de la etapa 6, `2026-11-09-saludconecta-06-flujo-admision.md`.
