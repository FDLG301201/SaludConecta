# SaludConecta · Etapa 4: Estado, ingreso y shells — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conectar el dominio con la interfaz: el estado con Provider, las rutas con `redirect` por rol, la bienvenida, el ingreso, el cambio de rol, las pantallas base de cada rol y el detalle del caso con su línea de tiempo.

**Architecture:**

- **Estado:**
  - `SessionProvider` (quién usa la app) es el `refreshListenable` del router.
  - `CaseProvider` expone los casos y **una acción por transición**: valida, aplica `CaseWorkflow`, guarda y llama a `notifyListeners()`. Las operaciones lentas marcan el caso con `isBusy`.
- **Raíz de composición:** `AppDependencies` crea los datos semilla, los gateways, los providers y el router, y los publica con `MultiProvider` (`main.dart`). Las pruebas usan la misma raíz con una hora fija y sin pausas.
- **Rutas:**
  - todas las del §6 existen desde esta etapa;
  - lo que se construye después apunta a `ComingSoonScreen`, que cada etapa reemplaza;
  - `RouteGuard` es una función pura con las reglas del `redirect`.

**Tech Stack:** provider 6.1 (`ChangeNotifier`, `MultiProvider`, `context.watch/read`), go_router 14.6 (`StatefulShellRoute.indexedStack`, `redirect`, `refreshListenable`), `CustomPainter` (conector de la línea de tiempo).

**Hoja de ruta:** [00-hoja-de-ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md) · **Spec:** §5, §6 (rutas, redirect, shells, pantallas comunes), §8, §10.3, §12

## Global Constraints

Las de la [hoja de ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md#global-constraints). Las más relevantes para esta etapa:

- **Capas:**
  - la UI (`features/`, `core/widgets/`) solo lee y llama al estado (`state/`); nunca toca repositorios ni gateways;
  - `CatalogRepository` se publica con `Provider` para consultar nombres y datos.
- **APIs de Flutter 3.19:** `MaterialState*`, `withOpacity`, `PopScope.onPopInvoked`, `surfaceVariant`.
- **Shells:** `NavigationBar` por debajo de 800 px y `NavigationRail` desde 800 px. Las pantallas de lectura tienen un ancho máximo de 1100 px (`PageBody`).
- **Errores:** las `ProcessException` se muestran en un `SnackBar`. Después de un `await` no se usa `context`: se capturan antes `ScaffoldMessenger`, `GoRouter` y los providers.
- **Calidad:** `flutter analyze` sin avisos.
- **Git:** un solo commit al final de la etapa (tarea 6).

## Archivos de la etapa

| Archivo | Responsabilidad |
|---|---|
| `lib/state/session_provider.dart` | Rol y usuario actuales; avisos leídos por paciente |
| `lib/state/case_provider.dart` | Casos, bandejas por rol y las 16 acciones del proceso |
| `lib/core/router/app_routes.dart` | Rutas (`AppRoutes`) y acciones sobre un caso (`CaseAction`) |
| `lib/core/router/route_guard.dart` | Reglas del `redirect` (función pura) |
| `lib/core/router/app_router.dart` | `GoRouter` con todas las rutas y los shells por rol |
| `lib/app_dependencies.dart` | Raíz de composición |
| `lib/main.dart` | Arranque con `AppDependencies` |
| `lib/core/theme/app_colors.dart` | + colores por actor y por estado |
| `lib/core/theme/app_icons.dart` | Íconos de servicios, canales, plataformas, pasos, actores y roles |
| `lib/core/widgets/` | `PageBody`, `SectionCard`, `StepBadge`, `ActorChip`, `StatusChip`, `CaseCard`, `EmptyState`, `LoadingButton`, `RoleSwitcherSheet`, `ComingSoonScreen` |
| `lib/features/auth/` | Bienvenida (`PageView`), selección de rol, ingreso del paciente e ingreso del personal |
| `lib/features/patient/patient_home_screen.dart` | Inicio del paciente (versión básica; la etapa 5 la completa) |
| `lib/features/shared/role_shell.dart` | Barra superior y navegación de cada rol |
| `lib/features/shared/case_list_screen.dart` | Lista de casos de una bandeja (las etapas 6–8 la reemplazan) |
| `lib/features/shared/not_found_screen.dart` | "Página no encontrada" / "Caso no encontrado" |
| `lib/features/shared/case_detail/` | `next_action.dart`, `case_timeline.dart`, `case_header.dart`, `case_sections.dart`, `case_detail_screen.dart` |
| `test/state/`, `test/core/router/`, `test/core/widgets/`, `test/features/`, `test/support/app_harness.dart` | Pruebas |

---

### Task 1: Estado: sesión y casos

**Files:**
- Create: `saludconecta/lib/state/session_provider.dart`, `saludconecta/lib/state/case_provider.dart`
- Test: `saludconecta/test/state/session_provider_test.dart`, `saludconecta/test/state/case_provider_test.dart`

**Interfaces:**
- Consumes: el dominio, los repositorios, los gateways y la semilla (etapa 2), y los fixtures de las pruebas.
- Produces:
  - **`SessionProvider({Clock clock})`:**

    | Grupo | Miembros |
    |---|---|
    | Lectura | `role`, `isLoggedIn`, `currentPatient`, `currentStaff`, `currentDoctor`, `displayName` |
    | Ingreso | `loginPatient(Patient)`, `loginStaff(StaffMember)` (solo Admisión y Facturación), `loginDoctor(Doctor)`, `logout()` |
    | Avisos | `notificationsSeenAt(patientId) → DateTime?`, `markNotificationsSeen()` |

  - **`CaseProvider({required CatalogRepository catalog, required CaseRepository repository, required InsuranceGateway insurance, required ConfirmationGateway confirmation, Clock clock})`:**
    - **Lectura:** `catalog`, `cases`, `caseById(id)`, `now`, `isBusy(caseId)` e `invoiceFor(case)`.
    - **Bandejas:** `inboxFor(role, {patientId, doctorId})`, `casesOfPatient(id)`, `admissionInbox()`, `followUpCases()`, `doctorAgenda(doctorId)` y `billingInbox()`.
    - **Acciones** (`staff` es `StaffMember`; `doctor`, `Doctor`; `patient`, `Patient`):

      | Paso | Acción | Devuelve |
      |---|---|---|
      | 1 | `requestAppointment({patient, service, channel, reason, preferredDate})` | `TelemedicineCase` |
      | 2 | `registerReception(id, {staff, notes})` | `TelemedicineCase` |
      | 3 | `validateInsurance(id, {staff})` | `Future<InsuranceValidation>` |
      | 3 | `continueAsPrivate(id, {staff})` | `TelemedicineCase` |
      | Cualquiera | `cancelCase(id, {role, actorName, reason})` | `TelemedicineCase` |
      | 4 | `scheduleAppointment(id, {staff, doctor, dateTime, platform})` | `TelemedicineCase` |
      | 5 | `sendConfirmation(id, {staff, via})` | `Future<String>` (el enlace) |
      | 6 | `signConsent(id, {patient, acceptedTerms, acceptedDataUse, identityConfirmed, signature})` | `TelemedicineCase` |
      | 7 | `startConsultation(id, {doctor})` | `TelemedicineCase` |
      | 7 | `finishConsultation(id, {doctor, notes})` | `TelemedicineCase` |
      | 8 | `issueResults(id, {doctor, instructions, medications, orders, referral, followUpInDays})` | `TelemedicineCase` |
      | 9 | `submitClaim(id, {staff})` | `Future<String>` (el número) |
      | 9 | `registerPayment(id, {staff, method})` | `TelemedicineCase` |
      | 9 | `closeAdministratively(id, {staff})` | `TelemedicineCase` |
      | 10 | `logFollowUpCall(id, {staff, note})` | `TelemedicineCase` |
      | 10 | `submitSurvey(id, {patient, rating, nps, comment})` | `TelemedicineCase` |

    Todas lanzan `ProcessException` si la regla no lo permite. En ese caso no guardan nada ni notifican.

- [ ] **Step 1: Escribir las pruebas del estado**

Create `saludconecta/test/state/session_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/state/session_provider.dart';

import '../support/fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 9, 10);
  late SessionProvider session;
  late int notifications;

  setUp(() {
    session = SessionProvider(clock: () => now);
    notifications = 0;
    session.addListener(() => notifications++);
  });

  test('empieza sin sesión', () {
    expect(session.isLoggedIn, isFalse);
    expect(session.role, isNull);
    expect(session.displayName, '');
  });

  test('la paciente ingresa y sus avisos anteriores cuentan como leídos', () {
    session.loginPatient(maria);
    expect(session.role, UserRole.patient);
    expect(session.currentPatient, same(maria));
    expect(session.displayName, 'María Fernández');
    expect(session.notificationsSeenAt(maria.id), now);
    expect(notifications, 1);
  });

  test('cambiar de rol reemplaza la sesión anterior', () {
    session.loginPatient(maria);
    session.loginDoctor(mendez);
    expect(session.role, UserRole.doctor);
    expect(session.currentPatient, isNull);
    expect(session.currentDoctor, same(mendez));
    expect(session.displayName, 'Dr. Carlos Méndez');
    session.loginStaff(catalog.staffFor(Actor.billing));
    expect(session.role, UserRole.billing);
    expect(session.displayName, 'Roberto Díaz');
  });

  test('Soporte TI no inicia sesión en la app', () {
    expect(() => session.loginStaff(catalog.staffFor(Actor.support)), throwsArgumentError);
  });

  test('los avisos leídos se conservan al cambiar de rol; cerrar sesión limpia el rol', () {
    var clock = now;
    session = SessionProvider(clock: () => clock);
    session.loginPatient(maria);
    clock = now.add(const Duration(hours: 2));
    session.markNotificationsSeen();
    session.loginDoctor(mendez);
    session.loginPatient(maria);
    expect(session.notificationsSeenAt(maria.id), now.add(const Duration(hours: 2)));
    session.logout();
    expect(session.isLoggedIn, isFalse);
  });
}
```

Create `saludconecta/test/state/case_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/gateways/confirmation_gateway.dart';
import 'package:saludconecta/data/gateways/insurance_gateway.dart';
import 'package:saludconecta/data/repositories/case_repository.dart';
import 'package:saludconecta/data/seed/seed_cases.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/case_records.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_exception.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/schedule_service.dart';
import 'package:saludconecta/state/case_provider.dart';

import '../support/fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 9, 10);
  final ana = catalog.staffFor(Actor.admission);
  final roberto = catalog.staffFor(Actor.billing);
  late CaseProvider provider;
  late int notifications;

  setUp(() {
    provider = CaseProvider(
      catalog: catalog,
      repository: InMemoryCaseRepository(SeedCases.generate(now: now, catalog: catalog)),
      insurance: SimulatedInsuranceGateway(catalog: catalog, clock: () => now, delay: Duration.zero),
      confirmation: SimulatedConfirmationGateway(delay: Duration.zero),
      clock: () => now,
    );
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  String requestForMaria() => provider
      .requestAppointment(
        patient: maria,
        service: generalConsult,
        channel: RequestChannel.whatsapp,
        reason: 'Fiebre y dolor de garganta',
        preferredDate: DateTime(2026, 11, 12),
      )
      .id;

  test('solicitar una cita crea el caso, notifica y aparece en "Nuevas" de Admisión', () {
    final id = requestForMaria();
    expect(notifications, 1);
    expect(provider.caseById(id)!.currentStep, ProcessStep.reception);
    expect(provider.admissionInbox().map((c) => c.id), contains(id));
    expect(provider.casesOfPatient(maria.id).first.id, id);
  });

  test('una acción no permitida lanza ProcessException y no cambia nada', () {
    final id = requestForMaria();
    notifications = 0;
    expect(() => provider.closeAdministratively(id, staff: roberto), throwsA(isA<ProcessException>()));
    expect(notifications, 0);
    expect(provider.caseById(id)!.currentStep, ProcessStep.reception);
  });

  test('mientras se consulta al seguro el caso queda ocupado', () async {
    final id = requestForMaria();
    provider.registerReception(id, staff: ana);
    final pending = provider.validateInsurance(id, staff: ana);
    expect(provider.isBusy(id), isTrue);
    await expectLater(provider.validateInsurance(id, staff: ana), throwsA(isA<ProcessException>()));
    final result = await pending;
    expect(result.approved, isTrue);
    expect(result.coveragePercent, 80);
    expect(provider.isBusy(id), isFalse);
    expect(provider.caseById(id)!.currentStep, ProcessStep.scheduling);
  });

  test('recorrido en vivo completo: de la solicitud a la encuesta', () async {
    final id = requestForMaria();
    provider.registerReception(id, staff: ana);
    await provider.validateInsurance(id, staff: ana);
    final day = ScheduleService.availableDays(doctor: mendez, cases: provider.cases, now: now).first;
    final slot = ScheduleService.availableSlots(doctor: mendez, day: day, cases: provider.cases, now: now).first;
    provider.scheduleAppointment(id, staff: ana, doctor: mendez, dateTime: slot, platform: VideoPlatform.teams);
    expect(
      await provider.sendConfirmation(id, staff: ana, via: RequestChannel.whatsapp),
      startsWith('https://teams.microsoft.com/'),
    );
    provider.signConsent(
      id,
      patient: maria,
      acceptedTerms: true,
      acceptedDataUse: true,
      identityConfirmed: true,
      signature: signature,
    );
    provider.startConsultation(id, doctor: mendez);
    provider.finishConsultation(id, doctor: mendez, notes: notes);
    provider.issueResults(
      id,
      doctor: mendez,
      instructions: 'Reposo e hidratación',
      medications: const [
        PrescriptionItem(medication: 'Acetaminofén 500 mg', dose: '1 tableta', frequency: 'Cada 8 horas', duration: '5 días'),
      ],
      followUpInDays: 15,
    );
    expect(await provider.submitClaim(id, staff: roberto), startsWith('REC-'));
    provider.registerPayment(id, staff: roberto, method: PaymentMethod.card);
    provider.closeAdministratively(id, staff: roberto);
    provider.submitSurvey(id, patient: maria, rating: 5, nps: 10);
    final done = provider.caseById(id)!;
    expect(done.status, CaseStatus.completed);
    expect(done.completedSteps, ProcessStep.values.toSet());
    expect(provider.invoiceFor(done).copay, 300);
  });

  test('el seguro rechaza a Pedro (afiliación inactiva) y Admisión continúa como privado', () async {
    final pedroCase = provider.admissionInbox().firstWhere((c) => c.patientId == SeedIds.pedro);
    final result = await provider.validateInsurance(pedroCase.id, staff: ana);
    expect(result.approved, isFalse);
    expect(provider.caseById(pedroCase.id)!.status, CaseStatus.insuranceRejected);
    expect(provider.admissionInbox().map((c) => c.id), contains(pedroCase.id));
    provider.continueAsPrivate(pedroCase.id, staff: ana);
    final updated = provider.caseById(pedroCase.id)!;
    expect(updated.privatePay, isTrue);
    expect(updated.currentStep, ProcessStep.scheduling);
  });

  test('no se agenda con un médico de otra especialidad ni en un turno ocupado', () async {
    final id = requestForMaria();
    provider.registerReception(id, staff: ana);
    await provider.validateInsurance(id, staff: ana);
    final day = ScheduleService.availableDays(doctor: mendez, cases: provider.cases, now: now).first;
    final slot = ScheduleService.availableSlots(doctor: mendez, day: day, cases: provider.cases, now: now).first;
    final jimenez = catalog.doctorById(SeedIds.jimenez);
    expect(
      () => provider.scheduleAppointment(id, staff: ana, doctor: jimenez, dateTime: slot, platform: VideoPlatform.zoom),
      throwsA(isA<ProcessException>()),
    );
    final booked = provider.doctorAgenda(SeedIds.mendez).first.appointment!.dateTime;
    expect(
      () => provider.scheduleAppointment(id, staff: ana, doctor: mendez, dateTime: booked, platform: VideoPlatform.zoom),
      throwsA(isA<ProcessException>()),
    );
  });

  test('cada rol ve su bandeja', () {
    expect(provider.admissionInbox().map((c) => c.currentStep.number).toSet(), {2, 3, 4, 5});
    expect(provider.doctorAgenda(SeedIds.mendez).map((c) => c.currentStep.number).toList()..sort(), [6, 7, 8]);
    expect(provider.inboxFor(UserRole.doctor, doctorId: SeedIds.jimenez), isEmpty);
    expect(provider.billingInbox(), hasLength(1));
    expect(provider.followUpCases(), hasLength(1));
    expect(provider.inboxFor(UserRole.patient, patientId: SeedIds.jose).length, greaterThanOrEqualTo(3));
  });
}
```

- [ ] **Step 2: Ejecutar las pruebas y verificar que fallan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/state
```

Expected: FAIL. No compila porque `lib/state/` no existe.

- [ ] **Step 3: Crear `SessionProvider`**

Create `saludconecta/lib/state/session_provider.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../domain/models/enums.dart';
import '../domain/models/people.dart';
import '../domain/services/clock.dart';

/// Quién usa la app y con qué rol (modo demostración: sin contraseñas).
///
/// Es el `refreshListenable` del router: cuando cambia, go_router vuelve a evaluar el `redirect`.
class SessionProvider extends ChangeNotifier {
  SessionProvider({Clock clock = DateTime.now}) : _clock = clock;

  final Clock _clock;
  UserRole? _role;
  Patient? _patient;
  StaffMember? _staff;
  Doctor? _doctor;

  /// Hasta cuándo leyó sus avisos cada paciente (se conserva al cambiar de rol).
  final _notificationsSeenAt = <String, DateTime>{};

  UserRole? get role => _role;
  bool get isLoggedIn => _role != null;
  Patient? get currentPatient => _patient;
  StaffMember? get currentStaff => _staff;
  Doctor? get currentDoctor => _doctor;

  /// Nombre de quien usa la app: "María Fernández", "Dr. Carlos Méndez"…
  String get displayName => _patient?.fullName ?? _doctor?.displayName ?? _staff?.fullName ?? '';

  /// Ingreso del paciente con su carnet.
  void loginPatient(Patient patient) {
    // La primera vez, los avisos anteriores cuentan como leídos.
    _notificationsSeenAt.putIfAbsent(patient.id, _clock);
    _set(UserRole.patient, patient: patient);
  }

  /// Ingreso de Admisión o de Facturación. Soporte TI no usa la app (solo es contacto).
  void loginStaff(StaffMember staff) {
    final role = switch (staff.actor) {
      Actor.admission => UserRole.admission,
      Actor.billing => UserRole.billing,
      _ => throw ArgumentError('${staff.fullName} no inicia sesión en la app.'),
    };
    _set(role, staff: staff);
  }

  void loginDoctor(Doctor doctor) => _set(UserRole.doctor, doctor: doctor);

  void logout() => _set(null);

  /// Desde cuándo el paciente no tiene avisos sin leer.
  DateTime? notificationsSeenAt(String patientId) => _notificationsSeenAt[patientId];

  void markNotificationsSeen() {
    final patient = _patient;
    if (patient == null) return;
    _notificationsSeenAt[patient.id] = _clock();
    notifyListeners();
  }

  void _set(UserRole? role, {Patient? patient, StaffMember? staff, Doctor? doctor}) {
    _role = role;
    _patient = patient;
    _staff = staff;
    _doctor = doctor;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Crear `CaseProvider`**

Create `saludconecta/lib/state/case_provider.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../data/gateways/confirmation_gateway.dart';
import '../data/gateways/insurance_gateway.dart';
import '../data/repositories/case_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../domain/models/case_records.dart';
import '../domain/models/catalog.dart';
import '../domain/models/enums.dart';
import '../domain/models/people.dart';
import '../domain/models/telemedicine_case.dart';
import '../domain/process/case_workflow.dart';
import '../domain/process/process_exception.dart';
import '../domain/process/process_rules.dart';
import '../domain/process/process_step.dart';
import '../domain/services/billing_calculator.dart';
import '../domain/services/clock.dart';
import '../domain/services/schedule_service.dart';

/// Estado de los casos de telemedicina (§5 del spec).
///
/// La UI lee los casos y llama a una acción por cada transición. Cada acción:
/// 1. valida con las reglas del dominio (lanza `ProcessException` si no se puede);
/// 2. obtiene el caso nuevo con `CaseWorkflow` (los modelos son inmutables);
/// 3. lo guarda en el repositorio;
/// 4. llama a `notifyListeners()` para que las pantallas se vuelvan a dibujar.
class CaseProvider extends ChangeNotifier {
  CaseProvider({
    required this.catalog,
    required CaseRepository repository,
    required InsuranceGateway insurance,
    required ConfirmationGateway confirmation,
    Clock clock = DateTime.now,
  })  : _repository = repository,
        _insurance = insurance,
        _confirmation = confirmation,
        _clock = clock;

  final CatalogRepository catalog;
  final CaseRepository _repository;
  final InsuranceGateway _insurance;
  final ConfirmationGateway _confirmation;
  final Clock _clock;

  /// Casos con una operación lenta en curso (seguro, envío del enlace, reclamación).
  final _busy = <String>{};

  static const _admissionSteps = {
    ProcessStep.reception,
    ProcessStep.insuranceValidation,
    ProcessStep.scheduling,
    ProcessStep.patientConfirmation,
  };
  static const _doctorSteps = {ProcessStep.consentAdmission, ProcessStep.consultation, ProcessStep.consultationResult};

  // ----- Lectura -----

  List<TelemedicineCase> get cases => _repository.getAll();

  TelemedicineCase? caseById(String id) => _repository.getById(id);

  /// Hora actual según el reloj de la app (fija en las pruebas).
  DateTime get now => _clock();

  /// `true` mientras una operación lenta está en curso: la UI muestra carga y deshabilita botones.
  bool isBusy(String caseId) => _busy.contains(caseId);

  /// Casos que le toca atender a cada rol.
  List<TelemedicineCase> inboxFor(UserRole role, {String? patientId, String? doctorId}) => switch (role) {
        UserRole.patient => casesOfPatient(patientId ?? ''),
        UserRole.admission => admissionInbox(),
        UserRole.doctor => doctorAgenda(doctorId ?? ''),
        UserRole.billing => billingInbox(),
      };

  /// Casos del paciente, del movimiento más reciente al más antiguo.
  List<TelemedicineCase> casesOfPatient(String patientId) {
    final result = [
      for (final c in cases)
        if (c.patientId == patientId) c,
    ];
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  /// Admisión: pasos 2 a 5 pendientes (incluye los rechazados por el seguro), el más antiguo primero.
  List<TelemedicineCase> admissionInbox() => _oldestFirst([
        for (final c in cases)
          if (c.isOpen && _admissionSteps.contains(c.currentStep)) c,
      ]);

  /// Admisión: casos en el paso 10 (llamadas de seguimiento y encuesta pendiente).
  List<TelemedicineCase> followUpCases() => _oldestFirst([
        for (final c in cases)
          if (c.status == CaseStatus.active && c.currentStep == ProcessStep.followUp) c,
      ]);

  /// Médico: sus citas con los pasos 6, 7 u 8 pendientes, por fecha de la cita.
  List<TelemedicineCase> doctorAgenda(String doctorId) {
    final result = [
      for (final c in cases)
        if (c.status == CaseStatus.active &&
            _doctorSteps.contains(c.currentStep) &&
            c.appointment?.doctorId == doctorId)
          c,
    ];
    result.sort((a, b) => a.appointment!.dateTime.compareTo(b.appointment!.dateTime));
    return result;
  }

  /// Facturación: casos con el paso 9 pendiente.
  List<TelemedicineCase> billingInbox() => _oldestFirst([
        for (final c in cases)
          if (c.status == CaseStatus.active && c.currentStep == ProcessStep.administrativeClosure) c,
      ]);

  /// Factura del caso según la tarifa del servicio y la cobertura del seguro.
  Invoice invoiceFor(TelemedicineCase c) => BillingCalculator.invoiceFor(c, catalog.serviceById(c.serviceId));

  // ----- Acciones: una por transición del proceso -----

  /// Paso 1: el paciente pide una cita. Devuelve el caso creado.
  TelemedicineCase requestAppointment({
    required Patient patient,
    required MedicalService service,
    required RequestChannel channel,
    required String reason,
    required DateTime preferredDate,
  }) {
    final at = _clock();
    return _save(CaseWorkflow.request(
      id: _repository.nextId(at),
      patient: patient,
      service: service,
      channel: channel,
      reason: reason,
      preferredDate: preferredDate,
      at: at,
    ));
  }

  /// Paso 2: Admisión registra la solicitud.
  TelemedicineCase registerReception(String caseId, {required StaffMember staff, String notes = ''}) => _update(
        caseId,
        (c) => CaseWorkflow.registerReception(c, staffName: staff.fullName, notes: notes, at: _clock()),
      );

  /// Paso 3: consulta al seguro (operación lenta). Si rechaza, el caso queda "Rechazado por el seguro".
  Future<InsuranceValidation> validateInsurance(String caseId, {required StaffMember staff}) async {
    final c = _require(caseId);
    ProcessRules.ensureCanPerform(c, ProcessStep.insuranceValidation, UserRole.admission);
    return _whileBusy(caseId, () async {
      final result = await _insurance.validate(
        patient: catalog.patientById(c.patientId),
        service: catalog.serviceById(c.serviceId),
        caseId: caseId,
      );
      _update(caseId, (latest) => CaseWorkflow.applyInsuranceResult(latest, result: result, staffName: staff.fullName));
      return result;
    });
  }

  /// Paso 3, tras el rechazo: el paciente continúa como privado (paga el 100%).
  TelemedicineCase continueAsPrivate(String caseId, {required StaffMember staff}) =>
      _update(caseId, (c) => CaseWorkflow.continueAsPrivate(c, staffName: staff.fullName, at: _clock()));

  /// Cancela la solicitud: el paciente (hasta el paso 6) o Admisión (tras un rechazo del seguro).
  TelemedicineCase cancelCase(
    String caseId, {
    required UserRole role,
    required String actorName,
    String reason = '',
  }) =>
      _update(caseId, (c) => CaseWorkflow.cancel(c, role: role, actorName: actorName, at: _clock(), reason: reason));

  /// Paso 4: agenda la cita. El médico debe atender la especialidad del servicio y el turno debe seguir libre.
  TelemedicineCase scheduleAppointment(
    String caseId, {
    required StaffMember staff,
    required Doctor doctor,
    required DateTime dateTime,
    required VideoPlatform platform,
  }) {
    return _update(caseId, (c) {
      ProcessRules.ensureCanPerform(c, ProcessStep.scheduling, UserRole.admission);
      final service = catalog.serviceById(c.serviceId);
      if (service.specialty != doctor.specialty) {
        throw ProcessException('${doctor.displayName} no atiende ${service.name}.');
      }
      final free = ScheduleService.availableSlots(doctor: doctor, day: dateTime, cases: cases, now: _clock());
      if (!free.contains(dateTime)) {
        throw const ProcessException('Ese horario ya no está disponible. Elige otro.');
      }
      return CaseWorkflow.schedule(
        c,
        doctor: doctor,
        dateTime: dateTime,
        platform: platform,
        staffName: staff.fullName,
        at: _clock(),
      );
    });
  }

  /// Paso 5: envía el enlace por WhatsApp o correo (operación lenta). Devuelve el enlace.
  Future<String> sendConfirmation(String caseId, {required StaffMember staff, required RequestChannel via}) async {
    final c = _require(caseId);
    ProcessRules.ensureCanPerform(c, ProcessStep.patientConfirmation, UserRole.admission);
    return _whileBusy(caseId, () async {
      final link = await _confirmation.send(caseId: caseId, platform: c.appointment!.platform, via: via);
      _update(
        caseId,
        (latest) => CaseWorkflow.confirm(latest, link: link, via: via, staffName: staff.fullName, at: _clock()),
      );
      return link;
    });
  }

  /// Paso 6: el paciente firma el consentimiento.
  TelemedicineCase signConsent(
    String caseId, {
    required Patient patient,
    required bool acceptedTerms,
    required bool acceptedDataUse,
    required bool identityConfirmed,
    required List<List<SignaturePoint>> signature,
  }) =>
      _update(
        caseId,
        (c) => CaseWorkflow.signConsent(
          c,
          patient: patient,
          acceptedTerms: acceptedTerms,
          acceptedDataUse: acceptedDataUse,
          identityConfirmed: identityConfirmed,
          signature: signature,
          at: _clock(),
        ),
      );

  /// Paso 7 (auxiliar): el médico abre la consulta. En modo demo no espera la hora agendada.
  TelemedicineCase startConsultation(String caseId, {required Doctor doctor}) =>
      _update(caseId, (c) => CaseWorkflow.startConsultation(c, doctor: doctor, at: _clock()));

  /// Paso 7: el médico finaliza la consulta con sus notas clínicas.
  TelemedicineCase finishConsultation(String caseId, {required Doctor doctor, required ClinicalNotes notes}) =>
      _update(caseId, (c) => CaseWorkflow.finishConsultation(c, doctor: doctor, notes: notes, at: _clock()));

  /// Paso 8: el médico emite receta, órdenes, referimiento e indicaciones.
  TelemedicineCase issueResults(
    String caseId, {
    required Doctor doctor,
    required String instructions,
    List<PrescriptionItem> medications = const [],
    List<MedicalOrder> orders = const [],
    Referral? referral,
    int? followUpInDays,
  }) =>
      _update(
        caseId,
        (c) => CaseWorkflow.issueResults(
          c,
          doctor: doctor,
          instructions: instructions,
          medications: medications,
          orders: orders,
          referral: referral,
          followUpInDays: followUpInDays,
          at: _clock(),
        ),
      );

  /// Paso 9 (auxiliar, operación lenta): envía la reclamación al seguro. En vivo siempre se aprueba.
  Future<String> submitClaim(String caseId, {required StaffMember staff}) async {
    final c = _require(caseId);
    ProcessRules.ensureCanAssist(c, AssistAction.submitClaim, UserRole.billing);
    if (invoiceFor(c).insurerAmount == 0) {
      throw const ProcessException('No aplica reclamación: el paciente es privado.');
    }
    return _whileBusy(caseId, () async {
      final number = await _insurance.submitClaim(caseId: caseId);
      _update(
        caseId,
        (latest) => CaseWorkflow.recordClaim(
          latest,
          service: catalog.serviceById(latest.serviceId),
          claimNumber: number,
          status: ClaimStatus.approved,
          staffName: staff.fullName,
          at: _clock(),
        ),
      );
      return number;
    });
  }

  /// Paso 9 (auxiliar): registra el pago del copago (solo el método, nunca datos de tarjeta).
  TelemedicineCase registerPayment(String caseId, {required StaffMember staff, required PaymentMethod method}) =>
      _update(
        caseId,
        (c) => CaseWorkflow.registerPayment(
          c,
          service: catalog.serviceById(c.serviceId),
          method: method,
          staffName: staff.fullName,
          at: _clock(),
        ),
      );

  /// Paso 9: cierre administrativo (requiere auditoría completa, reclamación y pago).
  TelemedicineCase closeAdministratively(String caseId, {required StaffMember staff}) => _update(
        caseId,
        (c) => CaseWorkflow.closeAdministratively(
          c,
          service: catalog.serviceById(c.serviceId),
          staffName: staff.fullName,
          at: _clock(),
        ),
      );

  /// Paso 10 (auxiliar): Admisión registra una llamada de seguimiento.
  TelemedicineCase logFollowUpCall(String caseId, {required StaffMember staff, required String note}) =>
      _update(caseId, (c) => CaseWorkflow.logFollowUpCall(c, staffName: staff.fullName, note: note, at: _clock()));

  /// Paso 10: el paciente responde la encuesta y el caso queda completado.
  TelemedicineCase submitSurvey(
    String caseId, {
    required Patient patient,
    required int rating,
    required int nps,
    String comment = '',
  }) =>
      _update(
        caseId,
        (c) => CaseWorkflow.submitSurvey(c, patient: patient, rating: rating, nps: nps, comment: comment, at: _clock()),
      );

  // ----- Ayudantes -----

  TelemedicineCase _require(String caseId) {
    final c = _repository.getById(caseId);
    if (c == null) {
      throw ProcessException('No existe el caso $caseId.');
    }
    return c;
  }

  /// Aplica [change] al caso actual, lo guarda y notifica. Si [change] lanza, no se guarda nada.
  TelemedicineCase _update(String caseId, TelemedicineCase Function(TelemedicineCase current) change) =>
      _save(change(_require(caseId)));

  TelemedicineCase _save(TelemedicineCase c) {
    _repository.save(c);
    notifyListeners();
    return c;
  }

  List<TelemedicineCase> _oldestFirst(List<TelemedicineCase> items) =>
      items..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Marca el caso como ocupado mientras corre [operation].
  Future<T> _whileBusy<T>(String caseId, Future<T> Function() operation) async {
    if (!_busy.add(caseId)) {
      throw const ProcessException('Ya hay una operación en curso para este caso.');
    }
    notifyListeners();
    try {
      return await operation();
    } finally {
      _busy.remove(caseId);
      notifyListeners();
    }
  }
}
```

- [ ] **Step 5: Ejecutar las pruebas y verificar que pasan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/state
```

Expected: `All tests passed!` (12 pruebas: 5 de sesión y 7 de casos).

---

### Task 2: Rutas y reglas de acceso

**Files:**
- Create: `saludconecta/lib/core/router/app_routes.dart`, `saludconecta/lib/core/router/route_guard.dart`
- Test: `saludconecta/test/core/router/route_guard_test.dart`

**Interfaces:**
- Consumes: `UserRole`.
- Produces:
  - **Rutas fijas de `AppRoutes`** (`String`):

    | Grupo | Constantes |
    |---|---|
    | Ingreso | `welcome`, `login`, `patientLogin` |
    | Paciente | `patientHome`, `patientAppointments`, `patientServices`, `patientProfile`, `requestAppointmentPath` |
    | Admisión | `admissionInbox`, `admissionAgenda`, `admissionFollowUp`, `admissionIndicators` |
    | Médico | `doctorAgenda`, `doctorIndicators` |
    | Facturación | `billingPending`, `billingClaims`, `billingIndicators` |
    | Comunes | `process`, `about` |

  - **Rutas que se arman con datos:**
    - `staffLogin(role)` y `home(role)`;
    - `requestAppointment({serviceId})`;
    - `caseDetail(id)`, `caseDiagram(id)` y `caseAction(id, action)`.
  - **`CaseAction`:**
    - valores: `consent`, `waitingRoom`, `videoCall`, `results`, `survey`, `process`, `consultation`, `issueResults`, `closure`;
    - campos `segment` y `role`, y `fromSegment(String)`.
  - **`RouteGuard.redirect(String path, UserRole? role) → String?`.**

- [ ] **Step 1: Escribir la prueba de las reglas de acceso**

Create `saludconecta/test/core/router/route_guard_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/core/router/route_guard.dart';
import 'package:saludconecta/domain/models/enums.dart';

void main() {
  test('sin sesión solo se ven la bienvenida y el ingreso', () {
    expect(RouteGuard.redirect('/bienvenida', null), isNull);
    expect(RouteGuard.redirect('/ingreso', null), isNull);
    expect(RouteGuard.redirect('/ingreso/personal/medico', null), isNull);
    expect(RouteGuard.redirect('/paciente', null), '/ingreso');
    expect(RouteGuard.redirect('/caso/TM-2026-0001', null), '/ingreso');
    expect(RouteGuard.redirect('/proceso', null), '/ingreso');
  });

  test('con sesión, el ingreso lleva al inicio del rol', () {
    expect(RouteGuard.redirect('/ingreso', UserRole.billing), '/facturacion');
    expect(RouteGuard.redirect('/ingreso/paciente', UserRole.patient), '/paciente');
  });

  test('las secciones de otro rol llevan al inicio del rol actual', () {
    expect(RouteGuard.redirect('/admision', UserRole.patient), '/paciente');
    expect(RouteGuard.redirect('/facturacion/reclamaciones', UserRole.patient), '/paciente');
    expect(RouteGuard.redirect('/paciente', UserRole.doctor), '/medico');
    expect(RouteGuard.redirect('/paciente/citas', UserRole.patient), isNull);
    expect(RouteGuard.redirect('/paciente/solicitar', UserRole.patient), isNull);
    expect(RouteGuard.redirect('/medico/indicadores', UserRole.doctor), isNull);
  });

  test('las acciones de otro rol sobre un caso llevan al detalle del caso', () {
    expect(RouteGuard.redirect('/caso/TM-2026-0001/procesar', UserRole.patient), '/caso/TM-2026-0001');
    expect(RouteGuard.redirect('/caso/TM-2026-0001/cierre', UserRole.doctor), '/caso/TM-2026-0001');
    expect(RouteGuard.redirect('/caso/TM-2026-0001/consentimiento', UserRole.patient), isNull);
    expect(RouteGuard.redirect('/caso/TM-2026-0001/consulta', UserRole.doctor), isNull);
    expect(RouteGuard.redirect('/caso/TM-2026-0001/diagrama', UserRole.billing), isNull);
    expect(RouteGuard.redirect('/caso/TM-2026-0001', UserRole.admission), isNull);
    expect(RouteGuard.redirect('/proceso', UserRole.admission), isNull);
  });

  test('rutas armadas con datos', () {
    expect(CaseAction.fromSegment('emitir-resultados'), CaseAction.issueResults);
    expect(CaseAction.fromSegment('otra'), isNull);
    expect(AppRoutes.caseAction('TM-1', CaseAction.waitingRoom), '/caso/TM-1/sala-espera');
    expect(AppRoutes.staffLogin(UserRole.billing), '/ingreso/personal/facturacion');
    expect(AppRoutes.requestAppointment(serviceId: 'nutricion'), '/paciente/solicitar?servicio=nutricion');
    expect(AppRoutes.home(UserRole.admission), '/admision');
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/core/router/route_guard_test.dart
```

Expected: FAIL. No compila porque `app_routes.dart` y `route_guard.dart` no existen.

- [ ] **Step 3: Crear las rutas y las reglas**

Create `saludconecta/lib/core/router/app_routes.dart`:

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
  static String requestAppointment({String? serviceId}) =>
      serviceId == null ? requestAppointmentPath : '$requestAppointmentPath?servicio=$serviceId';

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

Create `saludconecta/lib/core/router/route_guard.dart`:

```dart
import '../../domain/models/enums.dart';
import 'app_routes.dart';

/// Reglas de acceso del `redirect` de go_router (§6 del spec). Es una función pura para poder probarla:
/// recibe la ruta pedida y el rol de la sesión, y devuelve a dónde redirigir (o `null` para seguir).
class RouteGuard {
  const RouteGuard._();

  static String? redirect(String path, UserRole? role) {
    final isLogin = path == AppRoutes.login || path.startsWith('${AppRoutes.login}/');
    final isPublic = isLogin || path == AppRoutes.welcome;

    // Sin sesión solo se ven la bienvenida y el ingreso.
    if (role == null) return isPublic ? null : AppRoutes.login;

    // Con sesión, el ingreso lleva al inicio del rol.
    if (isLogin) return AppRoutes.home(role);

    // Las secciones de otro rol llevan al inicio del rol actual.
    final owner = _sectionOwner(path);
    if (owner != null && owner != role) return AppRoutes.home(role);

    // Las acciones de otro rol sobre un caso llevan al detalle del caso.
    final segments = Uri.parse(path).pathSegments;
    if (segments.length == 3 && segments.first == 'caso') {
      final action = CaseAction.fromSegment(segments[2]);
      if (action != null && action.role != role) return AppRoutes.caseDetail(segments[1]);
    }
    return null;
  }

  /// Rol dueño de una sección (`/paciente…`, `/admision…`, `/medico…`, `/facturacion…`).
  static UserRole? _sectionOwner(String path) {
    for (final role in UserRole.values) {
      final home = AppRoutes.home(role);
      if (path == home || path.startsWith('$home/')) return role;
    }
    return null;
  }
}
```

- [ ] **Step 4: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/core/router/route_guard_test.dart
```

Expected: `All tests passed!` (5 pruebas).

---

### Task 3: Colores por actor, íconos y widgets base

**Files:**
- Modify (reemplazo completo): `saludconecta/lib/core/theme/app_colors.dart`
- Create: `saludconecta/lib/core/theme/app_icons.dart`
- Create: `saludconecta/lib/core/widgets/page_body.dart`, `section_card.dart`, `step_badge.dart`, `actor_chip.dart`, `status_chip.dart`, `empty_state.dart`, `loading_button.dart`, `coming_soon_screen.dart` (en `saludconecta/lib/core/widgets/`)
- Test: `saludconecta/test/core/widgets/base_widgets_test.dart`

**Interfaces:**
- Consumes: los enums y `ProcessStep` (etapa 2); `AppIllustrations` y `AppIllustration` (etapa 3).
- Produces:
  - **Colores:** `AppColors.forActor(Actor)` y `AppColors.forStatus(CaseStatus)`.
  - **Íconos de `AppIcons`:** `service(iconKey)`, `channel(RequestChannel)`, `platform(VideoPlatform)`, `step(ProcessStep)`, `actor(Actor)` y `role(UserRole)`.
  - **Widgets:**

    | Widget | Constructor |
    |---|---|
    | `PageBody` | `({required child, padding})`, con ancho máximo de 1100 |
    | `SectionCard` | `({required title, required child, icon, trailing})` |
    | `StepBadge` | `({required step, size = 32, color})` |
    | `ActorChip` | `({required actor, label})` |
    | `StatusChip` | `({required status})` |
    | `EmptyState` | `({required illustration, required title, message, action})` |
    | `LoadingButton` | `({required label, required onPressed, loading = false, icon})` |
    | `ComingSoonScreen` | `({required title, required stage, inShell = false})` |

- [ ] **Step 1: Escribir la prueba de los widgets base**

Create `saludconecta/test/core/widgets/base_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/constants/app_illustrations.dart';
import 'package:saludconecta/core/widgets/actor_chip.dart';
import 'package:saludconecta/core/widgets/coming_soon_screen.dart';
import 'package:saludconecta/core/widgets/empty_state.dart';
import 'package:saludconecta/core/widgets/loading_button.dart';
import 'package:saludconecta/core/widgets/status_chip.dart';
import 'package:saludconecta/core/widgets/step_badge.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

void main() {
  testWidgets('StepBadge, StatusChip y ActorChip muestran su texto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StepBadge(step: ProcessStep.consultation),
              StatusChip(status: CaseStatus.insuranceRejected),
              ActorChip(actor: Actor.support),
            ],
          ),
        ),
      ),
    );
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Rechazado por el seguro'), findsOneWidget);
    expect(find.text('Soporte TI'), findsOneWidget);
  });

  testWidgets('LoadingButton se deshabilita y muestra carga mientras espera', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LoadingButton(label: 'Consultar al seguro', loading: true, onPressed: () => taps++)),
      ),
    );
    await tester.tap(find.text('Consultar al seguro'));
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('EmptyState muestra el título, el mensaje y la acción', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            illustration: AppIllustrations.emptyCases,
            title: 'Aún no tienes citas',
            message: 'Solicita tu primera cita.',
            action: TextButton(onPressed: () {}, child: const Text('Solicitar cita')),
          ),
        ),
      ),
    );
    expect(find.text('Aún no tienes citas'), findsOneWidget);
    expect(find.text('Solicitar cita'), findsOneWidget);
  });

  testWidgets('ComingSoonScreen dice en qué etapa se construye la pantalla', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComingSoonScreen(title: 'Mis citas', stage: 5)));
    expect(find.text('Esta pantalla se construye en la etapa 5 del plan.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/core/widgets/base_widgets_test.dart
```

Expected: FAIL. No compila porque los widgets no existen.

- [ ] **Step 3: Colores por actor y por estado; íconos**

Replace the whole content of `saludconecta/lib/core/theme/app_colors.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';

/// Paleta de SaludConecta (§11 del spec).
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF1565C0);
  static const secondary = Color(0xFF00897B);
  static const background = Color(0xFFF4F8FB);

  /// Azul marino de los encabezados.
  static const navy = Color(0xFF0D3B66);

  // Un color por actor del proceso (infografía 1).
  static const patient = Color(0xFF43A047);
  static const admission = Color(0xFF1E88E5);
  static const doctor = Color(0xFF00897B);
  static const support = Color(0xFF7B1FA2);
  static const billing = Color(0xFF283593);

  // Estados de los pasos.
  static const done = Color(0xFF2E7D32);
  static const current = Color(0xFFF9A825);
  static const pending = Color(0xFF9E9E9E);
  static const danger = Color(0xFFC62828);

  /// Ámbar oscuro para textos sobre fondo ámbar claro (contraste legible).
  static const currentText = Color(0xFF8A6100);

  /// Color de cada actor del proceso.
  static Color forActor(Actor actor) => switch (actor) {
        Actor.patient => patient,
        Actor.admission => admission,
        Actor.doctor => doctor,
        Actor.support => support,
        Actor.billing => billing,
      };

  /// Color de cada estado del caso.
  static Color forStatus(CaseStatus status) => switch (status) {
        CaseStatus.active => current,
        CaseStatus.completed => done,
        CaseStatus.insuranceRejected || CaseStatus.cancelled => danger,
      };
}
```

Create `saludconecta/lib/core/theme/app_icons.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';
import '../../domain/process/process_step.dart';

/// Íconos de Material para los conceptos del dominio. El dominio no depende de Flutter:
/// guarda claves (`iconKey`) o enums, y aquí se traducen a `IconData`.
class AppIcons {
  const AppIcons._();

  static const _services = <String, IconData>{
    'stethoscope': Icons.medical_services,
    'monitor_heart': Icons.monitor_heart,
    'child_care': Icons.child_care,
    'female': Icons.female,
    'favorite': Icons.favorite,
    'psychology': Icons.psychology,
    'restaurant': Icons.restaurant,
    'groups': Icons.groups,
    'medication': Icons.medication,
    'event_available': Icons.event_available,
    'healing': Icons.healing,
    'fact_check': Icons.fact_check,
    'support_agent': Icons.support_agent,
    'school': Icons.school,
    'notifications_active': Icons.notifications_active,
    'thumb_up': Icons.thumb_up,
    'receipt_long': Icons.receipt_long,
    'science': Icons.science,
    'image_search': Icons.image_search,
    'alt_route': Icons.alt_route,
    'assignment': Icons.assignment,
    'calendar_month': Icons.calendar_month,
    'verified_user': Icons.verified_user,
    'verified': Icons.verified,
  };

  /// Ícono de un servicio por su `iconKey`.
  static IconData service(String iconKey) => _services[iconKey] ?? Icons.medical_services;

  static IconData channel(RequestChannel channel) => switch (channel) {
        RequestChannel.mobile => Icons.smartphone,
        RequestChannel.email => Icons.email_outlined,
        RequestChannel.whatsapp => Icons.chat_outlined,
        RequestChannel.webPortal => Icons.language,
        RequestChannel.phone => Icons.call_outlined,
      };

  /// Teams, Zoom y Meet se muestran por nombre con íconos genéricos (sin sus logos).
  static IconData platform(VideoPlatform platform) => switch (platform) {
        VideoPlatform.teams => Icons.groups_outlined,
        VideoPlatform.zoom => Icons.videocam_outlined,
        VideoPlatform.meet => Icons.video_call_outlined,
      };

  static IconData step(ProcessStep step) => switch (step) {
        ProcessStep.requestAppointment => Icons.edit_calendar,
        ProcessStep.reception => Icons.support_agent,
        ProcessStep.insuranceValidation => Icons.verified_user,
        ProcessStep.scheduling => Icons.calendar_month,
        ProcessStep.patientConfirmation => Icons.mark_email_read,
        ProcessStep.consentAdmission => Icons.draw,
        ProcessStep.consultation => Icons.video_camera_front,
        ProcessStep.consultationResult => Icons.receipt_long,
        ProcessStep.administrativeClosure => Icons.request_quote,
        ProcessStep.followUp => Icons.favorite,
      };

  static IconData actor(Actor actor) => switch (actor) {
        Actor.patient => Icons.person,
        Actor.admission => Icons.support_agent,
        Actor.doctor => Icons.medical_services,
        Actor.support => Icons.settings,
        Actor.billing => Icons.receipt_long,
      };

  static IconData role(UserRole role) => actor(role.actor);
}
```

- [ ] **Step 4: Crear los widgets base**

Create `saludconecta/lib/core/widgets/page_body.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Contenido de una pantalla: arriba y al centro, con un ancho máximo de 1100 px (§6 del spec).
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  static const maxWidth = 1100.0;

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
```

Create `saludconecta/lib/core/widgets/section_card.dart`:

```dart
import 'package:flutter/material.dart';

/// Tarjeta con título (y, opcionalmente, un ícono y un widget a la derecha).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.icon, this.trailing});

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/core/widgets/step_badge.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/process/process_step.dart';
import '../theme/app_colors.dart';

/// Número de paso en un círculo, con el color de su actor (o el color que se indique).
class StepBadge extends StatelessWidget {
  const StepBadge({super.key, required this.step, this.size = 32, this.color});

  final ProcessStep step;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color ?? AppColors.forActor(step.actor), shape: BoxShape.circle),
      child: Text(
        '${step.number}',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.42),
      ),
    );
  }
}
```

Create `saludconecta/lib/core/widgets/actor_chip.dart`:

```dart
import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Chip con el ícono y el color de un actor del proceso.
class ActorChip extends StatelessWidget {
  const ActorChip({super.key, required this.actor, this.label});

  final Actor actor;

  /// Texto opcional; por defecto, el nombre del actor.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forActor(actor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.actor(actor), size: 14, color: color),
          const SizedBox(width: 4),
          Text(label ?? actor.label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
```

Create `saludconecta/lib/core/widgets/status_chip.dart`:

```dart
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
```

Create `saludconecta/lib/core/widgets/empty_state.dart`:

```dart
import 'package:flutter/material.dart';

import 'app_illustration.dart';

/// Ilustración y texto para cuando una lista está vacía.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.illustration, required this.title, this.message, this.action});

  final String illustration;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIllustration(illustration, width: 220, height: 160),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/core/widgets/loading_button.dart`:

```dart
import 'package:flutter/material.dart';

/// Botón que muestra un indicador de carga y se deshabilita mientras [loading] es `true`
/// (operaciones lentas: seguro, envío del enlace, reclamación).
class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const spinner = SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4));
    if (!loading && icon == null) {
      return FilledButton(onPressed: onPressed, child: Text(label));
    }
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading ? spinner : Icon(icon),
      label: Text(label),
    );
  }
}
```

Create `saludconecta/lib/core/widgets/coming_soon_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../constants/app_illustrations.dart';
import 'empty_state.dart';

/// Pantalla provisional de lo que se construye en una etapa posterior del plan.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.stage, this.inShell = false});

  final String title;
  final int stage;

  /// Dentro de un shell no lleva barra propia (el shell ya tiene una).
  final bool inShell;

  @override
  Widget build(BuildContext context) {
    final body = EmptyState(
      illustration: AppIllustrations.emptyCases,
      title: title,
      message: 'Esta pantalla se construye en la etapa $stage del plan.',
    );
    if (inShell) return body;
    return Scaffold(appBar: AppBar(title: Text(title)), body: body);
  }
}
```

- [ ] **Step 5: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/core/widgets/base_widgets_test.dart
```

Expected: `All tests passed!` (4 pruebas).

---

### Task 4: Detalle del caso y línea de tiempo

**Files:**
- Create: `saludconecta/lib/core/widgets/case_card.dart`
- Create: `saludconecta/lib/features/shared/not_found_screen.dart`
- Create: `saludconecta/lib/features/shared/case_detail/next_action.dart`, `case_timeline.dart`, `case_header.dart`, `case_sections.dart`, `case_detail_screen.dart`
- Test: `saludconecta/test/features/case_detail/next_action_test.dart`, `saludconecta/test/features/case_detail/case_timeline_test.dart`

**Interfaces:**
- Consumes:
  - `CaseProvider`, `SessionProvider`, `CatalogRepository` (vía Provider) y `AppRoutes`/`CaseAction`;
  - los widgets base y los fixtures.
- Produces:
  - **Próxima acción** (en `next_action.dart`):
    - `NextAction{label, route, icon}`;
    - `nextActionFor(case, role, {patientId, doctorId}) → NextAction?`;
    - `waitingText(case) → String`.
  - **Línea de tiempo:**
    - `TimelineStepState`: `done`, `current`, `blocked` o `pending`;
    - `CaseTimeline({required telemedicineCase})`;
    - `CaseTimeline.stateOf(case, step)`.
  - **Pantallas y widgets:**
    - `CaseHeader({required telemedicineCase, required patient, required service})`;
    - `CaseSections({required telemedicineCase})`;
    - `CaseDetailScreen({required caseId})`;
    - `NotFoundScreen({title, message})`;
    - `CaseCard({required telemedicineCase, onTap, showPatient = true, trailing})`.

- [ ] **Step 1: Escribir las pruebas de la próxima acción y de la línea de tiempo**

Create `saludconecta/test/features/case_detail/next_action_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/features/shared/case_detail/next_action.dart';

import '../../support/fixtures.dart';

void main() {
  test('Admisión procesa los pasos 2 a 5', () {
    final action = nextActionFor(caseAt(ProcessStep.scheduling), UserRole.admission);
    expect(action!.label, 'Procesar solicitud');
    expect(action.route, '/caso/TM-2026-0100/procesar');
  });

  test('el paciente firma el consentimiento solo de su propio caso', () {
    final c = caseAt(ProcessStep.consentAdmission);
    expect(nextActionFor(c, UserRole.patient, patientId: maria.id)!.label, 'Firmar consentimiento');
    expect(nextActionFor(c, UserRole.patient, patientId: 'pac-otro'), isNull);
  });

  test('solo el médico asignado inicia la consulta', () {
    final c = caseAt(ProcessStep.consultation);
    expect(nextActionFor(c, UserRole.doctor, doctorId: mendez.id)!.label, 'Iniciar consulta');
    expect(nextActionFor(c, UserRole.doctor, doctorId: 'doc-otro'), isNull);
    expect(nextActionFor(c, UserRole.patient, patientId: maria.id)!.label, 'Ir a la sala de espera');
  });

  test('Facturación hace el cierre y nadie actúa sobre un caso completado', () {
    expect(nextActionFor(caseAt(ProcessStep.administrativeClosure), UserRole.billing)!.route, '/caso/TM-2026-0100/cierre');
    for (final role in UserRole.values) {
      expect(nextActionFor(caseAt(null), role, patientId: maria.id, doctorId: mendez.id), isNull);
    }
  });

  test('texto de espera según a quién le toca el paso', () {
    expect(waitingText(caseAt(ProcessStep.consentAdmission)), 'Esperando al paciente: Consentimiento y admisión virtual');
    expect(waitingText(caseAt(ProcessStep.reception)), 'Esperando a Admisión: Recepción en Hospital / PSS');
  });
}
```

Create `saludconecta/test/features/case_detail/case_timeline_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/features/shared/case_detail/case_timeline.dart';

import '../../support/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('estado de cada paso en la línea de tiempo', () {
    final c = caseAt(ProcessStep.consultation);
    expect(CaseTimeline.stateOf(c, ProcessStep.consentAdmission), TimelineStepState.done);
    expect(CaseTimeline.stateOf(c, ProcessStep.consultation), TimelineStepState.current);
    expect(CaseTimeline.stateOf(c, ProcessStep.followUp), TimelineStepState.pending);
    final refused = CaseWorkflow.applyInsuranceResult(
      caseAt(ProcessStep.insuranceValidation),
      staffName: ana,
      result: rejected(start),
    );
    expect(CaseTimeline.stateOf(refused, ProcessStep.insuranceValidation), TimelineStepState.blocked);
  });

  testWidgets('muestra los 10 pasos y los eventos del caso', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: CaseTimeline(telemedicineCase: caseAt(ProcessStep.consultation))),
        ),
      ),
    );
    for (final step in ProcessStep.values) {
      expect(find.text(step.title), findsOneWidget);
    }
    expect(find.text('Consentimiento firmado'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar las pruebas y verificar que fallan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/case_detail
```

Expected: FAIL. No compila porque los archivos de `case_detail/` no existen.

- [ ] **Step 3: Crear la próxima acción y la línea de tiempo**

Create `saludconecta/lib/features/shared/case_detail/next_action.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_step.dart';

/// Lo que un rol puede hacer ahora con un caso: el texto del botón, la ruta y el ícono.
class NextAction {
  const NextAction({required this.label, required this.route, required this.icon});

  final String label;
  final String route;
  final IconData icon;
}

/// Próxima acción de [role] sobre el caso, o `null` si le toca a otro actor o si el caso terminó.
/// [patientId] y [doctorId] son de quien tiene la sesión: solo actúa sobre sus propios casos.
NextAction? nextActionFor(TelemedicineCase c, UserRole role, {String? patientId, String? doctorId}) {
  String action(CaseAction a) => AppRoutes.caseAction(c.id, a);
  if (c.status == CaseStatus.insuranceRejected) {
    return role == UserRole.admission
        ? NextAction(label: 'Resolver el rechazo del seguro', route: action(CaseAction.process), icon: Icons.rule)
        : null;
  }
  if (c.status != CaseStatus.active) return null;
  final ownCase = patientId != null && c.patientId == patientId;
  final assigned = doctorId != null && c.appointment?.doctorId == doctorId;
  return switch ((role, c.currentStep)) {
    (
      UserRole.admission,
      ProcessStep.reception ||
          ProcessStep.insuranceValidation ||
          ProcessStep.scheduling ||
          ProcessStep.patientConfirmation
    ) =>
      NextAction(label: 'Procesar solicitud', route: action(CaseAction.process), icon: Icons.playlist_add_check),
    (UserRole.admission, ProcessStep.followUp) =>
      const NextAction(label: 'Registrar llamada de seguimiento', route: AppRoutes.admissionFollowUp, icon: Icons.call),
    (UserRole.patient, ProcessStep.consentAdmission) when ownCase =>
      NextAction(label: 'Firmar consentimiento', route: action(CaseAction.consent), icon: Icons.draw),
    (UserRole.patient, ProcessStep.consultation) when ownCase =>
      NextAction(label: 'Ir a la sala de espera', route: action(CaseAction.waitingRoom), icon: Icons.meeting_room),
    (UserRole.patient, ProcessStep.followUp) when ownCase =>
      NextAction(label: 'Responder la encuesta', route: action(CaseAction.survey), icon: Icons.star_rate),
    (UserRole.doctor, ProcessStep.consultation) when assigned =>
      NextAction(label: 'Iniciar consulta', route: action(CaseAction.consultation), icon: Icons.video_call),
    (UserRole.doctor, ProcessStep.consultationResult) when assigned =>
      NextAction(label: 'Emitir resultados', route: action(CaseAction.issueResults), icon: Icons.receipt_long),
    (UserRole.billing, ProcessStep.administrativeClosure) =>
      NextAction(label: 'Cierre administrativo', route: action(CaseAction.closure), icon: Icons.request_quote),
    _ => null,
  };
}

/// Texto cuando el paso le toca a otro actor, p. ej. "Esperando a Admisión: Agendamiento".
String waitingText(TelemedicineCase c) {
  final step = c.currentStep;
  final who = switch (step.owners.first) {
    UserRole.patient => 'al paciente',
    UserRole.admission => 'a Admisión',
    UserRole.doctor => 'al médico',
    UserRole.billing => 'a Facturación',
  };
  return 'Esperando $who: ${step.title}';
}
```

Create `saludconecta/lib/features/shared/case_detail/case_timeline.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/process_event.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_step.dart';

/// Estado visual de un paso en la línea de tiempo.
enum TimelineStepState { done, current, blocked, pending }

/// Línea de tiempo del caso (§10.3 del spec): los 10 pasos en vertical, unidos por un conector
/// pintado con `CustomPainter`. Cada paso muestra su actor y sus eventos con fecha, hora y detalle.
class CaseTimeline extends StatelessWidget {
  const CaseTimeline({super.key, required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  /// Completado (verde), actual (ámbar), detenido por rechazo o cancelación (rojo) o pendiente (gris).
  static TimelineStepState stateOf(TelemedicineCase c, ProcessStep step) {
    if (c.isStepCompleted(step)) return TimelineStepState.done;
    if (step == c.currentStep && c.status != CaseStatus.completed) {
      return c.status == CaseStatus.active ? TimelineStepState.current : TimelineStepState.blocked;
    }
    return TimelineStepState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    return Column(
      children: [
        for (final step in ProcessStep.values)
          _TimelineRow(
            step: step,
            state: stateOf(c, step),
            events: [
              for (final e in c.events)
                if (e.step == step) e,
            ],
            isLast: step == ProcessStep.followUp,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.state, required this.events, required this.isLast});

  final ProcessStep step;
  final TimelineStepState state;
  final List<ProcessEvent> events;
  final bool isLast;

  Color get _color => switch (state) {
        TimelineStepState.done => AppColors.done,
        TimelineStepState.current => AppColors.current,
        TimelineStepState.blocked => AppColors.danger,
        TimelineStepState.pending => AppColors.pending,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlighted = state == TimelineStepState.current || state == TimelineStepState.blocked;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: CustomPaint(
              painter: _ConnectorPainter(color: AppColors.pending.withOpacity(0.45), visible: !isLast),
              child: Align(alignment: Alignment.topCenter, child: _StepDot(step: step, state: state, color: _color)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: highlighted ? const EdgeInsets.all(10) : const EdgeInsets.only(top: 5),
                decoration: highlighted
                    ? BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(12))
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: state == TimelineStepState.pending ? AppColors.pending : null,
                      ),
                    ),
                    Text(
                      step.actor.label,
                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.forActor(step.actor)),
                    ),
                    for (final e in events) _EventLine(event: e),
                    if (events.isEmpty && state == TimelineStepState.current)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('En curso', style: theme.textTheme.bodySmall),
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

class _StepDot extends StatelessWidget {
  const _StepDot({required this.step, required this.state, required this.color});

  final ProcessStep step;
  final TimelineStepState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final filled = state != TimelineStepState.pending;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? color : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: switch (state) {
        TimelineStepState.done => const Icon(Icons.check, size: 18, color: Colors.white),
        TimelineStepState.blocked => const Icon(Icons.priority_high, size: 18, color: Colors.white),
        _ => Text(
            '${step.number}',
            style: TextStyle(color: filled ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
      },
    );
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine({required this.event});

  final ProcessEvent event;

  IconData get _icon => switch (event.kind) {
        EventKind.completed => Icons.check_circle_outline,
        EventKind.rejected => Icons.block,
        EventKind.cancelled => Icons.cancel_outlined,
        EventKind.started => Icons.play_circle_outline,
        EventKind.claim => Icons.receipt_long_outlined,
        EventKind.payment => Icons.payments_outlined,
        EventKind.call => Icons.call_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: theme.textTheme.bodyMedium),
                if (event.detail.isNotEmpty) Text(event.detail, style: muted),
                Text('${Formatters.dateTime(event.at)} · ${event.actorName}', style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta la línea vertical que une un paso con el siguiente.
class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({required this.color, required this.visible});

  final Color color;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width / 2, 34), Offset(size.width / 2, size.height), paint);
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) => oldDelegate.color != color || oldDelegate.visible != visible;
}
```

- [ ] **Step 4: Crear la tarjeta de caso, el encabezado, las secciones, la pantalla y "no encontrado"**

Create `saludconecta/lib/core/widgets/case_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/telemedicine_case.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'avatar_image.dart';
import 'status_chip.dart';
import 'step_badge.dart';

/// Tarjeta de caso para las listas: paciente (o servicio), paso actual y estado.
class CaseCard extends StatelessWidget {
  const CaseCard({super.key, required this.telemedicineCase, this.onTap, this.showPatient = true, this.trailing});

  final TelemedicineCase telemedicineCase;
  final VoidCallback? onTap;

  /// En las listas del personal se muestra el paciente; en las del paciente, el servicio.
  final bool showPatient;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final patient = catalog.patientById(c.patientId);
    final service = catalog.serviceById(c.serviceId);
    final theme = Theme.of(context);
    final step = c.currentStep;
    final progress =
        c.status == CaseStatus.completed ? 'Proceso completo' : 'Paso ${step.number} de 10: ${step.title}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (showPatient)
                AvatarImage(name: patient.fullName, asset: patient.avatarAsset, size: 44)
              else
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Icon(AppIcons.service(service.iconKey), color: AppColors.primary),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showPatient ? patient.fullName : service.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      showPatient ? '${service.name} · ${c.id}' : c.id,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StepBadge(
                          step: step,
                          size: 22,
                          color: c.status == CaseStatus.active ? null : AppColors.forStatus(c.status),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            progress,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(status: c.status),
                  if (trailing != null) ...[const SizedBox(height: 6), trailing!],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/features/shared/not_found_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/empty_state.dart';
import '../../state/session_provider.dart';

/// "Página no encontrada" (ruta desconocida) o "Caso no encontrado", con un botón para volver al inicio.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({
    super.key,
    this.title = 'Página no encontrada',
    this.message = 'Esa dirección no existe en SaludConecta.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<SessionProvider>().role;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        illustration: AppIllustrations.emptyResults,
        title: title,
        message: message,
        action: FilledButton.icon(
          onPressed: () => context.go(role == null ? AppRoutes.login : AppRoutes.home(role)),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Volver al inicio'),
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/features/shared/case_detail/case_header.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../domain/models/catalog.dart';
import '../../../domain/models/people.dart';
import '../../../domain/models/telemedicine_case.dart';

/// Encabezado del caso: paciente, servicio, ID, canal de la solicitud y estado.
class CaseHeader extends StatelessWidget {
  const CaseHeader({super.key, required this.telemedicineCase, required this.patient, required this.service});

  final TelemedicineCase telemedicineCase;
  final Patient patient;
  final MedicalService service;

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AvatarImage(name: patient.fullName, asset: patient.avatarAsset, size: 60),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.fullName, style: theme.textTheme.titleLarge),
                  Text(service.name, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Pill(icon: Icons.tag, text: c.id),
                      _Pill(icon: AppIcons.channel(c.channel), text: c.channel.label),
                      if (c.privatePay) const _Pill(icon: Icons.payments_outlined, text: 'Privado'),
                      StatusChip(status: c.status),
                    ],
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

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
```

Create `saludconecta/lib/features/shared/case_detail/case_sections.dart`:

```dart
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
                results.prescription == null ? 'Sin medicamentos' : '${results.prescription!.items.length} medicamento(s)',
              ),
              _InfoRow('Órdenes', results.orders.isEmpty ? 'Ninguna' : results.orders.map((o) => o.description).join(', ')),
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
```

Create `saludconecta/lib/features/shared/case_detail/case_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/step_badge.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_exception.dart';
import '../../../domain/process/process_rules.dart';
import '../../../state/case_provider.dart';
import '../../../state/session_provider.dart';
import '../not_found_screen.dart';
import 'case_header.dart';
import 'case_sections.dart';
import 'case_timeline.dart';
import 'next_action.dart';

/// Detalle del caso (§6 del spec): encabezado, próxima acción según el rol, línea de tiempo,
/// datos de cada etapa, "Ver en el diagrama" y "Cancelar cita" cuando las reglas lo permiten.
class CaseDetailScreen extends StatelessWidget {
  const CaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final session = context.watch<SessionProvider>();
    final c = cases.caseById(caseId);
    if (c == null) {
      return const NotFoundScreen(title: 'Caso no encontrado', message: 'El caso que buscas no existe.');
    }
    final role = session.role;
    if (role == null) return const SizedBox.shrink();
    final catalog = context.read<CatalogRepository>();
    final canCancel =
        role == UserRole.patient && c.patientId == session.currentPatient?.id && ProcessRules.canPatientCancel(c);
    return Scaffold(
      appBar: AppBar(title: Text('Caso ${c.id}')),
      body: PageBody(
        child: ListView(
          children: [
            CaseHeader(
              telemedicineCase: c,
              patient: catalog.patientById(c.patientId),
              service: catalog.serviceById(c.serviceId),
            ),
            const SizedBox(height: 12),
            _NextActionCard(
              telemedicineCase: c,
              action: nextActionFor(
                c,
                role,
                patientId: session.currentPatient?.id,
                doctorId: session.currentDoctor?.id,
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(title: 'Línea de tiempo', icon: Icons.timeline, child: CaseTimeline(telemedicineCase: c)),
            const SizedBox(height: 12),
            CaseSections(telemedicineCase: c),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.caseDiagram(c.id)),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Ver en el diagrama'),
                ),
                if (canCancel)
                  TextButton.icon(
                    onPressed: () => _confirmCancel(context, c),
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar cita'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, TelemedicineCase c) async {
    // Se capturan antes del await: después no se usa `context`.
    final cases = context.read<CaseProvider>();
    final session = context.read<SessionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar la cita?'),
        content: Text('El caso ${c.id} quedará cancelado. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      cases.cancelCase(
        c.id,
        role: UserRole.patient,
        actorName: session.displayName,
        reason: 'Cancelada por el paciente desde la app',
      );
      messenger.showSnackBar(const SnackBar(content: Text('La cita fue cancelada.')));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Tarjeta "Próxima acción": el botón de la acción que le toca al rol, o a quién se espera.
class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.telemedicineCase, required this.action});

  final TelemedicineCase telemedicineCase;
  final NextAction? action;

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final theme = Theme.of(context);
    final step = c.currentStep;
    final next = action;
    final (title, message) = switch (c.status) {
      CaseStatus.completed => ('Proceso completado', 'El caso recorrió los 10 pasos.'),
      CaseStatus.cancelled => ('Solicitud cancelada', 'El caso se canceló en el paso ${step.number}.'),
      _ => ('Próxima acción', next == null ? waitingText(c) : 'Paso ${step.number} de 10: ${step.title}'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            StepBadge(
              step: step,
              size: 40,
              color: c.status == CaseStatus.active ? null : AppColors.forStatus(c.status),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(message, style: theme.textTheme.bodyMedium),
                  if (next != null) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      // Las acciones sobre el caso se apilan; las secciones del rol se abren con `go`.
                      onPressed: () => next.route.startsWith('/caso/') ? context.push(next.route) : context.go(next.route),
                      icon: Icon(next.icon),
                      label: Text(next.label),
                    ),
                  ],
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

- [ ] **Step 5: Ejecutar las pruebas y verificar que pasan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/case_detail
& $flutter analyze
```

Expected:
- `All tests passed!` (7 pruebas);
- `No issues found!`. La pantalla de detalle compila aunque todavía no tiene ruta (eso es la tarea 5).

---

### Task 5: Ingreso, roles y navegación

**Files:**
- Create: `saludconecta/lib/core/widgets/role_switcher_sheet.dart`
- Create: `saludconecta/lib/features/shared/role_shell.dart`, `saludconecta/lib/features/shared/case_list_screen.dart`
- Create: `saludconecta/lib/features/patient/patient_home_screen.dart`
- Create: `saludconecta/lib/features/auth/role_selection_screen.dart`, `patient_login_screen.dart`, `staff_login_screen.dart`
- Modify (reemplazo completo): `saludconecta/lib/features/auth/welcome_screen.dart`, `saludconecta/lib/core/router/app_router.dart`, `saludconecta/lib/main.dart`, `saludconecta/test/app_test.dart`
- Create: `saludconecta/lib/app_dependencies.dart`
- Test: `saludconecta/test/support/app_harness.dart`, `saludconecta/test/features/login_flow_test.dart`, `saludconecta/test/features/case_detail_screen_test.dart`, `saludconecta/test/features/role_switcher_test.dart`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces:
  - **`AppDependencies.create({Clock clock, Duration insuranceDelay, Duration confirmationDelay, String initialLocation})`:**
    - campos `catalog`, `session`, `cases` y `router`;
    - `provide(Widget child) → Widget`, con el `MultiProvider`.
  - **`AppRouter.create({required SessionProvider session, String initialLocation}) → GoRouter`.**
  - **Shell:**
    - `RoleShell({required role, required navigationShell, required destinations})`;
    - `RoleDestination{label, icon, selectedIcon}`.
  - **Pantallas:**
    - `CaseListScreen({required title, required subtitle, required select})`;
    - `PatientHomeScreen()`, que muestra "Hola, {nombre}";
    - `WelcomeScreen()`, `RoleSelectionScreen()`, `PatientLoginScreen()` y `StaffLoginScreen({required role})`;
    - `RoleSwitcherSheet.show(context)`.
  - **Pruebas:**
    - `testDependencies({initialLocation})` y `appWith(dependencies)`;
    - `buildTestApp({initialLocation})`;
    - `testNow`.

- [ ] **Step 1: Escribir las pruebas de la navegación**

Create `saludconecta/test/support/app_harness.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:saludconecta/app.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';

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
```

Replace the whole content of `saludconecta/test/app_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('la app arranca en la bienvenida con el nombre y el lema', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(find.text('SaludConecta'), findsOneWidget);
    expect(find.text('Más acceso, mejor salud'), findsOneWidget);
    expect(find.text('Solicita tu cita por el canal que prefieras'), findsOneWidget);
  });
}
```

Create `saludconecta/test/features/login_flow_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/domain/models/enums.dart';

import '../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('el ingreso como paciente lleva al Inicio', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paciente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('María Fernández'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, María'), findsOneWidget);
  });

  testWidgets('un carnet que no existe muestra un error en el campo', (tester) async {
    await tester.pumpWidget(buildTestApp(initialLocation: AppRoutes.patientLogin));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'XX-000');
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('No encontramos ese carnet. Revisa el número.'), findsOneWidget);
  });

  testWidgets('el personal elige su usuario y llega a su bandeja', (tester) async {
    await tester.pumpWidget(buildTestApp(initialLocation: AppRoutes.staffLogin(UserRole.admission)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Peña'));
    await tester.pumpAndSettle();
    expect(find.text('Bandeja de Admisión'), findsOneWidget);
  });
}
```

Create `saludconecta/test/features/case_detail_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('el paciente ve la próxima acción, la línea de tiempo y puede cancelar', (tester) async {
    final deps = testDependencies();
    final jose = deps.catalog.patientById(SeedIds.jose);
    final pending =
        deps.cases.casesOfPatient(jose.id).firstWhere((c) => c.currentStep == ProcessStep.consentAdmission);
    deps.session.loginPatient(jose);
    deps.router.go(AppRoutes.caseDetail(pending.id));
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    expect(find.text('Caso ${pending.id}'), findsOneWidget);
    expect(find.text('Firmar consentimiento'), findsOneWidget);
    expect(find.text('Línea de tiempo'), findsOneWidget);
    final cancel = find.text('Cancelar cita');
    await tester.scrollUntilVisible(cancel, 400, scrollable: find.byType(Scrollable).first);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();
    expect(deps.cases.caseById(pending.id)!.status, CaseStatus.cancelled);
    expect(find.text('Cancelar cita'), findsNothing);
    // La lista solo construye lo visible: se vuelve arriba para ver la tarjeta de la próxima acción.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text('Solicitud cancelada'), findsWidgets);
  });

  testWidgets('un caso que no existe muestra "Caso no encontrado"', (tester) async {
    final deps = testDependencies(initialLocation: AppRoutes.caseDetail('TM-0000-0000'));
    deps.session.loginDoctor(deps.catalog.doctorById(SeedIds.mendez));
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    expect(find.text('Caso no encontrado'), findsWidgets);
    expect(find.text('Volver al inicio'), findsOneWidget);
  });
}
```

Create `saludconecta/test/features/role_switcher_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/domain/models/enums.dart';

import '../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('"Cambiar de rol" abre la hoja y pasa de Admisión a María', (tester) async {
    await tester.pumpWidget(buildTestApp(initialLocation: AppRoutes.staffLogin(UserRole.admission)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Peña'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cambiar de rol'));
    await tester.pumpAndSettle();
    expect(find.text('Modo demostración: elige quién usa la app.'), findsOneWidget);

    await tester.tap(find.text('María Fernández'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, María'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar las pruebas y verificar que fallan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/app_test.dart test/features/login_flow_test.dart test/features/case_detail_screen_test.dart test/features/role_switcher_test.dart
```

Expected: FAIL. No compila porque `app_dependencies.dart` no existe.

- [ ] **Step 3: Crear el shell, la hoja "Cambiar de rol" y las listas**

Create `saludconecta/lib/core/widgets/role_switcher_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../state/session_provider.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'avatar_image.dart';

/// Hoja "Cambiar de rol" (§6): los 4 roles con sus usuarios de demostración. Un toque cambia la sesión.
class RoleSwitcherSheet extends StatelessWidget {
  const RoleSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => const RoleSwitcherSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogRepository>();
    final session = context.read<SessionProvider>();
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final admission = catalog.staffFor(Actor.admission);
    final billing = catalog.staffFor(Actor.billing);

    // Cierra la hoja, cambia la sesión y abre el inicio del nuevo rol.
    void switchTo(UserRole role, VoidCallback login) {
      navigator.pop();
      login();
      router.go(AppRoutes.home(role));
    }

    Widget person(String name, String subtitle, String? avatar, UserRole role, VoidCallback login) => ListTile(
          leading: AvatarImage(name: name, asset: avatar, size: 40),
          title: Text(name),
          subtitle: Text(subtitle),
          onTap: () => switchTo(role, login),
        );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            title: Text('Cambiar de rol', style: Theme.of(context).textTheme.titleLarge),
            subtitle: const Text('Modo demostración: elige quién usa la app.'),
          ),
          const _RoleHeader(role: UserRole.patient),
          for (final p in catalog.demoPatients)
            person(
              p.fullName,
              'Carnet ${p.affiliation.affiliateNumber}',
              p.avatarAsset,
              UserRole.patient,
              () => session.loginPatient(p),
            ),
          const _RoleHeader(role: UserRole.admission),
          person(admission.fullName, 'Admisión', admission.avatarAsset, UserRole.admission, () {
            session.loginStaff(admission);
          }),
          const _RoleHeader(role: UserRole.doctor),
          for (final d in catalog.doctors)
            person(d.displayName, d.specialty.label, d.avatarAsset, UserRole.doctor, () => session.loginDoctor(d)),
          const _RoleHeader(role: UserRole.billing),
          person(billing.fullName, 'Facturación', billing.avatarAsset, UserRole.billing, () {
            session.loginStaff(billing);
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              navigator.pop();
              session.logout();
              router.go(AppRoutes.login);
            },
          ),
        ],
      ),
    );
  }
}

class _RoleHeader extends StatelessWidget {
  const _RoleHeader({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forActor(role.actor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(AppIcons.role(role), color: color, size: 20),
          const SizedBox(width: 8),
          Text(role.label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
```

Create `saludconecta/lib/features/shared/role_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/constants/app_info.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/role_switcher_sheet.dart';
import '../../domain/models/enums.dart';
import '../../state/session_provider.dart';

/// Una pestaña de la navegación de un rol.
class RoleDestination {
  const RoleDestination({required this.label, required this.icon, required this.selectedIcon});

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Estructura común de cada rol (§6): barra superior con "Diagrama del proceso", "Acerca de" y
/// "Cambiar de rol"; navegación inferior por debajo de 800 px y lateral desde 800 px.
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.role, required this.navigationShell, required this.destinations});

  static const wideBreakpoint = 800.0;

  final UserRole role;
  final StatefulNavigationShell navigationShell;
  final List<RoleDestination> destinations;

  /// Cambia de pestaña; si ya estaba en ella, vuelve a su pantalla inicial.
  void _select(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final theme = Theme.of(context);
    final appBar = AppBar(
      title: Row(
        children: [
          const AppIllustration(AppIllustrations.logo, width: 32, height: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(AppInfo.appName),
                Text(
                  '${role.label} · ${session.displayName}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Diagrama del proceso',
          icon: const Icon(Icons.account_tree_outlined),
          onPressed: () => context.push(AppRoutes.process),
        ),
        IconButton(
          tooltip: 'Acerca de',
          icon: const Icon(Icons.info_outline),
          onPressed: () => context.push(AppRoutes.about),
        ),
        IconButton(
          tooltip: 'Cambiar de rol',
          icon: const Icon(Icons.switch_account_outlined),
          onPressed: () => RoleSwitcherSheet.show(context),
        ),
      ],
    );
    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _select,
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}
```

Create `saludconecta/lib/features/shared/case_list_screen.dart`:

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

/// Lista de casos de una bandeja (versión de la etapa 4). Las etapas 6 a 8 la reemplazan por las
/// pantallas de cada rol, con filtros y acciones.
class CaseListScreen extends StatelessWidget {
  const CaseListScreen({super.key, required this.title, required this.subtitle, required this.select});

  final String title;
  final String subtitle;

  /// Qué casos mostrar, según el estado de los casos y la sesión.
  final List<TelemedicineCase> Function(CaseProvider cases, SessionProvider session) select;

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final session = context.watch<SessionProvider>();
    final items = select(cases, session);
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return EmptyState(illustration: AppIllustrations.emptyCases, title: title, message: 'No hay casos. $subtitle.');
    }
    return PageBody(
      child: ListView.separated(
        itemCount: items.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                Text('${items.length} casos · $subtitle', style: theme.textTheme.bodyMedium),
              ],
            );
          }
          final c = items[index - 1];
          return CaseCard(
            telemedicineCase: c,
            onTap: () => context.push(AppRoutes.caseDetail(c.id)),
            trailing: Text(
              'Hace ${Formatters.duration(cases.now.difference(c.updatedAt))}',
              style: theme.textTheme.labelSmall,
            ),
          );
        },
      ),
    );
  }
}
```

Create `saludconecta/lib/features/patient/patient_home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/case_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_body.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';

/// Inicio del paciente (versión de la etapa 4): saludo y sus citas.
/// La etapa 5 agrega los avisos, los accesos rápidos y los consejos de salud.
class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<SessionProvider>().currentPatient;
    if (patient == null) return const SizedBox.shrink();
    final items = context.watch<CaseProvider>().casesOfPatient(patient.id);
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
            ],
          ),
          const SizedBox(height: 20),
          Text('Tus citas', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const EmptyState(
              illustration: AppIllustrations.emptyCases,
              title: 'Aún no tienes citas',
              message: 'Cuando solicites una cita aparecerá aquí.',
            )
          else
            for (final c in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CaseCard(
                  telemedicineCase: c,
                  showPatient: false,
                  onTap: () => context.push(AppRoutes.caseDetail(c.id)),
                ),
              ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Crear la bienvenida, la selección de rol y los ingresos**

Replace the whole content of `saludconecta/lib/features/auth/welcome_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/constants/app_info.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_illustration.dart';

/// Bienvenida (§6): 3 páginas con ilustración, indicador de puntos y los botones "Omitir" y "Comenzar".
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _pages = [
    (
      AppIllustrations.onboardingRequest,
      'Solicita tu cita por el canal que prefieras',
      'Celular, correo, WhatsApp, portal web o teléfono: tú eliges cómo pedir tu consulta.',
    ),
    (
      AppIllustrations.onboardingConsult,
      'Consulta con tu médico desde casa',
      'Te atiende un médico general o especialista por MS Teams, Zoom o Google Meet.',
    ),
    (
      AppIllustrations.onboardingFollowUp,
      'Recibe tu receta y seguimiento',
      'Tu receta con código QR, tus órdenes y el seguimiento de tu atención, en la app.',
    ),
  ];

  final _controller = PageController();
  var _page = 0;

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => context.go(AppRoutes.login);

  void _next() => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      const AppIllustration(AppIllustrations.logo, width: 40, height: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppInfo.appName, style: theme.textTheme.titleLarge),
                            Text(
                              AppInfo.slogan,
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ),
                      if (!_isLast) TextButton(onPressed: _finish, child: const Text('Omitir')),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (page) => setState(() => _page = page),
                    children: [
                      for (final (asset, title, body) in _pages)
                        _OnboardingPage(asset: asset, title: title, body: body),
                    ],
                  ),
                ),
                _Dots(count: _pages.length, current: _page),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLast ? _finish : _next,
                      child: Text(_isLast ? 'Comenzar' : 'Siguiente'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.asset, required this.title, required this.body});

  final String asset;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(child: AppIllustration(asset, semanticLabel: title)),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Indicador de puntos: el de la página actual es más ancho.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? AppColors.primary : AppColors.pending.withOpacity(0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
```

Create `saludconecta/lib/features/auth/role_selection_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/page_body.dart';
import '../../domain/models/enums.dart';

/// Selección de rol (§6): 4 tarjetas ilustradas. Es una demostración: no hay contraseñas.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const _descriptions = {
    UserRole.patient: 'Pide citas, firma tu consentimiento, entra a la videollamada y revisa tu receta.',
    UserRole.admission: 'Registra solicitudes, valida el seguro, agenda las citas y da seguimiento.',
    UserRole.doctor: 'Atiende tus citas por videollamada, escribe notas clínicas y emite resultados.',
    UserRole.billing: 'Factura, envía reclamaciones al seguro, audita y cierra los casos.',
  };

  void _open(BuildContext context, UserRole role) =>
      context.go(role == UserRole.patient ? AppRoutes.patientLogin : AppRoutes.staffLogin(role));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿Quién usa la app?')),
      body: PageBody(
        child: ListView(
          children: [
            Card(
              color: AppColors.current.withOpacity(0.12),
              child: const ListTile(
                leading: Icon(Icons.info_outline, color: AppColors.currentText),
                title: Text('Modo demostración: sin contraseñas'),
                subtitle: Text('Elige un rol y un usuario de prueba. Todos los datos son ficticios.'),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 2 : 1;
                final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final role in UserRole.values)
                      SizedBox(
                        width: width,
                        child: _RoleCard(
                          role: role,
                          description: _descriptions[role]!,
                          onTap: () => _open(context, role),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.description, required this.onTap});

  final UserRole role;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.forActor(role.actor);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AppIllustration(AppIllustrations.forRole(role), width: 110, height: 88),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(AppIcons.role(role), color: color, size: 20),
                        const SizedBox(width: 6),
                        // Flexible: en pantallas angostas el título se recorta en vez de desbordar.
                        Flexible(
                          child: Text(
                            role.label,
                            style: theme.textTheme.titleLarge?.copyWith(color: color),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/features/auth/patient_login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../state/session_provider.dart';

/// Ingreso del paciente con su número de carnet. Los chips rellenan el campo con los 6 pacientes demo.
class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({super.key});

  @override
  State<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Escribe tu número de carnet.';
    if (context.read<CatalogRepository>().patientByAffiliateNumber(text) == null) {
      return 'No encontramos ese carnet. Revisa el número.';
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final patient = context.read<CatalogRepository>().patientByAffiliateNumber(_number.text);
    if (patient == null) return;
    final router = GoRouter.of(context);
    context.read<SessionProvider>().loginPatient(patient);
    router.go(AppRoutes.patientHome);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogRepository>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ingreso de paciente')),
      body: PageBody(
        child: ListView(
          children: [
            const AppIllustration(AppIllustrations.rolePatient, height: 130),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _number,
                decoration: const InputDecoration(
                  labelText: 'Número de carnet de seguro',
                  hintText: 'Ej.: SP-100245',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: _validate,
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Pacientes de demostración', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in catalog.demoPatients)
                  ActionChip(
                    avatar: AvatarImage(name: p.fullName, asset: p.avatarAsset, size: 24),
                    label: Text(p.fullName),
                    onPressed: () {
                      _number.text = p.affiliation.affiliateNumber;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.login), label: const Text('Ingresar')),
          ],
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/features/auth/staff_login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../state/session_provider.dart';

/// Ingreso del personal (§6): se elige el usuario de demostración del rol (7 médicos para Médico).
class StaffLoginScreen extends StatelessWidget {
  const StaffLoginScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogRepository>();
    final session = context.read<SessionProvider>();
    final router = GoRouter.of(context);

    void enter(VoidCallback login) {
      login();
      router.go(AppRoutes.home(role));
    }

    final users = <Widget>[
      if (role == UserRole.doctor)
        for (final d in catalog.doctors)
          _UserTile(
            name: d.displayName,
            subtitle: '${d.specialty.label} · Exequátur ${d.exequatur}',
            avatar: d.avatarAsset,
            onTap: () => enter(() => session.loginDoctor(d)),
          )
      else
        for (final s in catalog.staff.where((s) => s.actor == role.actor))
          _UserTile(
            name: s.fullName,
            subtitle: role.label,
            avatar: s.avatarAsset,
            onTap: () => enter(() => session.loginStaff(s)),
          ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('Ingreso de ${role.label}')),
      body: PageBody(
        child: ListView(
          children: [
            AppIllustration(AppIllustrations.forRole(role), height: 130),
            const SizedBox(height: 12),
            Text(
              'Elige tu usuario de demostración',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ...users,
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.name, required this.subtitle, required this.onTap, this.avatar});

  final String name;
  final String subtitle;
  final String? avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: AvatarImage(name: name, asset: avatar, size: 44),
          title: Text(name),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Crear el router completo, la raíz de composición y el arranque**

Replace the whole content of `saludconecta/lib/core/router/app_router.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/enums.dart';
import '../../features/auth/patient_login_screen.dart';
import '../../features/auth/role_selection_screen.dart';
import '../../features/auth/staff_login_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/patient/patient_home_screen.dart';
import '../../features/shared/case_detail/case_detail_screen.dart';
import '../../features/shared/case_list_screen.dart';
import '../../features/shared/not_found_screen.dart';
import '../../features/shared/role_shell.dart';
import '../../state/session_provider.dart';
import '../widgets/coming_soon_screen.dart';
import 'app_routes.dart';
import 'route_guard.dart';

/// Rutas de la app (§6 del spec) con `redirect` por rol. Lo que se construye en etapas posteriores
/// apunta por ahora a `ComingSoonScreen`; cada etapa reemplaza su pantalla aquí.
class AppRouter {
  const AppRouter._();

  static GoRouter create({required SessionProvider session, String initialLocation = AppRoutes.welcome}) {
    return GoRouter(
      initialLocation: initialLocation,
      // Cuando cambia la sesión, go_router vuelve a evaluar el redirect.
      refreshListenable: session,
      redirect: (context, state) => RouteGuard.redirect(state.uri.path, session.role),
      errorBuilder: (context, state) => const NotFoundScreen(),
      routes: [
        GoRoute(path: AppRoutes.welcome, builder: (context, state) => const WelcomeScreen()),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const RoleSelectionScreen(),
          routes: [
            GoRoute(path: 'paciente', builder: (context, state) => const PatientLoginScreen()),
            GoRoute(
              path: 'personal/:rol',
              builder: (context, state) {
                final role = UserRole.fromSlug(state.pathParameters['rol']!);
                if (role == null || role == UserRole.patient) return const NotFoundScreen();
                return StaffLoginScreen(role: role);
              },
            ),
          ],
        ),
        _shell(UserRole.patient, [
          _Tab(AppRoutes.patientHome, 'Inicio', Icons.home_outlined, Icons.home,
              (context, state) => const PatientHomeScreen()),
          _Tab(AppRoutes.patientAppointments, 'Mis citas', Icons.event_note_outlined, Icons.event_note,
              (context, state) => const ComingSoonScreen(title: 'Mis citas', stage: 5, inShell: true)),
          _Tab(AppRoutes.patientServices, 'Servicios', Icons.medical_services_outlined, Icons.medical_services,
              (context, state) => const ComingSoonScreen(title: 'Servicios', stage: 5, inShell: true)),
          _Tab(AppRoutes.patientProfile, 'Perfil', Icons.person_outline, Icons.person,
              (context, state) => const ComingSoonScreen(title: 'Perfil', stage: 5, inShell: true)),
        ]),
        GoRoute(
          path: AppRoutes.requestAppointmentPath,
          builder: (context, state) => const ComingSoonScreen(title: 'Solicitar cita', stage: 5),
        ),
        _shell(UserRole.admission, [
          _Tab(
            AppRoutes.admissionInbox,
            'Bandeja',
            Icons.inbox_outlined,
            Icons.inbox,
            (context, state) => CaseListScreen(
              title: 'Bandeja de Admisión',
              subtitle: 'Solicitudes con los pasos 2 a 5 pendientes',
              select: (cases, session) => cases.admissionInbox(),
            ),
          ),
          _Tab(AppRoutes.admissionAgenda, 'Agenda', Icons.calendar_month_outlined, Icons.calendar_month,
              (context, state) => const ComingSoonScreen(title: 'Agenda', stage: 6, inShell: true)),
          _Tab(
            AppRoutes.admissionFollowUp,
            'Seguimiento',
            Icons.call_outlined,
            Icons.call,
            (context, state) => CaseListScreen(
              title: 'Seguimiento',
              subtitle: 'Casos con el paso 10 pendiente',
              select: (cases, session) => cases.followUpCases(),
            ),
          ),
          _Tab(AppRoutes.admissionIndicators, 'Indicadores', Icons.insights_outlined, Icons.insights,
              (context, state) => const ComingSoonScreen(title: 'Indicadores', stage: 9, inShell: true)),
        ]),
        _shell(UserRole.doctor, [
          _Tab(
            AppRoutes.doctorAgenda,
            'Agenda',
            Icons.event_available_outlined,
            Icons.event_available,
            (context, state) => CaseListScreen(
              title: 'Mi agenda',
              subtitle: 'Citas con los pasos 6 a 8 pendientes',
              select: (cases, session) => cases.doctorAgenda(session.currentDoctor?.id ?? ''),
            ),
          ),
          _Tab(AppRoutes.doctorIndicators, 'Indicadores', Icons.insights_outlined, Icons.insights,
              (context, state) => const ComingSoonScreen(title: 'Indicadores', stage: 9, inShell: true)),
        ]),
        _shell(UserRole.billing, [
          _Tab(
            AppRoutes.billingPending,
            'Pendientes',
            Icons.pending_actions_outlined,
            Icons.pending_actions,
            (context, state) => CaseListScreen(
              title: 'Pendientes de cierre',
              subtitle: 'Casos con el paso 9 pendiente',
              select: (cases, session) => cases.billingInbox(),
            ),
          ),
          _Tab(AppRoutes.billingClaims, 'Reclamaciones', Icons.receipt_long_outlined, Icons.receipt_long,
              (context, state) => const ComingSoonScreen(title: 'Reclamaciones', stage: 8, inShell: true)),
          _Tab(AppRoutes.billingIndicators, 'Indicadores', Icons.insights_outlined, Icons.insights,
              (context, state) => const ComingSoonScreen(title: 'Indicadores', stage: 9, inShell: true)),
        ]),
        GoRoute(
          path: '/caso/:id',
          builder: (context, state) => CaseDetailScreen(caseId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'diagrama',
              builder: (context, state) => const ComingSoonScreen(title: 'Diagrama del caso', stage: 10),
            ),
            for (final action in CaseAction.values)
              GoRoute(path: action.segment, builder: (context, state) => _pendingAction(action)),
          ],
        ),
        GoRoute(
          path: AppRoutes.process,
          builder: (context, state) => const ComingSoonScreen(title: 'Diagramas del proceso', stage: 10),
        ),
        GoRoute(
          path: AppRoutes.about,
          builder: (context, state) => const ComingSoonScreen(title: 'Acerca de', stage: 10),
        ),
      ],
    );
  }

  /// Pantalla provisional de cada acción sobre un caso, hasta la etapa que la construye.
  static Widget _pendingAction(CaseAction action) => switch (action) {
        CaseAction.consent => const ComingSoonScreen(title: 'Consentimiento informado', stage: 5),
        CaseAction.waitingRoom => const ComingSoonScreen(title: 'Sala de espera', stage: 5),
        CaseAction.videoCall => const ComingSoonScreen(title: 'Videollamada', stage: 5),
        CaseAction.results => const ComingSoonScreen(title: 'Resultados', stage: 5),
        CaseAction.survey => const ComingSoonScreen(title: 'Encuesta de satisfacción', stage: 5),
        CaseAction.process => const ComingSoonScreen(title: 'Procesar solicitud', stage: 6),
        CaseAction.consultation => const ComingSoonScreen(title: 'Consulta', stage: 7),
        CaseAction.issueResults => const ComingSoonScreen(title: 'Emitir resultados', stage: 7),
        CaseAction.closure => const ComingSoonScreen(title: 'Cierre administrativo', stage: 8),
      };

  /// Shell de un rol: una rama por pestaña (`StatefulShellRoute.indexedStack` conserva cada pestaña).
  static StatefulShellRoute _shell(UserRole role, List<_Tab> tabs) {
    return StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => RoleShell(
        role: role,
        navigationShell: navigationShell,
        destinations: [for (final tab in tabs) tab.destination],
      ),
      branches: [
        for (final tab in tabs) StatefulShellBranch(routes: [GoRoute(path: tab.path, builder: tab.builder)]),
      ],
    );
  }
}

/// Una pestaña de un shell: su ruta, su ícono y su pantalla.
class _Tab {
  const _Tab(this.path, this.label, this.icon, this.selectedIcon, this.builder);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final GoRouterWidgetBuilder builder;

  RoleDestination get destination => RoleDestination(label: label, icon: icon, selectedIcon: selectedIcon);
}
```

Create `saludconecta/lib/app_dependencies.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'data/gateways/confirmation_gateway.dart';
import 'data/gateways/insurance_gateway.dart';
import 'data/repositories/case_repository.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/seed/seed_cases.dart';
import 'data/seed/seed_catalog.dart';
import 'domain/services/clock.dart';
import 'state/case_provider.dart';
import 'state/session_provider.dart';

/// Raíz de composición: crea los datos semilla, los gateways simulados, el estado y las rutas,
/// y los publica para toda la app con `MultiProvider`.
class AppDependencies {
  AppDependencies._({required this.catalog, required this.session, required this.cases, required this.router});

  factory AppDependencies.create({
    Clock clock = DateTime.now,
    Duration insuranceDelay = const Duration(milliseconds: 1500),
    Duration confirmationDelay = const Duration(seconds: 1),
    String initialLocation = AppRoutes.welcome,
  }) {
    final catalog = SeedCatalog.repository();
    final session = SessionProvider(clock: clock);
    final cases = CaseProvider(
      catalog: catalog,
      repository: InMemoryCaseRepository(SeedCases.generate(now: clock(), catalog: catalog)),
      insurance: SimulatedInsuranceGateway(catalog: catalog, clock: clock, delay: insuranceDelay),
      confirmation: SimulatedConfirmationGateway(delay: confirmationDelay),
      clock: clock,
    );
    final router = AppRouter.create(session: session, initialLocation: initialLocation);
    return AppDependencies._(catalog: catalog, session: session, cases: cases, router: router);
  }

  final CatalogRepository catalog;
  final SessionProvider session;
  final CaseProvider cases;
  final GoRouter router;

  /// Publica las dependencias con Provider: las pantallas las leen con `context.watch` y `context.read`.
  Widget provide(Widget child) => MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<SessionProvider>.value(value: session),
          ChangeNotifierProvider<CaseProvider>.value(value: cases),
        ],
        child: child,
      );
}
```

Replace the whole content of `saludconecta/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carga los nombres de días y meses en español para `intl`.
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';
  // Raíz de composición: datos semilla, gateways simulados, providers (MultiProvider) y rutas.
  final dependencies = AppDependencies.create();
  runApp(dependencies.provide(SaludConectaApp(router: dependencies.router)));
}
```

- [ ] **Step 6: Ejecutar las pruebas y verificar que pasan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/app_test.dart test/features/login_flow_test.dart test/features/case_detail_screen_test.dart test/features/role_switcher_test.dart
```

Expected: `All tests passed!` (7 pruebas).

---

### Task 6: Verificación y commit de la etapa

**Files:**
- Modify: `docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md` (enlace al plan y estado de la etapa 4)

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
- `All tests passed!` (unas 145 pruebas);
- `No issues found!`.

- [ ] **Step 2: Recorrido en la web**

Con `preview_start` (`saludconecta-web`), esperar unos 20 s, recargar y recorrer la app capturando cada pantalla:

1. **Bienvenida:** la ilustración y "Solicita tu cita…". Avanzar con "Siguiente".
2. **"Omitir":** lleva a la selección de rol, con 4 tarjetas ilustradas y el aviso de modo demostración.
3. **Admisión → Ana Peña:** lleva a la "Bandeja de Admisión", con 5 casos y el tiempo de espera de cada uno.
4. **Abrir el caso de Pedro Almonte:**
   - la próxima acción es "Procesar solicitud";
   - la línea de tiempo muestra los pasos 1 y 2 en verde y el 3 en ámbar.
5. **"Cambiar de rol" → María Fernández:** lleva a "Hola, María", con sus 4 citas completadas.
6. **"Cambiar de rol" → Dr. Carlos Méndez:** lleva a "Mi agenda", con 3 citas (pasos 6, 7 y 8).

Expected: cada pantalla se ve completa y la consola del navegador no muestra errores nuevos.

Si el panel del navegador está oculto, la página corre en segundo plano y las animaciones se frenan: una hoja o una transición puede tardar en verse. En ese caso hay que esperar 1 o 2 s y volver a capturar, sin repetir el clic. La prueba `role_switcher_test.dart` confirma que la hoja abre.

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
& $adb pull /sdcard/saludconecta.png <scratchpad>\saludconecta-etapa4.png
```

Expected: la captura muestra la bienvenida, con la ilustración de los canales y el botón "Siguiente".

- [ ] **Step 4: Actualizar la hoja de ruta**

En `docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md`, en la fila de la etapa 4:
- cambiar `al cerrar la 3` por `[04-estado-y-shells](2026-11-09-saludconecta-04-estado-y-shells.md)`;
- cambiar el estado `pendiente` por `hecha`.

- [ ] **Step 5: Commit de la etapa 4**

```powershell
$repo = 'C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial'
git -C $repo add saludconecta docs/superpowers/plans
git -C $repo status --short
git -C $repo commit -m "feat: estado, ingreso y shells de SaludConecta (etapa 4)" -m "SessionProvider y CaseProvider con las 16 acciones del proceso, rutas con redirect por rol, bienvenida, ingreso de paciente y personal, cambio de rol, shells por rol, detalle del caso con línea de tiempo y raíz de composición. 145 pruebas en verde."
git -C $repo log --oneline -3
```

Expected: el commit tiene como autor `FDLG301201`.

Siguiente paso: escribir el plan de la etapa 5, `2026-11-09-saludconecta-05-flujo-paciente.md`.
