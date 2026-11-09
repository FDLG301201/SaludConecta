# SaludConecta · Etapa 2: Dominio y datos — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar en Dart puro los modelos, las reglas y transiciones del proceso, las calculadoras, los gateways simulados y los datos semilla, todo con pruebas unitarias.

**Architecture:**

- **`domain/`:** contiene `models/`, `process/` y `services/`, y no depende de Flutter.
  - `ProcessRules` dice qué está permitido.
  - `CaseWorkflow` aplica cada transición y devuelve un caso nuevo con su evento.
- **`data/`:** contiene `repositories/`, `gateways/` y `seed/`.
  - Implementa los repositorios en memoria y los gateways simulados.
  - Genera la semilla de forma determinista con `Random(2026)`, usando el mismo `CaseWorkflow`.

**Tech Stack:** Dart 3.3 (enums con campos, `switch` de expresiones, *records*), `dart:math` y `flutter_test`.

**Hoja de ruta:** [00-hoja-de-ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md) (incluye los refinamientos respecto al spec) · **Spec:** §4, §13

## Global Constraints

Las de la [hoja de ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md#global-constraints). Las más relevantes para esta etapa:

- **Dart puro:** `lib/domain/**` y `lib/data/**` no importan `package:flutter`. Sí pueden importar `dart:math`.
- **Modelos:**
  - inmutables, con campos `final` y constructores `const` cuando se pueda;
  - los montos son `int`, en pesos dominicanos.
- **Mensajes:** los de `ProcessException` están en español, porque la UI los muestra tal cual en un `SnackBar`.
- **Semilla:** determinista; el mismo `now` produce los mismos casos.
  - En la app, `now = DateTime.now()`.
  - En las pruebas, `now` es una fecha fija.
- **Calidad:** `flutter analyze` sin avisos. Las pruebas importan con `package:saludconecta/...`.
- **Git:** un solo commit al final de la etapa (tarea 7).

## Archivos de la etapa

| Archivo | Responsabilidad |
|---|---|
| `lib/domain/models/enums.dart` | Enumeraciones con etiqueta en español (`UserRole`, `Actor`, `CaseStatus`, `RequestChannel`, `VideoPlatform`, `ServiceGroup`, `Specialty`, `ClaimStatus`, `PaymentMethod`, `OrderType`, `Gender`, `EventKind`) |
| `lib/domain/models/people.dart` | `InsuranceAffiliation`, `Patient`, `WorkHours`, `Doctor`, `StaffMember` |
| `lib/domain/models/catalog.dart` | `Insurer` (con `coverageFor`) y `MedicalService` |
| `lib/domain/models/case_records.dart` | Datos que agrega cada paso: recepción, seguro, cita, confirmación, consentimiento, consulta, resultados, factura y seguimiento |
| `lib/domain/models/process_event.dart` | `ProcessEvent` (evento de la línea de tiempo) |
| `lib/domain/models/telemedicine_case.dart` | `TelemedicineCase` + `copyWith` + pasos completados |
| `lib/domain/process/process_step.dart` | Los 10 pasos con número, título, descripción, actor y dueños |
| `lib/domain/process/process_exception.dart` | Error de negocio |
| `lib/domain/process/process_rules.dart` | `ProcessRules` + `AssistAction` |
| `lib/domain/process/case_workflow.dart` | Las transiciones del proceso |
| `lib/domain/services/clock.dart` | `typedef Clock` |
| `lib/domain/services/case_codes.dart` | Autorización, reclamación, código de receta y enlace de la videollamada |
| `lib/domain/services/billing_calculator.dart` | Factura, copago, auditoría y regla de cierre |
| `lib/domain/services/schedule_service.dart` | Turnos y días disponibles |
| `lib/domain/services/stats_calculator.dart` | Datos de las gráficas |
| `lib/domain/services/notification_builder.dart` | Avisos para el paciente |
| `lib/data/repositories/catalog_repository.dart` | `CatalogRepository` + `InMemoryCatalogRepository` |
| `lib/data/repositories/case_repository.dart` | `CaseRepository` + `InMemoryCaseRepository` |
| `lib/data/gateways/insurance_gateway.dart` | `InsuranceGateway` + `SimulatedInsuranceGateway` |
| `lib/data/gateways/confirmation_gateway.dart` | `ConfirmationGateway` + `SimulatedConfirmationGateway` |
| `lib/data/seed/seed_catalog.dart` | `SeedIds` + `SeedCatalog` (aseguradoras, 24 servicios, médicos, personal, pacientes) |
| `lib/data/seed/seed_cases.dart` | `SeedCases.generate`: ~200 históricos y 10 casos en vivo |
| `test/support/fixtures.dart` | Datos y ayudantes compartidos por las pruebas |
| `test/domain/*_test.dart`, `test/data/*_test.dart` | Pruebas unitarias |

---

### Task 1: Modelos y pasos del proceso

**Files:**
- Create: `saludconecta/lib/domain/models/enums.dart`, `saludconecta/lib/domain/models/people.dart`, `saludconecta/lib/domain/models/catalog.dart`, `saludconecta/lib/domain/models/case_records.dart`, `saludconecta/lib/domain/models/process_event.dart`, `saludconecta/lib/domain/models/telemedicine_case.dart`, `saludconecta/lib/domain/process/process_step.dart`, `saludconecta/lib/domain/process/process_exception.dart`
- Test: `saludconecta/test/domain/models_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces (todo con estas firmas exactas):
  - Enums con `label` (`String`):
    - `UserRole` también tiene `slug`, `actor` y `static fromSlug(String) → UserRole?`.
    - `Actor` también tiene `description`.
    - `CaseStatus` también tiene `isOpen`.
    - `RequestChannel`, `VideoPlatform`, `ServiceGroup`, `Specialty`, `ClaimStatus`, `PaymentMethod`, `OrderType` y `Gender` solo tienen `label`.
    - `EventKind` no tiene `label`. Sus valores son `completed`, `rejected`, `cancelled`, `started`, `claim`, `payment` y `call`.
  - `ProcessStep`:
    - campos `number`, `title`, `description`, `actor` y `owners` (`Set<UserRole>`);
    - getters `next` y `previous`;
    - `isOwnedBy(UserRole)` y `static fromNumber(int)`.
  - `ProcessException(String message)`.
  - Personas:
    - `InsuranceAffiliation{insurerId, plan, affiliateNumber, active}`;
    - `Patient{id, fullName, cedula, birthDate, gender, phone, email, affiliation, avatarAsset?}`, con `firstName` y `ageOn(DateTime)`;
    - `WorkHours(startHour, endHour)`;
    - `Doctor{id, title, fullName, specialty, exequatur, avatarAsset, schedule: Map<int, WorkHours>}`, con `displayName` y `workDays`;
    - `StaffMember{id, fullName, actor, phone?, avatarAsset?}`.
  - Catálogo:
    - `Insurer{id, name, symbolAsset, planCoverage}`, con `coverageFor(plan, service)`;
    - `MedicalService{id, name, group, description, iconKey, requestable, specialty?, fee?, reducedCoverage, relatedStep?}`.
  - Datos por paso, en `case_records.dart`:
    - `ReceptionData`, `InsuranceValidation`, `Appointment`, `Confirmation`;
    - `SignaturePoint`, `ConsentRecord`;
    - `ClinicalNotes` (con `isComplete`), `ConsultationRecord`;
    - `PrescriptionItem`, `Prescription`, `MedicalOrder`, `Referral`, `ConsultationResults` (con `ordersOf(OrderType)`);
    - `Invoice`, `Payment`, `BillingRecord` (con `copyWith`);
    - `FollowUpCall`, `Survey`, `FollowUpRecord` (con `copyWith`).
  - `ProcessEvent{step, actor, actorName, at, title, detail = '', kind = EventKind.completed}`, con el getter `completesStep`.
  - `TelemedicineCase`:
    - los campos del §4 del spec y `copyWith`;
    - `completedSteps`, `isStepCompleted(step)`, `completedAt(step) → DateTime?`;
    - `isOpen` y `updatedAt`.

- [ ] **Step 1: Escribir la prueba de los modelos**

Create `saludconecta/test/domain/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/domain/models/case_records.dart';
import 'package:saludconecta/domain/models/catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/models/people.dart';
import 'package:saludconecta/domain/models/process_event.dart';
import 'package:saludconecta/domain/models/telemedicine_case.dart';
import 'package:saludconecta/domain/process/process_step.dart';

void main() {
  test('los 10 pasos están en orden y conocen su siguiente y su anterior', () {
    expect(ProcessStep.values, hasLength(10));
    expect(ProcessStep.fromNumber(3), ProcessStep.insuranceValidation);
    expect(ProcessStep.reception.next, ProcessStep.insuranceValidation);
    expect(ProcessStep.reception.previous, ProcessStep.requestAppointment);
    expect(ProcessStep.followUp.next, isNull);
    expect(ProcessStep.consultation.isOwnedBy(UserRole.doctor), isTrue);
    expect(ProcessStep.followUp.isOwnedBy(UserRole.patient), isTrue);
    expect(ProcessStep.followUp.actor, Actor.admission);
  });

  test('roles por segmento de URL', () {
    expect(UserRole.fromSlug('admision'), UserRole.admission);
    expect(UserRole.fromSlug('otro'), isNull);
    expect(UserRole.billing.actor, Actor.billing);
  });

  test('cobertura del plan, con y sin cobertura reducida', () {
    const insurer = Insurer(id: 'x', name: 'ARS X', symbolAsset: '', planCoverage: {'Plus': 80});
    const normal = MedicalService(id: 'a', name: 'A', group: ServiceGroup.clinical, description: '', iconKey: '');
    const reduced = MedicalService(
      id: 'b',
      name: 'B',
      group: ServiceGroup.clinical,
      description: '',
      iconKey: '',
      reducedCoverage: true,
    );
    expect(insurer.coverageFor('Plus', normal), 80);
    expect(insurer.coverageFor('Plus', reduced), 60);
    expect(insurer.coverageFor('Otro', normal), 0);
  });

  test('edad cumplida y primer nombre', () {
    final patient = Patient(
      id: 'p',
      fullName: 'María Fernández',
      cedula: '',
      birthDate: DateTime(1990, 3, 14),
      gender: Gender.female,
      phone: '',
      email: '',
      affiliation: const InsuranceAffiliation(insurerId: 'x', plan: 'Plus', affiliateNumber: 'SP-1', active: true),
    );
    expect(patient.ageOn(DateTime(2026, 3, 13)), 35);
    expect(patient.ageOn(DateTime(2026, 3, 14)), 36);
    expect(patient.firstName, 'María');
  });

  test('copyWith conserva lo demás y los pasos completados salen de los eventos', () {
    final at = DateTime(2026, 11, 9, 9);
    final c = TelemedicineCase(
      id: 'TM-2026-0001',
      patientId: 'p',
      serviceId: 's',
      channel: RequestChannel.whatsapp,
      reason: 'Motivo de prueba',
      preferredDate: at,
      createdAt: at,
      currentStep: ProcessStep.reception,
      status: CaseStatus.active,
      events: [
        ProcessEvent(step: ProcessStep.requestAppointment, actor: Actor.patient, actorName: 'María', at: at, title: 'Solicitud'),
      ],
    );
    final updated = c.copyWith(
      currentStep: ProcessStep.insuranceValidation,
      reception: const ReceptionData(registeredBy: 'Ana Peña'),
    );
    expect(updated.id, c.id);
    expect(updated.reason, 'Motivo de prueba');
    expect(updated.currentStep, ProcessStep.insuranceValidation);
    expect(updated.reception!.registeredBy, 'Ana Peña');
    expect(c.reception, isNull, reason: 'el original no cambia');
    expect(c.completedSteps, {ProcessStep.requestAppointment});
    expect(c.completedAt(ProcessStep.requestAppointment), at);
    expect(c.completedAt(ProcessStep.reception), isNull);
    expect(c.isOpen, isTrue);
    expect(c.updatedAt, at);
  });

  test('solo los eventos "completed" completan el paso', () {
    final at = DateTime(2026, 11, 9);
    final call = ProcessEvent(
      step: ProcessStep.followUp,
      actor: Actor.admission,
      actorName: 'Ana Peña',
      at: at,
      title: 'Llamada',
      kind: EventKind.call,
    );
    expect(call.completesStep, isFalse);
    expect(CaseStatus.insuranceRejected.isOpen, isTrue);
    expect(CaseStatus.cancelled.isOpen, isFalse);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/domain/models_test.dart
```

Expected: FAIL. No compila porque no existen los archivos de `lib/domain/`.

- [ ] **Step 3: Crear los enums**

Create `saludconecta/lib/domain/models/enums.dart`:

```dart
// Enumeraciones del dominio. Son Dart puro (no importan Flutter):
// cada valor trae su etiqueta en español para mostrarla en la interfaz.

/// Roles que pueden iniciar sesión en la app.
enum UserRole {
  patient('Paciente', 'paciente'),
  admission('Admisión', 'admision'),
  doctor('Médico', 'medico'),
  billing('Facturación', 'facturacion');

  const UserRole(this.label, this.slug);

  /// Nombre visible del rol.
  final String label;

  /// Segmento de la URL del rol, p. ej. `/admision`.
  final String slug;

  /// Actor de la infografía que representa este rol.
  Actor get actor => switch (this) {
        UserRole.patient => Actor.patient,
        UserRole.admission => Actor.admission,
        UserRole.doctor => Actor.doctor,
        UserRole.billing => Actor.billing,
      };

  /// Busca un rol por su segmento de URL; devuelve `null` si no existe.
  static UserRole? fromSlug(String slug) {
    for (final role in UserRole.values) {
      if (role.slug == slug) return role;
    }
    return null;
  }
}

/// Los 5 actores del proceso, tal como aparecen en la infografía.
enum Actor {
  patient('Paciente', 'Persona afiliada que solicita y recibe el servicio.'),
  admission('Admisión', 'Personal de admisión y atención al usuario: registra, orienta y da seguimiento al proceso.'),
  doctor('Médico', 'Médico general o especialista: realiza la consulta y emite indicaciones.'),
  support('Soporte TI', 'Personal de apoyo y tecnología: garantiza la plataforma, la conectividad y el soporte.'),
  billing('Facturación', 'Facturación y auditoría: gestiona el cierre administrativo y la calidad del servicio.');

  const Actor(this.label, this.description);

  final String label;
  final String description;
}

/// Estado general del caso.
enum CaseStatus {
  active('En proceso'),
  insuranceRejected('Rechazado por el seguro'),
  cancelled('Cancelado'),
  completed('Completado');

  const CaseStatus(this.label);

  final String label;

  /// Un caso abierto todavía puede avanzar o cancelarse.
  bool get isOpen => this == CaseStatus.active || this == CaseStatus.insuranceRejected;
}

/// Canales por los que el paciente pide la cita (paso 1).
enum RequestChannel {
  mobile('Celular'),
  email('Correo'),
  whatsapp('WhatsApp'),
  webPortal('Portal web'),
  phone('Teléfono');

  const RequestChannel(this.label);

  final String label;
}

/// Plataformas de videoconferencia (paso 7).
enum VideoPlatform {
  teams('MS Teams'),
  zoom('Zoom'),
  meet('Google Meet');

  const VideoPlatform(this.label);

  final String label;
}

/// Los 3 grupos de la infografía de servicios.
enum ServiceGroup {
  clinical('Servicios clínicos'),
  careFollowUp('Servicios asistenciales y de seguimiento'),
  derived('Servicios derivados de la consulta');

  const ServiceGroup(this.label);

  final String label;
}

/// Especialidades de los médicos.
enum Specialty {
  generalMedicine('Medicina general'),
  internalMedicine('Medicina interna'),
  pediatrics('Pediatría'),
  gynecology('Ginecología'),
  cardiology('Cardiología'),
  psychology('Psicología'),
  nutrition('Nutrición');

  const Specialty(this.label);

  final String label;
}

/// Estado de la reclamación al seguro (paso 9).
enum ClaimStatus {
  notApplicable('No aplica'),
  pending('Pendiente'),
  approved('Aprobada'),
  objected('Glosada');

  const ClaimStatus(this.label);

  final String label;
}

/// Método de pago del copago. Solo se registra el método, nunca datos de tarjeta.
enum PaymentMethod {
  cash('Efectivo'),
  card('Tarjeta'),
  transfer('Transferencia');

  const PaymentMethod(this.label);

  final String label;
}

/// Tipo de orden médica (paso 8).
enum OrderType {
  lab('Laboratorio'),
  imaging('Imágenes');

  const OrderType(this.label);

  final String label;
}

/// Sexo del paciente.
enum Gender {
  female('Femenino'),
  male('Masculino');

  const Gender(this.label);

  final String label;
}

/// Tipo de evento de la línea de tiempo del caso.
enum EventKind {
  /// Completa el paso.
  completed,

  /// El seguro rechazó la cobertura (paso 3).
  rejected,

  /// La solicitud se canceló.
  cancelled,

  /// El médico inició la consulta (paso 7).
  started,

  /// Facturación registró la reclamación (paso 9).
  claim,

  /// Facturación registró el pago del copago (paso 9).
  payment,

  /// Admisión registró una llamada de seguimiento (paso 10).
  call,
}
```

- [ ] **Step 4: Crear los pasos del proceso y la excepción**

Create `saludconecta/lib/domain/process/process_step.dart`:

```dart
import '../models/enums.dart';

/// Los 10 pasos del proceso de telemedicina (infografía 1).
///
/// - [actor]: actor principal del paso; define su color en los diagramas.
/// - [owners]: roles que pueden completar el paso en la app.
enum ProcessStep {
  requestAppointment(
    number: 1,
    title: 'Solicitud de cita',
    description: 'El paciente solicita la cita médica virtual por celular, correo, WhatsApp, portal web o teléfono.',
    actor: Actor.patient,
    owners: {UserRole.patient},
  ),
  reception(
    number: 2,
    title: 'Recepción en Hospital / PSS',
    description: 'Registro de datos y motivo de consulta.',
    actor: Actor.admission,
    owners: {UserRole.admission},
  ),
  insuranceValidation(
    number: 3,
    title: 'Validación con el seguro',
    description: 'Validación de afiliación, cobertura y autorización.',
    actor: Actor.admission,
    owners: {UserRole.admission},
  ),
  scheduling(
    number: 4,
    title: 'Agendamiento',
    description: 'Se agenda la cita y se confirma fecha y hora.',
    actor: Actor.admission,
    owners: {UserRole.admission},
  ),
  patientConfirmation(
    number: 5,
    title: 'Confirmación al paciente',
    description: 'Envío de enlace e instrucciones.',
    actor: Actor.admission,
    owners: {UserRole.admission},
  ),
  consentAdmission(
    number: 6,
    title: 'Consentimiento y admisión virtual',
    description: 'Aceptación del consentimiento e identificación del paciente.',
    actor: Actor.patient,
    owners: {UserRole.patient},
  ),
  consultation(
    number: 7,
    title: 'Consulta de telemedicina',
    description: 'Evaluación médica, orientación clínica y seguimiento por MS Teams, Zoom o Google Meet.',
    actor: Actor.doctor,
    owners: {UserRole.doctor},
  ),
  consultationResult(
    number: 8,
    title: 'Resultado de la consulta',
    description: 'Receta médica, órdenes, indicaciones o referencia presencial.',
    actor: Actor.doctor,
    owners: {UserRole.doctor},
  ),
  administrativeClosure(
    number: 9,
    title: 'Cierre administrativo',
    description: 'Facturación, reclamación, auditoría y pago.',
    actor: Actor.billing,
    owners: {UserRole.billing},
  ),
  followUp(
    number: 10,
    title: 'Seguimiento al paciente',
    description: 'Llamadas de seguimiento, encuesta de satisfacción, recordatorios y próximas citas.',
    // El seguimiento lo hace el hospital (Admisión), pero el paso lo completa el paciente con la encuesta.
    actor: Actor.admission,
    owners: {UserRole.patient},
  );

  const ProcessStep({
    required this.number,
    required this.title,
    required this.description,
    required this.actor,
    required this.owners,
  });

  final int number;
  final String title;
  final String description;
  final Actor actor;
  final Set<UserRole> owners;

  /// Paso siguiente, o `null` si es el último.
  ProcessStep? get next => number < ProcessStep.values.length ? ProcessStep.values[number] : null;

  /// Paso anterior, o `null` si es el primero.
  ProcessStep? get previous => number > 1 ? ProcessStep.values[number - 2] : null;

  /// ¿Puede este rol completar el paso?
  bool isOwnedBy(UserRole role) => owners.contains(role);

  /// Paso por su número (1–10).
  static ProcessStep fromNumber(int number) => ProcessStep.values[number - 1];
}
```

Create `saludconecta/lib/domain/process/process_exception.dart`:

```dart
/// Error de negocio: la transición pedida no está permitida.
///
/// El mensaje está en español porque la interfaz lo muestra tal cual.
class ProcessException implements Exception {
  const ProcessException(this.message);

  final String message;

  @override
  String toString() => message;
}
```

- [ ] **Step 5: Crear personas y catálogo**

Create `saludconecta/lib/domain/models/people.dart`:

```dart
import 'enums.dart';

/// Afiliación del paciente a una aseguradora (los datos de su carnet).
class InsuranceAffiliation {
  const InsuranceAffiliation({
    required this.insurerId,
    required this.plan,
    required this.affiliateNumber,
    required this.active,
  });

  final String insurerId;

  /// Plan contratado: "Básico", "Plus" o "Premium".
  final String plan;

  /// Número de carnet; con él inicia sesión el paciente.
  final String affiliateNumber;

  final bool active;
}

class Patient {
  const Patient({
    required this.id,
    required this.fullName,
    required this.cedula,
    required this.birthDate,
    required this.gender,
    required this.phone,
    required this.email,
    required this.affiliation,
    this.avatarAsset,
  });

  final String id;
  final String fullName;
  final String cedula;
  final DateTime birthDate;
  final Gender gender;
  final String phone;
  final String email;
  final InsuranceAffiliation affiliation;

  /// Ilustración del avatar; si es `null` se muestran las iniciales.
  final String? avatarAsset;

  String get firstName => fullName.split(' ').first;

  /// Edad cumplida en la fecha [on].
  int ageOn(DateTime on) {
    final hadBirthday = on.month > birthDate.month || (on.month == birthDate.month && on.day >= birthDate.day);
    return on.year - birthDate.year - (hadBirthday ? 0 : 1);
  }
}

/// Horario de un día laborable, en horas de 0 a 24 (p. ej. 8 a 17).
class WorkHours {
  const WorkHours(this.startHour, this.endHour);

  final int startHour;
  final int endHour;
}

class Doctor {
  const Doctor({
    required this.id,
    required this.title,
    required this.fullName,
    required this.specialty,
    required this.exequatur,
    required this.avatarAsset,
    required this.schedule,
  });

  final String id;

  /// "Dr.", "Dra." o "Lic.".
  final String title;
  final String fullName;
  final Specialty specialty;
  final String exequatur;
  final String avatarAsset;

  /// Horario por día de la semana (1 = lunes … 7 = domingo, igual que `DateTime.weekday`).
  final Map<int, WorkHours> schedule;

  /// Nombre con título, p. ej. "Dr. Carlos Méndez".
  String get displayName => '$title $fullName';

  Set<int> get workDays => schedule.keys.toSet();
}

/// Personal no médico: Admisión, Facturación y Soporte TI.
class StaffMember {
  const StaffMember({
    required this.id,
    required this.fullName,
    required this.actor,
    this.phone,
    this.avatarAsset,
  });

  final String id;
  final String fullName;
  final Actor actor;
  final String? phone;
  final String? avatarAsset;
}
```

Create `saludconecta/lib/domain/models/catalog.dart`:

```dart
import '../process/process_step.dart';
import 'enums.dart';

/// Aseguradora (ARS) ficticia con su cobertura por plan.
class Insurer {
  const Insurer({
    required this.id,
    required this.name,
    required this.symbolAsset,
    required this.planCoverage,
  });

  final String id;
  final String name;
  final String symbolAsset;

  /// % de cobertura por plan, p. ej. {'Básico': 70, 'Plus': 80, 'Premium': 90}.
  final Map<String, int> planCoverage;

  /// % que cubre el plan para el servicio; 20 puntos menos si el servicio tiene cobertura reducida.
  int coverageFor(String plan, MedicalService service) {
    final base = planCoverage[plan] ?? 0;
    final value = service.reducedCoverage ? base - 20 : base;
    return value < 0 ? 0 : value;
  }
}

/// Uno de los 24 servicios de la infografía 2.
class MedicalService {
  const MedicalService({
    required this.id,
    required this.name,
    required this.group,
    required this.description,
    required this.iconKey,
    this.requestable = false,
    this.specialty,
    this.fee,
    this.reducedCoverage = false,
    this.relatedStep,
  });

  final String id;
  final String name;
  final ServiceGroup group;
  final String description;

  /// Clave del ícono; `core/` la traduce a un `IconData` de Material.
  final String iconKey;

  /// Se puede pedir con el asistente "Solicitar cita".
  final bool requestable;
  final Specialty? specialty;

  /// Tarifa en pesos dominicanos (solo los servicios que se pueden solicitar).
  final int? fee;
  final bool reducedCoverage;

  /// Paso del proceso donde se genera el servicio (servicios derivados e incluidos).
  final ProcessStep? relatedStep;
}
```

- [ ] **Step 6: Crear los datos de cada paso, el evento y el caso**

Create `saludconecta/lib/domain/models/case_records.dart`:

```dart
import 'enums.dart';

// Datos que cada paso agrega al caso. Todas las clases son inmutables.

/// Paso 2: recepción de la solicitud.
class ReceptionData {
  const ReceptionData({required this.registeredBy, this.notes = ''});

  final String registeredBy;
  final String notes;
}

/// Paso 3: respuesta del seguro.
class InsuranceValidation {
  const InsuranceValidation({
    required this.approved,
    required this.coveragePercent,
    required this.message,
    required this.at,
    this.authorizationNumber,
  });

  final bool approved;
  final int coveragePercent;
  final String message;
  final DateTime at;

  /// Número de autorización (solo si se aprobó), formato AUT-yyyyMMdd-NNNN.
  final String? authorizationNumber;
}

/// Paso 4: la cita agendada.
class Appointment {
  const Appointment({required this.doctorId, required this.dateTime, required this.platform});

  final String doctorId;
  final DateTime dateTime;
  final VideoPlatform platform;
}

/// Paso 5: confirmación enviada al paciente.
class Confirmation {
  const Confirmation({required this.link, required this.sentVia, required this.instructions, required this.at});

  /// Enlace de demostración de la videollamada (no se abre).
  final String link;

  /// WhatsApp o correo.
  final RequestChannel sentVia;
  final String instructions;
  final DateTime at;
}

/// Un punto de la firma, con coordenadas normalizadas entre 0 y 1.
class SignaturePoint {
  const SignaturePoint(this.x, this.y);

  final double x;
  final double y;
}

/// Paso 6: consentimiento informado y admisión virtual.
class ConsentRecord {
  const ConsentRecord({required this.at, required this.identityConfirmed, required this.signature});

  final DateTime at;
  final bool identityConfirmed;

  /// Trazos de la firma; cada trazo es una lista de puntos.
  final List<List<SignaturePoint>> signature;
}

/// Notas clínicas que escribe el médico durante la consulta.
class ClinicalNotes {
  const ClinicalNotes({this.chiefComplaint = '', this.assessment = '', this.diagnosis = '', this.plan = ''});

  /// Motivo de consulta.
  final String chiefComplaint;

  /// Evaluación.
  final String assessment;
  final String diagnosis;
  final String plan;

  /// El motivo y el diagnóstico son obligatorios para finalizar la consulta.
  bool get isComplete => chiefComplaint.trim().isNotEmpty && diagnosis.trim().isNotEmpty;
}

/// Paso 7: la consulta.
class ConsultationRecord {
  const ConsultationRecord({required this.startedAt, this.endedAt, this.notes = const ClinicalNotes()});

  final DateTime startedAt;
  final DateTime? endedAt;
  final ClinicalNotes notes;
}

class PrescriptionItem {
  const PrescriptionItem({
    required this.medication,
    required this.dose,
    required this.frequency,
    required this.duration,
  });

  final String medication;
  final String dose;
  final String frequency;
  final String duration;
}

class Prescription {
  const Prescription({required this.items, required this.verificationCode});

  final List<PrescriptionItem> items;

  /// Código que aparece en el QR de la receta.
  final String verificationCode;
}

class MedicalOrder {
  const MedicalOrder({required this.type, required this.description});

  final OrderType type;
  final String description;
}

/// Referimiento presencial a un especialista.
class Referral {
  const Referral({required this.specialty, required this.reason});

  final Specialty specialty;
  final String reason;
}

/// Paso 8: resultados de la consulta.
class ConsultationResults {
  const ConsultationResults({
    required this.instructions,
    this.prescription,
    this.orders = const [],
    this.referral,
    this.followUpInDays,
  });

  final String instructions;
  final Prescription? prescription;
  final List<MedicalOrder> orders;
  final Referral? referral;

  /// Días para la próxima cita de seguimiento (7, 15 o 30); `null` si no requiere.
  final int? followUpInDays;

  List<MedicalOrder> ordersOf(OrderType type) => orders.where((o) => o.type == type).toList();
}

/// Factura del caso. Los montos son pesos dominicanos enteros.
class Invoice {
  const Invoice({required this.fee, required this.coveragePercent, required this.insurerAmount, required this.copay});

  final int fee;
  final int coveragePercent;
  final int insurerAmount;
  final int copay;
}

class Payment {
  const Payment({required this.method, required this.amount, required this.at});

  final PaymentMethod method;
  final int amount;
  final DateTime at;
}

/// Paso 9: cierre administrativo.
class BillingRecord {
  const BillingRecord({required this.invoice, required this.claimStatus, this.claimNumber, this.payment, this.closedAt});

  final Invoice invoice;
  final ClaimStatus claimStatus;
  final String? claimNumber;
  final Payment? payment;
  final DateTime? closedAt;

  BillingRecord copyWith({ClaimStatus? claimStatus, String? claimNumber, Payment? payment, DateTime? closedAt}) {
    return BillingRecord(
      invoice: invoice,
      claimStatus: claimStatus ?? this.claimStatus,
      claimNumber: claimNumber ?? this.claimNumber,
      payment: payment ?? this.payment,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}

class FollowUpCall {
  const FollowUpCall({required this.at, required this.byName, required this.note});

  final DateTime at;
  final String byName;
  final String note;
}

/// Encuesta de satisfacción.
class Survey {
  const Survey({required this.rating, required this.nps, required this.at, this.comment = ''});

  /// Estrellas, de 1 a 5.
  final int rating;

  /// "¿Qué tan probable es que nos recomiendes?", de 0 a 10.
  final int nps;
  final DateTime at;
  final String comment;
}

/// Paso 10: seguimiento.
class FollowUpRecord {
  const FollowUpRecord({this.calls = const [], this.survey});

  final List<FollowUpCall> calls;
  final Survey? survey;

  FollowUpRecord copyWith({List<FollowUpCall>? calls, Survey? survey}) {
    return FollowUpRecord(calls: calls ?? this.calls, survey: survey ?? this.survey);
  }
}
```

Create `saludconecta/lib/domain/models/process_event.dart`:

```dart
import '../process/process_step.dart';
import 'enums.dart';

/// Un hecho de la línea de tiempo del caso.
class ProcessEvent {
  const ProcessEvent({
    required this.step,
    required this.actor,
    required this.actorName,
    required this.at,
    required this.title,
    this.detail = '',
    this.kind = EventKind.completed,
  });

  final ProcessStep step;
  final Actor actor;
  final String actorName;
  final DateTime at;
  final String title;
  final String detail;
  final EventKind kind;

  /// Solo los eventos `completed` completan el paso; los demás son auxiliares
  /// (p. ej. el inicio de la consulta o una llamada de seguimiento).
  bool get completesStep => kind == EventKind.completed;
}
```

Create `saludconecta/lib/domain/models/telemedicine_case.dart`:

```dart
import '../process/process_step.dart';
import 'case_records.dart';
import 'enums.dart';
import 'process_event.dart';

/// El caso de telemedicina: recorre los 10 pasos del proceso.
class TelemedicineCase {
  const TelemedicineCase({
    required this.id,
    required this.patientId,
    required this.serviceId,
    required this.channel,
    required this.reason,
    required this.preferredDate,
    required this.createdAt,
    required this.currentStep,
    required this.status,
    required this.events,
    this.privatePay = false,
    this.reception,
    this.insurance,
    this.appointment,
    this.confirmation,
    this.consent,
    this.consultation,
    this.results,
    this.billing,
    this.followUp,
  });

  /// Identificador, p. ej. "TM-2026-0001".
  final String id;
  final String patientId;
  final String serviceId;
  final RequestChannel channel;

  /// Motivo de consulta escrito por el paciente.
  final String reason;
  final DateTime preferredDate;
  final DateTime createdAt;

  /// Próximo paso PENDIENTE. Al completar el paso 10 se queda en `followUp`.
  final ProcessStep currentStep;
  final CaseStatus status;

  /// Línea de tiempo, en orden cronológico.
  final List<ProcessEvent> events;

  /// `true` si continuó como privado tras el rechazo del seguro.
  final bool privatePay;

  final ReceptionData? reception;
  final InsuranceValidation? insurance;
  final Appointment? appointment;
  final Confirmation? confirmation;
  final ConsentRecord? consent;
  final ConsultationRecord? consultation;
  final ConsultationResults? results;
  final BillingRecord? billing;
  final FollowUpRecord? followUp;

  /// Copia con los campos indicados cambiados; los demás se conservan.
  TelemedicineCase copyWith({
    ProcessStep? currentStep,
    CaseStatus? status,
    List<ProcessEvent>? events,
    bool? privatePay,
    ReceptionData? reception,
    InsuranceValidation? insurance,
    Appointment? appointment,
    Confirmation? confirmation,
    ConsentRecord? consent,
    ConsultationRecord? consultation,
    ConsultationResults? results,
    BillingRecord? billing,
    FollowUpRecord? followUp,
  }) {
    return TelemedicineCase(
      id: id,
      patientId: patientId,
      serviceId: serviceId,
      channel: channel,
      reason: reason,
      preferredDate: preferredDate,
      createdAt: createdAt,
      currentStep: currentStep ?? this.currentStep,
      status: status ?? this.status,
      events: events ?? this.events,
      privatePay: privatePay ?? this.privatePay,
      reception: reception ?? this.reception,
      insurance: insurance ?? this.insurance,
      appointment: appointment ?? this.appointment,
      confirmation: confirmation ?? this.confirmation,
      consent: consent ?? this.consent,
      consultation: consultation ?? this.consultation,
      results: results ?? this.results,
      billing: billing ?? this.billing,
      followUp: followUp ?? this.followUp,
    );
  }

  /// Pasos completados, según los eventos que completan paso.
  Set<ProcessStep> get completedSteps => {
        for (final e in events)
          if (e.completesStep) e.step,
      };

  bool isStepCompleted(ProcessStep step) => events.any((e) => e.completesStep && e.step == step);

  /// Momento en que se completó [step], o `null` si no se ha completado.
  DateTime? completedAt(ProcessStep step) {
    for (final e in events) {
      if (e.completesStep && e.step == step) return e.at;
    }
    return null;
  }

  bool get isOpen => status.isOpen;

  /// Momento del último cambio.
  DateTime get updatedAt => events.isEmpty ? createdAt : events.last.at;
}
```

- [ ] **Step 7: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/domain/models_test.dart
```

Expected: `All tests passed!` (6 pruebas).

---

### Task 2: Catálogo semilla y repositorio del catálogo

**Files:**
- Create: `saludconecta/lib/data/repositories/catalog_repository.dart`, `saludconecta/lib/data/seed/seed_catalog.dart`
- Test: `saludconecta/test/data/seed_catalog_test.dart`

**Interfaces:**
- Consumes: modelos de la tarea 1.
- Produces:
  - `abstract class CatalogRepository`, con:
    - las listas `insurers`, `services`, `doctors`, `patients`, `demoPatients` y `staff`;
    - las búsquedas `insurerById`, `serviceById`, `doctorById` y `patientById`, que lanzan `ArgumentError` si no existe;
    - `patientByAffiliateNumber(String) → Patient?`, que ignora mayúsculas y espacios;
    - `staffFor(Actor) → StaffMember`;
    - `doctorsFor(Specialty) → List<Doctor>`.
  - `InMemoryCatalogRepository({insurers, services, doctors, demoPatients, staff, otherPatients})`.
  - `SeedIds`: constantes `String` para:
    - los 6 pacientes demo: `maria`, `jose`, `carmen`, `pedro`, `luisa`, `ramon`;
    - los 7 médicos: `mendez`, `jimenez`, `rosario`, `nunez`, `santana`, `herrera`, `cruz`;
    - el personal: `ana`, `roberto`, `luis`;
    - los 13 servicios solicitables: `generalConsult`, `internalMedicine`, `pediatrics`, `gynecology`, `cardiology`, `psychology`, `nutrition`, `secondOpinion`, `chronicCare`, `postConsultFollowUp`, `postOpFollowUp`, `resultsReview`, `medicalGuidance`.
  - `SeedCatalog`:
    - las constantes `insurers`, `services`, `doctors` y `staff`, y `demoPatients` (`final`);
    - `backgroundPatients()`, que devuelve 40 pacientes;
    - `repository() → InMemoryCatalogRepository`.

- [ ] **Step 1: Escribir la prueba del catálogo**

Create `saludconecta/test/data/seed_catalog_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';

void main() {
  final catalog = SeedCatalog.repository();

  test('los 24 servicios de la infografía, en 3 grupos de 8', () {
    expect(catalog.services, hasLength(24));
    for (final group in ServiceGroup.values) {
      expect(catalog.services.where((s) => s.group == group), hasLength(8), reason: group.label);
    }
    final requestable = catalog.services.where((s) => s.requestable).toList();
    expect(requestable, hasLength(13));
    expect(requestable.every((s) => s.fee != null && s.specialty != null), isTrue);
    expect(catalog.serviceById(SeedIds.generalConsult).fee, 1500);
    expect(catalog.serviceById(SeedIds.nutrition).reducedCoverage, isTrue);
  });

  test('un médico por especialidad; el Dr. Méndez también trabaja el sábado', () {
    expect(catalog.doctors, hasLength(7));
    for (final specialty in Specialty.values) {
      expect(catalog.doctorsFor(specialty), hasLength(1), reason: specialty.label);
    }
    expect(catalog.doctorById(SeedIds.mendez).workDays, {1, 2, 3, 4, 5, 6});
    expect(catalog.doctorById(SeedIds.jimenez).displayName, 'Dra. Laura Jiménez');
  });

  test('pacientes de demostración y búsqueda por número de carnet', () {
    expect(catalog.demoPatients, hasLength(6));
    expect(catalog.patients, hasLength(46));
    expect(catalog.patientByAffiliateNumber(' sp-100245 ')!.id, SeedIds.maria);
    expect(catalog.patientByAffiliateNumber('XX-0'), isNull);
    expect(catalog.patientById(SeedIds.maria).affiliation.plan, 'Plus');
    expect(catalog.patientById(SeedIds.pedro).affiliation.active, isFalse);
  });

  test('aseguradoras ficticias y personal', () {
    expect(catalog.insurers.map((i) => i.name), ['ARS Salud Plena', 'ARS Vida Segura', 'ARS Familia Sana']);
    expect(catalog.staffFor(Actor.admission).fullName, 'Ana Peña');
    expect(catalog.staffFor(Actor.billing).fullName, 'Roberto Díaz');
    expect(catalog.staffFor(Actor.support).phone, '809-555-0199');
    expect(() => catalog.serviceById('no-existe'), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/data/seed_catalog_test.dart
```

Expected: FAIL. No compila porque `lib/data/seed/seed_catalog.dart` no existe.

- [ ] **Step 3: Crear el repositorio del catálogo**

Create `saludconecta/lib/data/repositories/catalog_repository.dart`:

```dart
import '../../domain/models/catalog.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/people.dart';

/// Catálogo: aseguradoras, servicios, médicos, pacientes y personal.
abstract class CatalogRepository {
  List<Insurer> get insurers;
  List<MedicalService> get services;
  List<Doctor> get doctors;

  /// Todos los pacientes: los 6 de demostración y los de fondo.
  List<Patient> get patients;

  /// Los 6 pacientes de demostración (chips de la pantalla de ingreso).
  List<Patient> get demoPatients;
  List<StaffMember> get staff;

  Insurer insurerById(String id);
  MedicalService serviceById(String id);
  Doctor doctorById(String id);
  Patient patientById(String id);

  /// Paciente por número de carnet (ignora mayúsculas y espacios); `null` si no existe.
  Patient? patientByAffiliateNumber(String affiliateNumber);

  /// Primer miembro del personal con ese actor (Admisión, Facturación o Soporte TI).
  StaffMember staffFor(Actor actor);

  /// Médicos de una especialidad.
  List<Doctor> doctorsFor(Specialty specialty);
}

/// Implementación en memoria; los datos vienen de `SeedCatalog`.
class InMemoryCatalogRepository implements CatalogRepository {
  InMemoryCatalogRepository({
    required List<Insurer> insurers,
    required List<MedicalService> services,
    required List<Doctor> doctors,
    required List<Patient> demoPatients,
    required List<StaffMember> staff,
    List<Patient> otherPatients = const [],
  })  : insurers = List.unmodifiable(insurers),
        services = List.unmodifiable(services),
        doctors = List.unmodifiable(doctors),
        demoPatients = List.unmodifiable(demoPatients),
        patients = List.unmodifiable([...demoPatients, ...otherPatients]),
        staff = List.unmodifiable(staff);

  @override
  final List<Insurer> insurers;

  @override
  final List<MedicalService> services;

  @override
  final List<Doctor> doctors;

  @override
  final List<Patient> demoPatients;

  @override
  final List<Patient> patients;

  @override
  final List<StaffMember> staff;

  @override
  Insurer insurerById(String id) => _find(insurers, (i) => i.id == id, 'aseguradora', id);

  @override
  MedicalService serviceById(String id) => _find(services, (s) => s.id == id, 'servicio', id);

  @override
  Doctor doctorById(String id) => _find(doctors, (d) => d.id == id, 'médico', id);

  @override
  Patient patientById(String id) => _find(patients, (p) => p.id == id, 'paciente', id);

  @override
  Patient? patientByAffiliateNumber(String affiliateNumber) {
    final wanted = _normalize(affiliateNumber);
    for (final p in patients) {
      if (_normalize(p.affiliation.affiliateNumber) == wanted) return p;
    }
    return null;
  }

  @override
  StaffMember staffFor(Actor actor) => _find(staff, (s) => s.actor == actor, 'personal', actor.name);

  @override
  List<Doctor> doctorsFor(Specialty specialty) => [
        for (final d in doctors)
          if (d.specialty == specialty) d,
      ];

  static T _find<T>(List<T> items, bool Function(T item) test, String kind, String id) {
    for (final item in items) {
      if (test(item)) return item;
    }
    throw ArgumentError('No existe $kind con id "$id".');
  }

  static String _normalize(String value) => value.replaceAll(RegExp(r'\s'), '').toUpperCase();
}
```

- [ ] **Step 4: Crear el catálogo semilla**

Create `saludconecta/lib/data/seed/seed_catalog.dart`:

```dart
import '../../domain/models/catalog.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/people.dart';
import '../../domain/process/process_step.dart';
import '../repositories/catalog_repository.dart';

/// IDs fijos de los datos de demostración (los usan la semilla y las pruebas).
class SeedIds {
  const SeedIds._();

  // Pacientes de demostración.
  static const maria = 'pac-maria';
  static const jose = 'pac-jose';
  static const carmen = 'pac-carmen';
  static const pedro = 'pac-pedro';
  static const luisa = 'pac-luisa';
  static const ramon = 'pac-ramon';

  // Médicos.
  static const mendez = 'doc-mendez';
  static const jimenez = 'doc-jimenez';
  static const rosario = 'doc-rosario';
  static const nunez = 'doc-nunez';
  static const santana = 'doc-santana';
  static const herrera = 'doc-herrera';
  static const cruz = 'doc-cruz';

  // Personal.
  static const ana = 'staff-ana';
  static const roberto = 'staff-roberto';
  static const luis = 'staff-luis';

  // Servicios que se pueden solicitar.
  static const generalConsult = 'consulta-general';
  static const internalMedicine = 'medicina-interna';
  static const pediatrics = 'pediatria-orientacion';
  static const gynecology = 'ginecologia-seguimiento';
  static const cardiology = 'cardiologia-seguimiento';
  static const psychology = 'psicologia';
  static const nutrition = 'nutricion';
  static const secondOpinion = 'segunda-opinion';
  static const chronicCare = 'control-cronicos';
  static const postConsultFollowUp = 'seguimiento-postconsulta';
  static const postOpFollowUp = 'seguimiento-postoperatorio';
  static const resultsReview = 'revision-resultados';
  static const medicalGuidance = 'orientacion-medica';
}

/// Catálogo de demostración. Las aseguradoras y las personas son FICTICIAS.
class SeedCatalog {
  const SeedCatalog._();

  static const insurers = <Insurer>[
    Insurer(
      id: 'salud-plena',
      name: 'ARS Salud Plena',
      symbolAsset: 'assets/illustrations/insurer_salud_plena.svg',
      planCoverage: {'Básico': 70, 'Plus': 80, 'Premium': 90},
    ),
    Insurer(
      id: 'vida-segura',
      name: 'ARS Vida Segura',
      symbolAsset: 'assets/illustrations/insurer_vida_segura.svg',
      planCoverage: {'Básico': 65, 'Plus': 80, 'Premium': 90},
    ),
    Insurer(
      id: 'familia-sana',
      name: 'ARS Familia Sana',
      symbolAsset: 'assets/illustrations/insurer_familia_sana.svg',
      planCoverage: {'Básico': 70, 'Plus': 85, 'Premium': 95},
    ),
  ];

  /// Los 24 servicios de la infografía 2.
  static const services = <MedicalService>[
    // ----- 1. Servicios clínicos -----
    MedicalService(
      id: SeedIds.generalConsult, name: 'Consulta médica general', group: ServiceGroup.clinical,
      description: 'Evaluación de síntomas comunes, diagnóstico y tratamiento inicial.', iconKey: 'stethoscope',
      requestable: true, specialty: Specialty.generalMedicine, fee: 1500,
    ),
    MedicalService(
      id: SeedIds.internalMedicine, name: 'Medicina interna', group: ServiceGroup.clinical,
      description: 'Atención de adultos con enfermedades crónicas o que afectan varios órganos.',
      iconKey: 'monitor_heart', requestable: true, specialty: Specialty.internalMedicine, fee: 2500,
    ),
    MedicalService(
      id: SeedIds.pediatrics, name: 'Pediatría de orientación', group: ServiceGroup.clinical,
      description: 'Orientación sobre la salud y los síntomas de niños y adolescentes.', iconKey: 'child_care',
      requestable: true, specialty: Specialty.pediatrics, fee: 2000,
    ),
    MedicalService(
      id: SeedIds.gynecology, name: 'Ginecología de seguimiento', group: ServiceGroup.clinical,
      description: 'Controles y seguimiento de la salud de la mujer.', iconKey: 'female',
      requestable: true, specialty: Specialty.gynecology, fee: 2500,
    ),
    MedicalService(
      id: SeedIds.cardiology, name: 'Cardiología de seguimiento', group: ServiceGroup.clinical,
      description: 'Control de la presión arterial, las palpitaciones y las enfermedades del corazón.',
      iconKey: 'favorite', requestable: true, specialty: Specialty.cardiology, fee: 2800,
    ),
    MedicalService(
      id: SeedIds.psychology, name: 'Psicología', group: ServiceGroup.clinical,
      description: 'Apoyo emocional y terapia breve por videollamada.', iconKey: 'psychology',
      requestable: true, specialty: Specialty.psychology, fee: 2200, reducedCoverage: true,
    ),
    MedicalService(
      id: SeedIds.nutrition, name: 'Nutrición', group: ServiceGroup.clinical,
      description: 'Planes de alimentación y control de peso.', iconKey: 'restaurant',
      requestable: true, specialty: Specialty.nutrition, fee: 1800, reducedCoverage: true,
    ),
    MedicalService(
      id: SeedIds.secondOpinion, name: 'Segunda opinión médica', group: ServiceGroup.clinical,
      description: 'Revisión de un diagnóstico o tratamiento por otro especialista.', iconKey: 'groups',
      requestable: true, specialty: Specialty.internalMedicine, fee: 3000, reducedCoverage: true,
    ),
    // ----- 2. Servicios asistenciales y de seguimiento -----
    MedicalService(
      id: SeedIds.chronicCare, name: 'Control de pacientes crónicos', group: ServiceGroup.careFollowUp,
      description: 'Seguimiento periódico de diabetes, hipertensión y otras condiciones.', iconKey: 'medication',
      requestable: true, specialty: Specialty.internalMedicine, fee: 1200,
    ),
    MedicalService(
      id: SeedIds.postConsultFollowUp, name: 'Seguimiento postconsulta', group: ServiceGroup.careFollowUp,
      description: 'Revisión de tu evolución después de una consulta.', iconKey: 'event_available',
      requestable: true, specialty: Specialty.generalMedicine, fee: 1000,
    ),
    MedicalService(
      id: SeedIds.postOpFollowUp, name: 'Seguimiento postoperatorio no crítico', group: ServiceGroup.careFollowUp,
      description: 'Control de la recuperación tras una cirugía sin complicaciones.', iconKey: 'healing',
      requestable: true, specialty: Specialty.generalMedicine, fee: 1200,
    ),
    MedicalService(
      id: SeedIds.resultsReview, name: 'Revisión de resultados de estudios', group: ServiceGroup.careFollowUp,
      description: 'Interpretación de análisis de laboratorio y de imágenes.', iconKey: 'fact_check',
      requestable: true, specialty: Specialty.generalMedicine, fee: 1000,
    ),
    MedicalService(
      id: SeedIds.medicalGuidance, name: 'Orientación médica', group: ServiceGroup.careFollowUp,
      description: 'Respuestas rápidas sobre síntomas, medicamentos y cuidados.', iconKey: 'support_agent',
      requestable: true, specialty: Specialty.generalMedicine, fee: 800,
    ),
    MedicalService(
      id: 'educacion-salud', name: 'Educación en salud', group: ServiceGroup.careFollowUp,
      description: 'Consejos de prevención y hábitos saludables en el Inicio de la app.', iconKey: 'school',
    ),
    MedicalService(
      id: 'recordatorios', name: 'Recordatorios y seguimiento al paciente', group: ServiceGroup.careFollowUp,
      description: 'Avisos de citas y llamadas de seguimiento del equipo de Admisión.',
      iconKey: 'notifications_active', relatedStep: ProcessStep.followUp,
    ),
    MedicalService(
      id: 'encuesta-satisfaccion', name: 'Encuesta de satisfacción', group: ServiceGroup.careFollowUp,
      description: 'Tu opinión sobre la atención, al final del proceso.', iconKey: 'thumb_up',
      relatedStep: ProcessStep.followUp,
    ),
    // ----- 3. Servicios derivados de la consulta -----
    MedicalService(
      id: 'receta-medica', name: 'Receta médica', group: ServiceGroup.derived,
      description: 'Receta digital con código QR de verificación.', iconKey: 'receipt_long',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'ordenes-laboratorio', name: 'Órdenes de laboratorio', group: ServiceGroup.derived,
      description: 'Análisis clínicos indicados por el médico.', iconKey: 'science',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'ordenes-imagenes', name: 'Órdenes de imágenes', group: ServiceGroup.derived,
      description: 'Radiografías, sonografías y otros estudios de imagen.', iconKey: 'image_search',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'referimientos', name: 'Referimientos', group: ServiceGroup.derived,
      description: 'Referencia presencial a un especialista cuando hace falta.', iconKey: 'alt_route',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'indicaciones-medicas', name: 'Indicaciones médicas', group: ServiceGroup.derived,
      description: 'Instrucciones de cuidado y tratamiento después de la consulta.', iconKey: 'assignment',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'proxima-cita', name: 'Programación de próxima cita', group: ServiceGroup.derived,
      description: 'Fecha sugerida para tu próxima consulta de seguimiento.', iconKey: 'calendar_month',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'validacion-afiliacion', name: 'Validación de afiliación y cobertura', group: ServiceGroup.derived,
      description: 'Verificación de tu seguro antes de la cita.', iconKey: 'verified_user',
      relatedStep: ProcessStep.insuranceValidation,
    ),
    MedicalService(
      id: 'autorizacion-servicios', name: 'Autorización de servicios', group: ServiceGroup.derived,
      description: 'Número de autorización del seguro para tu atención.', iconKey: 'verified',
      relatedStep: ProcessStep.insuranceValidation,
    ),
  ];

  /// Lunes a viernes de 8:00 a 17:00.
  static const _weekdays = {
    1: WorkHours(8, 17),
    2: WorkHours(8, 17),
    3: WorkHours(8, 17),
    4: WorkHours(8, 17),
    5: WorkHours(8, 17),
  };

  static const doctors = <Doctor>[
    Doctor(
      id: SeedIds.mendez, title: 'Dr.', fullName: 'Carlos Méndez', specialty: Specialty.generalMedicine,
      exequatur: '0457-12', avatarAsset: 'assets/illustrations/doctor_1.svg',
      // También atiende el sábado de 8:00 a 12:00.
      schedule: {..._weekdays, 6: WorkHours(8, 12)},
    ),
    Doctor(
      id: SeedIds.jimenez, title: 'Dra.', fullName: 'Laura Jiménez', specialty: Specialty.internalMedicine,
      exequatur: '0613-09', avatarAsset: 'assets/illustrations/doctor_2.svg', schedule: _weekdays,
    ),
    Doctor(
      id: SeedIds.rosario, title: 'Dr.', fullName: 'Andrés Rosario', specialty: Specialty.pediatrics,
      exequatur: '0722-15', avatarAsset: 'assets/illustrations/doctor_3.svg', schedule: _weekdays,
    ),
    Doctor(
      id: SeedIds.nunez, title: 'Dra.', fullName: 'Patricia Núñez', specialty: Specialty.gynecology,
      exequatur: '0839-11', avatarAsset: 'assets/illustrations/doctor_4.svg', schedule: _weekdays,
    ),
    Doctor(
      id: SeedIds.santana, title: 'Dr.', fullName: 'Miguel Santana', specialty: Specialty.cardiology,
      exequatur: '0915-08', avatarAsset: 'assets/illustrations/doctor_5.svg', schedule: _weekdays,
    ),
    Doctor(
      id: SeedIds.herrera, title: 'Lic.', fullName: 'Sofía Herrera', specialty: Specialty.psychology,
      exequatur: '1024-17', avatarAsset: 'assets/illustrations/doctor_6.svg', schedule: _weekdays,
    ),
    Doctor(
      id: SeedIds.cruz, title: 'Lic.', fullName: 'Daniela Cruz', specialty: Specialty.nutrition,
      exequatur: '1136-19', avatarAsset: 'assets/illustrations/doctor_7.svg', schedule: _weekdays,
    ),
  ];

  static const staff = <StaffMember>[
    StaffMember(id: SeedIds.ana, fullName: 'Ana Peña', actor: Actor.admission),
    StaffMember(id: SeedIds.roberto, fullName: 'Roberto Díaz', actor: Actor.billing),
    StaffMember(
      id: SeedIds.luis,
      fullName: 'Luis Castillo',
      actor: Actor.support,
      phone: '809-555-0199',
      avatarAsset: 'assets/illustrations/support.svg',
    ),
  ];

  /// Los 6 pacientes de demostración (cédulas y carnets ficticios).
  static final demoPatients = <Patient>[
    Patient(
      id: SeedIds.maria, fullName: 'María Fernández', cedula: '001-1234567-1', birthDate: DateTime(1990, 3, 14),
      gender: Gender.female, phone: '809-555-0101', email: 'maria.fernandez@example.com',
      affiliation: const InsuranceAffiliation(
        insurerId: 'salud-plena', plan: 'Plus', affiliateNumber: 'SP-100245', active: true,
      ),
      avatarAsset: 'assets/illustrations/patient_1.svg',
    ),
    Patient(
      id: SeedIds.jose, fullName: 'José Martínez', cedula: '001-2345678-2', birthDate: DateTime(1978, 7, 22),
      gender: Gender.male, phone: '809-555-0102', email: 'jose.martinez@example.com',
      affiliation: const InsuranceAffiliation(
        insurerId: 'vida-segura', plan: 'Básico', affiliateNumber: 'VS-200318', active: true,
      ),
      avatarAsset: 'assets/illustrations/patient_2.svg',
    ),
    Patient(
      id: SeedIds.carmen, fullName: 'Carmen Reyes', cedula: '001-3456789-3', birthDate: DateTime(1965, 11, 2),
      gender: Gender.female, phone: '809-555-0103', email: 'carmen.reyes@example.com',
      affiliation: const InsuranceAffiliation(
        insurerId: 'familia-sana', plan: 'Premium', affiliateNumber: 'FS-300472', active: true,
      ),
      avatarAsset: 'assets/illustrations/patient_3.svg',
    ),
    Patient(
      id: SeedIds.pedro, fullName: 'Pedro Almonte', cedula: '001-4567890-4', birthDate: DateTime(1983, 5, 30),
      gender: Gender.male, phone: '809-555-0104', email: 'pedro.almonte@example.com',
      // Afiliación INACTIVA: el seguro rechaza su solicitud (camino alterno de la demo).
      affiliation: const InsuranceAffiliation(
        insurerId: 'salud-plena', plan: 'Básico', affiliateNumber: 'SP-100519', active: false,
      ),
      avatarAsset: 'assets/illustrations/patient_4.svg',
    ),
    Patient(
      id: SeedIds.luisa, fullName: 'Luisa Gómez', cedula: '001-5678901-5', birthDate: DateTime(1995, 9, 18),
      gender: Gender.female, phone: '809-555-0105', email: 'luisa.gomez@example.com',
      affiliation: const InsuranceAffiliation(
        insurerId: 'familia-sana', plan: 'Plus', affiliateNumber: 'FS-300651', active: true,
      ),
      avatarAsset: 'assets/illustrations/patient_5.svg',
    ),
    Patient(
      id: SeedIds.ramon, fullName: 'Ramón Ortiz', cedula: '001-6789012-6', birthDate: DateTime(1958, 1, 25),
      gender: Gender.male, phone: '809-555-0106', email: 'ramon.ortiz@example.com',
      affiliation: const InsuranceAffiliation(
        insurerId: 'vida-segura', plan: 'Premium', affiliateNumber: 'VS-200733', active: true,
      ),
      avatarAsset: 'assets/illustrations/patient_6.svg',
    ),
  ];

  /// 40 pacientes de fondo con nombres generados; solo aparecen en los datos históricos.
  static List<Patient> backgroundPatients() {
    const femaleNames = [
      'Rosa', 'Yolanda', 'Gabriela', 'Altagracia', 'Mercedes', 'Paola', 'Esther', 'Juana', 'Teresa', 'Milagros',
    ];
    const maleNames = [
      'Juan', 'Rafael', 'Francisco', 'Héctor', 'Manuel', 'Julio', 'Félix', 'Domingo', 'Ernesto', 'Wilson',
    ];
    const lastNames = [
      'Rodríguez', 'Pérez', 'Santos', 'Guzmán', 'Vásquez', 'Batista', 'Peralta', 'Medina',
      'Cabrera', 'Mejía', 'Sánchez', 'Encarnación', 'Polanco', 'Familia', 'Tavárez', 'Ureña',
    ];
    const insurerIds = ['salud-plena', 'vida-segura', 'familia-sana'];
    const prefixes = ['SP', 'VS', 'FS'];
    const plans = ['Básico', 'Plus', 'Premium'];
    return [
      for (var i = 0; i < 40; i++)
        Patient(
          id: 'pac-${(i + 1).toString().padLeft(3, '0')}',
          fullName: '${i.isEven ? femaleNames[(i ~/ 2) % 10] : maleNames[(i ~/ 2) % 10]} ${lastNames[(i * 3) % 16]}',
          cedula: '402-${2000000 + i * 3571}-${(i * 7) % 10}',
          birthDate: DateTime(1950 + (i * 7) % 50, 1 + i % 12, 1 + (i * 3) % 28),
          gender: i.isEven ? Gender.female : Gender.male,
          phone: '809-555-${2000 + i}',
          email: 'paciente${i + 1}@example.com',
          affiliation: InsuranceAffiliation(
            insurerId: insurerIds[i % 3],
            plan: plans[(i ~/ 3) % 3],
            affiliateNumber: '${prefixes[i % 3]}-${400000 + i}',
            active: true,
          ),
        ),
    ];
  }

  /// Repositorio con todo el catálogo: pacientes de demostración y de fondo.
  static InMemoryCatalogRepository repository() => InMemoryCatalogRepository(
        insurers: insurers,
        services: services,
        doctors: doctors,
        demoPatients: demoPatients,
        otherPatients: backgroundPatients(),
        staff: staff,
      );
}
```

- [ ] **Step 5: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/data/seed_catalog_test.dart
```

Expected: `All tests passed!` (4 pruebas).

---

### Task 3: Códigos del caso y gateways simulados

**Files:**
- Create: `saludconecta/lib/domain/services/clock.dart`, `saludconecta/lib/domain/services/case_codes.dart`, `saludconecta/lib/data/gateways/insurance_gateway.dart`, `saludconecta/lib/data/gateways/confirmation_gateway.dart`
- Test: `saludconecta/test/data/gateways_test.dart`

**Interfaces:**
- Consumes: modelos (tarea 1), `CatalogRepository` y `SeedCatalog` (tarea 2).
- Produces:
  - `typedef Clock = DateTime Function()`.
  - `CaseCodes`, con estas funciones estáticas:
    - `sequenceOf(caseId)`;
    - `authorization(caseId, at)`, que devuelve `AUT-yyyyMMdd-NNNN`;
    - `claim(caseId)`, que devuelve `REC-NNNNN`;
    - `prescription(caseId)`, que devuelve `RX-2026-0012-XXXX`;
    - `meetingLink(caseId, VideoPlatform)`.
  - `abstract class InsuranceGateway`, con dos operaciones:
    - `Future<InsuranceValidation> validate({required Patient patient, required MedicalService service, required String caseId})`;
    - `Future<String> submitClaim({required String caseId})`.
  - `SimulatedInsuranceGateway({required CatalogRepository catalog, Clock clock = DateTime.now, Duration delay = 1.5 s})`.
  - `abstract class ConfirmationGateway`, con `Future<String> send({required String caseId, required VideoPlatform platform, required RequestChannel via})`.
  - `SimulatedConfirmationGateway({Duration delay = 1 s})`.

- [ ] **Step 1: Escribir la prueba de los códigos y los gateways**

Create `saludconecta/test/data/gateways_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/gateways/confirmation_gateway.dart';
import 'package:saludconecta/data/gateways/insurance_gateway.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/services/case_codes.dart';

void main() {
  final catalog = SeedCatalog.repository();
  final maria = catalog.patientById(SeedIds.maria);
  final pedro = catalog.patientById(SeedIds.pedro);
  final generalConsult = catalog.serviceById(SeedIds.generalConsult);
  final nutrition = catalog.serviceById(SeedIds.nutrition);

  test('códigos que se derivan del ID del caso', () {
    expect(CaseCodes.sequenceOf('TM-2026-0012'), '0012');
    expect(CaseCodes.authorization('TM-2026-0012', DateTime(2026, 11, 9)), 'AUT-20261109-0012');
    expect(CaseCodes.claim('TM-2026-0012'), 'REC-10012');
    expect(CaseCodes.prescription('TM-2026-0012'), matches(RegExp(r'^RX-2026-0012-[0-9A-F]{4}$')));
    expect(CaseCodes.prescription('TM-2026-0012'), CaseCodes.prescription('TM-2026-0012'));
  });

  test('enlace de demostración con el formato de cada plataforma', () {
    expect(CaseCodes.meetingLink('TM-2026-0012', VideoPlatform.meet), 'https://meet.google.com/tmc-2026-0012');
    expect(CaseCodes.meetingLink('TM-2026-0012', VideoPlatform.zoom), 'https://zoom.us/j/20260012');
    expect(
      CaseCodes.meetingLink('TM-2026-0012', VideoPlatform.teams),
      'https://teams.microsoft.com/l/meetup-join/tm-2026-0012',
    );
  });

  group('seguro simulado', () {
    final gateway = SimulatedInsuranceGateway(
      catalog: catalog,
      clock: () => DateTime(2026, 11, 9, 10),
      delay: Duration.zero,
    );

    test('aprueba con la cobertura del plan y genera la autorización', () async {
      final result = await gateway.validate(patient: maria, service: generalConsult, caseId: 'TM-2026-0100');
      expect(result.approved, isTrue);
      expect(result.coveragePercent, 80);
      expect(result.authorizationNumber, 'AUT-20261109-0100');
      expect(result.at, DateTime(2026, 11, 9, 10));
    });

    test('resta 20 puntos a los servicios de cobertura reducida', () async {
      final result = await gateway.validate(patient: maria, service: nutrition, caseId: 'TM-2026-0100');
      expect(result.coveragePercent, 60);
    });

    test('rechaza una afiliación inactiva', () async {
      final result = await gateway.validate(patient: pedro, service: generalConsult, caseId: 'TM-2026-0101');
      expect(result.approved, isFalse);
      expect(result.message, 'Afiliación inactiva');
      expect(result.authorizationNumber, isNull);
    });

    test('la reclamación devuelve su número', () async {
      expect(await gateway.submitClaim(caseId: 'TM-2026-0100'), 'REC-10100');
    });
  });

  test('la confirmación devuelve el enlace de la plataforma', () async {
    final gateway = SimulatedConfirmationGateway(delay: Duration.zero);
    final link = await gateway.send(caseId: 'TM-2026-0100', platform: VideoPlatform.meet, via: RequestChannel.whatsapp);
    expect(link, 'https://meet.google.com/tmc-2026-0100');
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/data/gateways_test.dart
```

Expected: FAIL. No compila porque `case_codes.dart` y los gateways no existen.

- [ ] **Step 3: Crear el reloj y los códigos**

Create `saludconecta/lib/domain/services/clock.dart`:

```dart
/// Función que da la hora actual. En la app es `DateTime.now`; en las pruebas, una hora fija.
typedef Clock = DateTime Function();
```

Create `saludconecta/lib/domain/services/case_codes.dart`:

```dart
import '../models/enums.dart';

/// Códigos y enlaces deterministas que se derivan del ID del caso ("TM-2026-0012").
class CaseCodes {
  const CaseCodes._();

  /// Los últimos 4 dígitos del ID: "TM-2026-0012" → "0012".
  static String sequenceOf(String caseId) {
    final digits = caseId.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.substring(digits.length - 4);
  }

  /// Autorización del seguro: AUT-yyyyMMdd-NNNN.
  static String authorization(String caseId, DateTime at) => 'AUT-${_compactDate(at)}-${sequenceOf(caseId)}';

  /// Número de reclamación al seguro: REC-NNNNN.
  static String claim(String caseId) => 'REC-${10000 + int.parse(sequenceOf(caseId))}';

  /// Código de verificación de la receta (va en el QR): RX-2026-0012-XXXX.
  static String prescription(String caseId) {
    var hash = 7;
    for (final unit in caseId.codeUnits) {
      hash = (hash * 31 + unit) & 0xFFFF;
    }
    final check = hash.toRadixString(16).toUpperCase().padLeft(4, '0');
    return 'RX-${caseId.substring(3)}-$check';
  }

  /// Enlace de demostración de la videollamada, con el formato de cada plataforma.
  static String meetingLink(String caseId, VideoPlatform platform) {
    final slug = caseId.toLowerCase();
    return switch (platform) {
      VideoPlatform.teams => 'https://teams.microsoft.com/l/meetup-join/$slug',
      VideoPlatform.zoom => 'https://zoom.us/j/${caseId.replaceAll(RegExp(r'[^0-9]'), '')}',
      VideoPlatform.meet => 'https://meet.google.com/${slug.replaceFirst('tm-', 'tmc-')}',
    };
  }

  static String _compactDate(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}
```

- [ ] **Step 4: Crear los gateways simulados**

Create `saludconecta/lib/data/gateways/insurance_gateway.dart`:

```dart
import '../../domain/models/case_records.dart';
import '../../domain/models/catalog.dart';
import '../../domain/models/people.dart';
import '../../domain/services/case_codes.dart';
import '../../domain/services/clock.dart';
import '../repositories/catalog_repository.dart';

/// Conexión con la aseguradora. En esta demostración es simulada.
abstract class InsuranceGateway {
  /// Paso 3: valida afiliación, cobertura y autorización.
  Future<InsuranceValidation> validate({
    required Patient patient,
    required MedicalService service,
    required String caseId,
  });

  /// Paso 9: envía la reclamación y devuelve su número.
  Future<String> submitClaim({required String caseId});
}

/// Seguro simulado: responde después de una pausa, como lo haría un servicio real.
class SimulatedInsuranceGateway implements InsuranceGateway {
  SimulatedInsuranceGateway({
    required this.catalog,
    this.clock = DateTime.now,
    this.delay = const Duration(milliseconds: 1500),
  });

  final CatalogRepository catalog;
  final Clock clock;
  final Duration delay;

  @override
  Future<InsuranceValidation> validate({
    required Patient patient,
    required MedicalService service,
    required String caseId,
  }) async {
    await Future<void>.delayed(delay);
    final affiliation = patient.affiliation;
    final at = clock();
    if (!affiliation.active) {
      return InsuranceValidation(approved: false, coveragePercent: 0, message: 'Afiliación inactiva', at: at);
    }
    final insurer = catalog.insurerById(affiliation.insurerId);
    return InsuranceValidation(
      approved: true,
      coveragePercent: insurer.coverageFor(affiliation.plan, service),
      authorizationNumber: CaseCodes.authorization(caseId, at),
      message: 'Cobertura aprobada por ${insurer.name} (plan ${affiliation.plan})',
      at: at,
    );
  }

  @override
  Future<String> submitClaim({required String caseId}) async {
    await Future<void>.delayed(delay);
    // En vivo la reclamación siempre se aprueba; las glosadas solo existen en los datos históricos.
    return CaseCodes.claim(caseId);
  }
}
```

Create `saludconecta/lib/data/gateways/confirmation_gateway.dart`:

```dart
import '../../domain/models/enums.dart';
import '../../domain/services/case_codes.dart';

/// Envío de la confirmación al paciente (paso 5). Es simulado: no se envía nada real.
abstract class ConfirmationGateway {
  /// "Envía" el enlace por [via] (WhatsApp o correo) y devuelve el enlace generado.
  Future<String> send({required String caseId, required VideoPlatform platform, required RequestChannel via});
}

class SimulatedConfirmationGateway implements ConfirmationGateway {
  SimulatedConfirmationGateway({this.delay = const Duration(seconds: 1)});

  final Duration delay;

  @override
  Future<String> send({required String caseId, required VideoPlatform platform, required RequestChannel via}) async {
    await Future<void>.delayed(delay);
    return CaseCodes.meetingLink(caseId, platform);
  }
}
```

- [ ] **Step 5: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/data/gateways_test.dart
```

Expected: `All tests passed!` (7 pruebas).

---

### Task 4: Reglas, flujo del proceso y facturación

**Files:**
- Create: `saludconecta/lib/domain/process/process_rules.dart`, `saludconecta/lib/domain/services/billing_calculator.dart`, `saludconecta/lib/domain/process/case_workflow.dart`
- Test: `saludconecta/test/support/fixtures.dart`, `saludconecta/test/domain/process_rules_test.dart`, `saludconecta/test/domain/billing_calculator_test.dart`

**Interfaces:**
- Consumes: modelos (tarea 1), `SeedCatalog`/`SeedIds` (tarea 2) y `CaseCodes` (tarea 3).
- Produces:
  - **`AssistAction`:** sus valores son `startConsultation`, `submitClaim`, `registerPayment` y `logFollowUpCall`, cada uno con `step`, `role` y `label`.
  - **`ProcessRules`** (funciones estáticas):
    - `ensureCanPerform(c, step, role)`;
    - `ensureCanAssist(c, action, role)`;
    - `canPatientCancel(c) → bool`;
    - `ensureCanCancel(c, role)`;
    - `ensureCanResolveRejection(c, role)`.
  - **`AuditItem(label, ok)`.**
  - **`BillingCalculator`** (funciones estáticas):
    - `coverageOf(c)` e `invoiceFor(c, service)`;
    - `claimStatusOf(c, invoice)` y `auditChecklist(c, invoice)`;
    - `paymentPending(c, invoice)` y `canClose(c, invoice)`.
  - **`CaseWorkflow`** (funciones estáticas; todas devuelven un `TelemedicineCase` nuevo):

    | Momento | Funciones |
    |---|---|
    | Paso 1 | `request(id:, patient:, service:, channel:, reason:, preferredDate:, at:)` |
    | Paso 2 | `registerReception(c, staffName:, notes:, at:)` |
    | Paso 3 | `applyInsuranceResult(c, result:, staffName:)`; tras un rechazo, `continueAsPrivate(c, staffName:, at:)` |
    | Cualquier momento | `cancel(c, role:, actorName:, at:, reason:)` |
    | Paso 4 | `schedule(c, doctor:, dateTime:, platform:, staffName:, at:)` |
    | Paso 5 | `confirm(c, link:, via:, staffName:, at:)` |
    | Paso 6 | `signConsent(c, patient:, acceptedTerms:, acceptedDataUse:, identityConfirmed:, signature:, at:)` |
    | Paso 7 | `startConsultation(c, doctor:, at:)` y `finishConsultation(c, doctor:, notes:, at:)` |
    | Paso 8 | `issueResults(c, doctor:, instructions:, medications:, orders:, referral:, followUpInDays:, at:)` |
    | Paso 9 | `recordClaim(c, service:, claimNumber:, status:, staffName:, at:)`, `registerPayment(c, service:, method:, staffName:, at:)` y `closeAdministratively(c, service:, staffName:, at:)` |
    | Paso 10 | `logFollowUpCall(c, staffName:, note:, at:)` y `submitSurvey(c, patient:, rating:, nps:, comment:, at:)` |

    Además, la constante `confirmationInstructions`.
  - **Fixtures de prueba:**
    - `catalog`, `maria`, `mendez`, `generalConsult`;
    - las constantes `ana` y `roberto`;
    - `start`, `appointmentTime`, `signature` y `notes`;
    - las funciones `approved()`, `rejected()`, `newCase()`, `closeCase()` y `caseAt(pending)`.

- [ ] **Step 1: Escribir los ayudantes de las pruebas**

Create `saludconecta/test/support/fixtures.dart`:

```dart
// Datos y ayudantes compartidos por las pruebas del dominio y de los datos.
import 'package:saludconecta/data/repositories/catalog_repository.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/case_records.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/models/telemedicine_case.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/case_codes.dart';

final CatalogRepository catalog = SeedCatalog.repository();
final maria = catalog.patientById(SeedIds.maria);
final mendez = catalog.doctorById(SeedIds.mendez);
final generalConsult = catalog.serviceById(SeedIds.generalConsult);

const ana = 'Ana Peña';
const roberto = 'Roberto Díaz';

/// Lunes 9 de noviembre de 2026, 9:00: inicio de los casos de prueba.
final start = DateTime(2026, 11, 9, 9);

/// Cita de los casos de prueba: jueves 12 de noviembre de 2026, 10:30, con el Dr. Méndez por Teams.
final appointmentTime = DateTime(2026, 11, 12, 10, 30);

const signature = [
  [SignaturePoint(0.1, 0.5), SignaturePoint(0.5, 0.2), SignaturePoint(0.9, 0.6)],
];

const notes = ClinicalNotes(
  chiefComplaint: 'Fiebre y dolor de garganta',
  assessment: 'Paciente estable',
  diagnosis: 'Faringitis aguda',
  plan: 'Analgésico y reposo',
);

InsuranceValidation approved(String caseId, DateTime at, {int coverage = 80}) => InsuranceValidation(
      approved: true,
      coveragePercent: coverage,
      authorizationNumber: CaseCodes.authorization(caseId, at),
      message: 'Cobertura aprobada',
      at: at,
    );

InsuranceValidation rejected(DateTime at) =>
    InsuranceValidation(approved: false, coveragePercent: 0, message: 'Afiliación inactiva', at: at);

/// Caso nuevo de María (Consulta médica general, RD$1,500): queda pendiente el paso 2.
TelemedicineCase newCase({String id = 'TM-2026-0100', RequestChannel channel = RequestChannel.whatsapp}) {
  return CaseWorkflow.request(
    id: id,
    patient: maria,
    service: generalConsult,
    channel: channel,
    reason: 'Dolor de garganta y fiebre',
    preferredDate: DateTime(2026, 11, 12),
    at: start,
  );
}

/// Reclamación aprobada, copago con tarjeta y cierre administrativo, todo en el momento [at].
TelemedicineCase closeCase(TelemedicineCase c, DateTime at) {
  var closed = CaseWorkflow.recordClaim(
    c,
    service: generalConsult,
    claimNumber: CaseCodes.claim(c.id),
    status: ClaimStatus.approved,
    staffName: roberto,
    at: at,
  );
  closed = CaseWorkflow.registerPayment(
    closed,
    service: generalConsult,
    method: PaymentMethod.card,
    staffName: roberto,
    at: at,
  );
  return CaseWorkflow.closeAdministratively(closed, service: generalConsult, staffName: roberto, at: at);
}

/// Avanza un caso nuevo de María hasta que [pending] sea el paso pendiente.
/// Con `null` recorre los 10 pasos y el caso queda completado.
/// Cada evento ocurre una hora después del anterior (h0 solicitud … h6 inicio de la consulta,
/// h7 fin, h8 resultados, h9 cierre, h10 encuesta).
TelemedicineCase caseAt(
  ProcessStep? pending, {
  String id = 'TM-2026-0100',
  RequestChannel channel = RequestChannel.whatsapp,
  int rating = 5,
  int nps = 10,
}) {
  var c = newCase(id: id, channel: channel);
  var hours = 0;
  DateTime next() => start.add(Duration(hours: ++hours));
  for (final step in ProcessStep.values.skip(1)) {
    if (step == pending) return c;
    c = switch (step) {
      ProcessStep.requestAppointment => c,
      ProcessStep.reception => CaseWorkflow.registerReception(c, staffName: ana, at: next()),
      ProcessStep.insuranceValidation =>
        CaseWorkflow.applyInsuranceResult(c, staffName: ana, result: approved(c.id, next())),
      ProcessStep.scheduling => CaseWorkflow.schedule(
          c,
          doctor: mendez,
          dateTime: appointmentTime,
          platform: VideoPlatform.teams,
          staffName: ana,
          at: next(),
        ),
      ProcessStep.patientConfirmation => CaseWorkflow.confirm(
          c,
          link: CaseCodes.meetingLink(c.id, VideoPlatform.teams),
          via: RequestChannel.whatsapp,
          staffName: ana,
          at: next(),
        ),
      ProcessStep.consentAdmission => CaseWorkflow.signConsent(
          c,
          patient: maria,
          acceptedTerms: true,
          acceptedDataUse: true,
          identityConfirmed: true,
          signature: signature,
          at: next(),
        ),
      ProcessStep.consultation => CaseWorkflow.finishConsultation(
          CaseWorkflow.startConsultation(c, doctor: mendez, at: next()),
          doctor: mendez,
          notes: notes,
          at: next(),
        ),
      ProcessStep.consultationResult => CaseWorkflow.issueResults(
          c,
          doctor: mendez,
          instructions: 'Reposo e hidratación',
          medications: const [
            PrescriptionItem(
              medication: 'Acetaminofén 500 mg',
              dose: '1 tableta',
              frequency: 'Cada 8 horas',
              duration: '5 días',
            ),
          ],
          followUpInDays: 15,
          at: next(),
        ),
      ProcessStep.administrativeClosure => closeCase(c, next()),
      ProcessStep.followUp => CaseWorkflow.submitSurvey(c, patient: maria, rating: rating, nps: nps, at: next()),
    };
  }
  return c;
}
```

- [ ] **Step 2: Escribir la prueba de las reglas del proceso**

Create `saludconecta/test/domain/process_rules_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/case_records.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/models/telemedicine_case.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_exception.dart';
import 'package:saludconecta/domain/process/process_rules.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../support/fixtures.dart';

final throwsProcessException = throwsA(isA<ProcessException>());

void main() {
  group('recorrido del proceso', () {
    test('al crear la solicitud queda pendiente la recepción', () {
      final c = newCase();
      expect(c.status, CaseStatus.active);
      expect(c.currentStep, ProcessStep.reception);
      expect(c.completedSteps, {ProcessStep.requestAppointment});
      expect(c.events.single.title, 'Solicitud enviada por WhatsApp');
    });

    test('un caso recorre los 10 pasos y queda completado', () {
      final c = caseAt(null);
      expect(c.status, CaseStatus.completed);
      expect(c.currentStep, ProcessStep.followUp);
      expect(c.completedSteps, ProcessStep.values.toSet());
      expect(c.followUp!.survey!.rating, 5);
    });

    test('el motivo debe tener al menos 10 caracteres', () {
      expect(
        () => CaseWorkflow.request(
          id: 'TM-2026-0100',
          patient: maria,
          service: generalConsult,
          channel: RequestChannel.email,
          reason: 'Fiebre',
          preferredDate: start,
          at: start,
        ),
        throwsProcessException,
      );
    });

    test('no se puede completar un paso fuera de orden', () {
      expect(
        () => CaseWorkflow.schedule(
          newCase(),
          doctor: mendez,
          dateTime: appointmentTime,
          platform: VideoPlatform.zoom,
          staffName: ana,
          at: start,
        ),
        throwsProcessException,
      );
    });

    test('otro rol no puede completar el paso', () {
      expect(() => ProcessRules.ensureCanPerform(newCase(), ProcessStep.reception, UserRole.doctor), throwsProcessException);
      expect(() => ProcessRules.ensureCanPerform(newCase(), ProcessStep.reception, UserRole.admission), returnsNormally);
    });

    test('no se puede operar sobre un caso cancelado', () {
      final cancelled = CaseWorkflow.cancel(newCase(), role: UserRole.patient, actorName: maria.fullName, at: start);
      expect(cancelled.status, CaseStatus.cancelled);
      expect(cancelled.events.last.kind, EventKind.cancelled);
      expect(() => CaseWorkflow.registerReception(cancelled, staffName: ana, at: start), throwsProcessException);
    });
  });

  group('rechazo del seguro', () {
    TelemedicineCase rejectedCase() => CaseWorkflow.applyInsuranceResult(
          caseAt(ProcessStep.insuranceValidation),
          staffName: ana,
          result: rejected(start),
        );

    test('el caso queda rechazado y sigue en el paso 3', () {
      final c = rejectedCase();
      expect(c.status, CaseStatus.insuranceRejected);
      expect(c.currentStep, ProcessStep.insuranceValidation);
      expect(c.isStepCompleted(ProcessStep.insuranceValidation), isFalse);
      expect(c.events.last.kind, EventKind.rejected);
    });

    test('continuar como privado completa el paso 3 y pasa al agendamiento', () {
      final c = CaseWorkflow.continueAsPrivate(rejectedCase(), staffName: ana, at: start);
      expect(c.status, CaseStatus.active);
      expect(c.privatePay, isTrue);
      expect(c.currentStep, ProcessStep.scheduling);
      expect(c.isStepCompleted(ProcessStep.insuranceValidation), isTrue);
      expect(c.events.last.title, 'Paciente privado (100%)');
    });

    test('Admisión puede cancelar una solicitud rechazada', () {
      final c = CaseWorkflow.cancel(rejectedCase(), role: UserRole.admission, actorName: ana, at: start);
      expect(c.status, CaseStatus.cancelled);
    });

    test('Admisión no cancela solicitudes activas ni resuelve casos sin rechazo', () {
      expect(() => CaseWorkflow.cancel(newCase(), role: UserRole.admission, actorName: ana, at: start), throwsProcessException);
      expect(() => CaseWorkflow.continueAsPrivate(newCase(), staffName: ana, at: start), throwsProcessException);
    });
  });

  group('cancelación del paciente', () {
    test('puede cancelar hasta el paso 6', () {
      expect(ProcessRules.canPatientCancel(caseAt(ProcessStep.reception)), isTrue);
      expect(ProcessRules.canPatientCancel(caseAt(ProcessStep.consentAdmission)), isTrue);
    });

    test('no puede cancelar desde la consulta en adelante', () {
      final c = caseAt(ProcessStep.consultation);
      expect(ProcessRules.canPatientCancel(c), isFalse);
      expect(() => CaseWorkflow.cancel(c, role: UserRole.patient, actorName: maria.fullName, at: start), throwsProcessException);
    });
  });

  group('consulta y resultados', () {
    test('iniciar la consulta es una acción auxiliar: no completa el paso 7', () {
      final c = CaseWorkflow.startConsultation(caseAt(ProcessStep.consultation), doctor: mendez, at: start);
      expect(c.currentStep, ProcessStep.consultation);
      expect(c.consultation, isNotNull);
      expect(c.events.last.kind, EventKind.started);
      expect(c.events.last.completesStep, isFalse);
    });

    test('otro médico no puede atender la cita', () {
      final other = catalog.doctorById(SeedIds.jimenez);
      expect(
        () => CaseWorkflow.startConsultation(caseAt(ProcessStep.consultation), doctor: other, at: start),
        throwsProcessException,
      );
    });

    test('finalizar exige motivo y diagnóstico', () {
      final started = CaseWorkflow.startConsultation(caseAt(ProcessStep.consultation), doctor: mendez, at: start);
      expect(
        () => CaseWorkflow.finishConsultation(
          started,
          doctor: mendez,
          notes: const ClinicalNotes(chiefComplaint: 'Fiebre'),
          at: start,
        ),
        throwsProcessException,
      );
    });

    test('emitir resultados exige indicaciones y genera el código de la receta', () {
      final c = caseAt(ProcessStep.consultationResult);
      expect(() => CaseWorkflow.issueResults(c, doctor: mendez, instructions: '  ', at: start), throwsProcessException);
      final issued = caseAt(ProcessStep.administrativeClosure);
      expect(issued.results!.prescription!.verificationCode, startsWith('RX-2026-0100-'));
      expect(issued.results!.followUpInDays, 15);
      expect(issued.events.last.detail, 'Receta (1) · Seguimiento en 15 días');
    });
  });

  group('cierre administrativo', () {
    test('no se puede cerrar sin reclamación ni pago', () {
      final c = caseAt(ProcessStep.administrativeClosure);
      expect(
        () => CaseWorkflow.closeAdministratively(c, service: generalConsult, staffName: roberto, at: start),
        throwsProcessException,
      );
    });

    test('las acciones auxiliares del paso 9 son solo de Facturación', () {
      final c = caseAt(ProcessStep.administrativeClosure);
      expect(() => ProcessRules.ensureCanAssist(c, AssistAction.submitClaim, UserRole.admission), throwsProcessException);
      expect(() => ProcessRules.ensureCanAssist(c, AssistAction.submitClaim, UserRole.billing), returnsNormally);
    });

    test('con la reclamación aprobada y el copago pagado se cierra y pasa a seguimiento', () {
      final c = caseAt(ProcessStep.followUp);
      expect(c.billing!.closedAt, isNotNull);
      expect(c.billing!.claimStatus, ClaimStatus.approved);
      expect(c.billing!.payment!.amount, 300);
      expect(c.currentStep, ProcessStep.followUp);
      expect(c.status, CaseStatus.active);
    });
  });

  group('seguimiento', () {
    test('Admisión registra llamadas sin completar el paso 10', () {
      final c = CaseWorkflow.logFollowUpCall(caseAt(ProcessStep.followUp), staffName: ana, note: 'Paciente mejor', at: start);
      expect(c.followUp!.calls, hasLength(1));
      expect(c.status, CaseStatus.active);
      expect(c.events.last.kind, EventKind.call);
    });

    test('la encuesta valida el rango de estrellas y de recomendación', () {
      final c = caseAt(ProcessStep.followUp);
      expect(() => CaseWorkflow.submitSurvey(c, patient: maria, rating: 6, nps: 10, at: start), throwsProcessException);
      expect(() => CaseWorkflow.submitSurvey(c, patient: maria, rating: 5, nps: 11, at: start), throwsProcessException);
    });
  });
}
```

- [ ] **Step 3: Escribir la prueba de la facturación**

Create `saludconecta/test/domain/billing_calculator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/billing_calculator.dart';

import '../support/fixtures.dart';

void main() {
  test('copago con la cobertura del plan (Salud Plena Plus 80%)', () {
    final invoice = BillingCalculator.invoiceFor(caseAt(ProcessStep.administrativeClosure), generalConsult);
    expect(invoice.fee, 1500);
    expect(invoice.coveragePercent, 80);
    expect(invoice.insurerAmount, 1200);
    expect(invoice.copay, 300);
  });

  test('los servicios de cobertura reducida pierden 20 puntos', () {
    final insurer = catalog.insurerById('salud-plena');
    expect(insurer.coverageFor('Plus', catalog.serviceById(SeedIds.nutrition)), 60);
    expect(insurer.coverageFor('Plus', generalConsult), 80);
  });

  test('el paciente privado paga el 100% y la reclamación no aplica', () {
    final rejectedCase = CaseWorkflow.applyInsuranceResult(
      caseAt(ProcessStep.insuranceValidation),
      staffName: ana,
      result: rejected(start),
    );
    final privateCase = CaseWorkflow.continueAsPrivate(rejectedCase, staffName: ana, at: start);
    final invoice = BillingCalculator.invoiceFor(privateCase, generalConsult);
    expect(invoice.coveragePercent, 0);
    expect(invoice.insurerAmount, 0);
    expect(invoice.copay, 1500);
    expect(BillingCalculator.claimStatusOf(privateCase, invoice), ClaimStatus.notApplicable);
  });

  test('la parte del seguro se redondea', () {
    const service = MedicalService(
      id: 'prueba',
      name: 'Servicio de prueba',
      group: ServiceGroup.clinical,
      description: '',
      iconKey: 'stethoscope',
      requestable: true,
      fee: 1250,
    );
    final c = CaseWorkflow.applyInsuranceResult(
      caseAt(ProcessStep.insuranceValidation),
      staffName: ana,
      result: approved('TM-2026-0100', start, coverage: 65),
    );
    final invoice = BillingCalculator.invoiceFor(c, service);
    expect(invoice.insurerAmount, 813, reason: '1250 × 65% = 812.5, que se redondea a 813');
    expect(invoice.copay, 437);
  });

  test('antes de la reclamación la auditoría está incompleta', () {
    final c = caseAt(ProcessStep.administrativeClosure);
    final invoice = BillingCalculator.invoiceFor(c, generalConsult);
    final failing = BillingCalculator.auditChecklist(c, invoice).where((item) => !item.ok).map((item) => item.label);
    expect(failing, ['Reclamación aprobada o no aplica']);
    expect(BillingCalculator.canClose(c, invoice), isFalse);
  });

  test('con la reclamación aprobada y el pago registrado se puede cerrar', () {
    var c = caseAt(ProcessStep.administrativeClosure);
    c = CaseWorkflow.recordClaim(
      c,
      service: generalConsult,
      claimNumber: 'REC-10100',
      status: ClaimStatus.approved,
      staffName: roberto,
      at: start,
    );
    final invoice = BillingCalculator.invoiceFor(c, generalConsult);
    expect(BillingCalculator.auditChecklist(c, invoice).every((item) => item.ok), isTrue);
    expect(BillingCalculator.paymentPending(c, invoice), isTrue);
    expect(BillingCalculator.canClose(c, invoice), isFalse);
    c = CaseWorkflow.registerPayment(c, service: generalConsult, method: PaymentMethod.cash, staffName: roberto, at: start);
    expect(BillingCalculator.paymentPending(c, invoice), isFalse);
    expect(BillingCalculator.canClose(c, invoice), isTrue);
  });
}
```

- [ ] **Step 4: Ejecutar las pruebas y verificar que fallan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/domain/process_rules_test.dart test/domain/billing_calculator_test.dart
```

Expected: FAIL. No compila porque `process_rules.dart`, `billing_calculator.dart` y `case_workflow.dart` no existen.

- [ ] **Step 5: Crear las reglas del proceso**

Create `saludconecta/lib/domain/process/process_rules.dart`:

```dart
import '../models/enums.dart';
import '../models/telemedicine_case.dart';
import 'process_exception.dart';
import 'process_step.dart';

/// Acciones auxiliares: ocurren dentro de un paso, pero no lo completan.
enum AssistAction {
  startConsultation(ProcessStep.consultation, UserRole.doctor, 'iniciar la consulta'),
  submitClaim(ProcessStep.administrativeClosure, UserRole.billing, 'enviar la reclamación'),
  registerPayment(ProcessStep.administrativeClosure, UserRole.billing, 'registrar el pago'),
  logFollowUpCall(ProcessStep.followUp, UserRole.admission, 'registrar una llamada de seguimiento');

  const AssistAction(this.step, this.role, this.label);

  final ProcessStep step;
  final UserRole role;
  final String label;
}

/// Reglas del proceso. Si algo no está permitido, lanzan [ProcessException].
class ProcessRules {
  const ProcessRules._();

  /// [role] quiere completar [step] en el caso [c].
  static void ensureCanPerform(TelemedicineCase c, ProcessStep step, UserRole role) {
    _ensureActive(c);
    if (c.currentStep != step) {
      throw ProcessException(
        'El caso ${c.id} está en el paso ${c.currentStep.number} (${c.currentStep.title}), '
        'no en el paso ${step.number}.',
      );
    }
    if (!step.isOwnedBy(role)) {
      throw ProcessException('${role.label} no puede completar el paso ${step.number} (${step.title}).');
    }
  }

  /// [role] quiere hacer una acción auxiliar del paso actual.
  static void ensureCanAssist(TelemedicineCase c, AssistAction action, UserRole role) {
    _ensureActive(c);
    if (c.currentStep != action.step) {
      throw ProcessException('Solo se puede ${action.label} en el paso ${action.step.number} (${action.step.title}).');
    }
    if (role != action.role) {
      throw ProcessException('${role.label} no puede ${action.label}.');
    }
  }

  /// El paciente puede cancelar mientras el caso esté abierto y no haya pasado del paso 6.
  static bool canPatientCancel(TelemedicineCase c) =>
      c.status.isOpen && c.currentStep.number <= ProcessStep.consentAdmission.number;

  static void ensureCanCancel(TelemedicineCase c, UserRole role) {
    switch (role) {
      case UserRole.patient:
        if (!canPatientCancel(c)) {
          throw const ProcessException('La cita ya no se puede cancelar: la consulta está en curso o ya terminó.');
        }
      case UserRole.admission:
        if (c.status != CaseStatus.insuranceRejected) {
          throw const ProcessException('Admisión solo cancela solicitudes rechazadas por el seguro.');
        }
      case UserRole.doctor || UserRole.billing:
        throw ProcessException('${role.label} no puede cancelar solicitudes.');
    }
  }

  /// Continuar como privado o cancelar tras el rechazo es decisión de Admisión.
  static void ensureCanResolveRejection(TelemedicineCase c, UserRole role) {
    if (c.status != CaseStatus.insuranceRejected) {
      throw const ProcessException('El caso no tiene un rechazo del seguro pendiente.');
    }
    if (role != UserRole.admission) {
      throw ProcessException('${role.label} no puede resolver el rechazo del seguro.');
    }
  }

  static void _ensureActive(TelemedicineCase c) {
    if (c.status != CaseStatus.active) {
      throw ProcessException('El caso ${c.id} está "${c.status.label}" y no admite este cambio.');
    }
  }
}
```

- [ ] **Step 6: Crear la calculadora de facturación**

Create `saludconecta/lib/domain/services/billing_calculator.dart`:

```dart
import '../models/case_records.dart';
import '../models/catalog.dart';
import '../models/enums.dart';
import '../models/telemedicine_case.dart';

/// Un punto de la auditoría del cierre administrativo.
class AuditItem {
  const AuditItem(this.label, this.ok);

  final String label;
  final bool ok;
}

/// Cálculos del paso 9: factura, copago, auditoría y regla de cierre.
class BillingCalculator {
  const BillingCalculator._();

  /// % que cubre el seguro: 0 si el paciente es privado o si el seguro no aprobó.
  static int coverageOf(TelemedicineCase c) {
    final insurance = c.insurance;
    if (c.privatePay || insurance == null || !insurance.approved) return 0;
    return insurance.coveragePercent;
  }

  /// Factura del caso: tarifa, parte del seguro (redondeada) y copago.
  static Invoice invoiceFor(TelemedicineCase c, MedicalService service) {
    final fee = service.fee ?? 0;
    final coverage = coverageOf(c);
    final insurerAmount = (fee * coverage / 100).round();
    return Invoice(fee: fee, coveragePercent: coverage, insurerAmount: insurerAmount, copay: fee - insurerAmount);
  }

  /// Estado de la reclamación: el registrado, o el inicial según la factura.
  static ClaimStatus claimStatusOf(TelemedicineCase c, Invoice invoice) =>
      c.billing?.claimStatus ?? (invoice.insurerAmount == 0 ? ClaimStatus.notApplicable : ClaimStatus.pending);

  /// Lista de auditoría. Todas las casillas deben estar en ✓ para cerrar.
  static List<AuditItem> auditChecklist(TelemedicineCase c, Invoice invoice) {
    final claim = claimStatusOf(c, invoice);
    final insurance = c.insurance;
    final authorized =
        c.privatePay || (insurance != null && insurance.approved && insurance.authorizationNumber != null);
    return [
      AuditItem('Consentimiento informado firmado', c.consent != null),
      AuditItem('Autorización del seguro o paciente privado', authorized),
      AuditItem('Notas clínicas completas', c.consultation?.notes.isComplete ?? false),
      AuditItem('Resultados de la consulta emitidos', c.results != null),
      AuditItem('Reclamación aprobada o no aplica', claim == ClaimStatus.approved || claim == ClaimStatus.notApplicable),
    ];
  }

  /// ¿Falta cobrar el copago?
  static bool paymentPending(TelemedicineCase c, Invoice invoice) => invoice.copay > 0 && c.billing?.payment == null;

  /// Se puede cerrar cuando la auditoría está completa y el copago está pagado (o es 0).
  static bool canClose(TelemedicineCase c, Invoice invoice) =>
      auditChecklist(c, invoice).every((item) => item.ok) && !paymentPending(c, invoice);
}
```

- [ ] **Step 7: Crear el flujo del proceso**

Create `saludconecta/lib/domain/process/case_workflow.dart`:

```dart
import '../models/case_records.dart';
import '../models/catalog.dart';
import '../models/enums.dart';
import '../models/people.dart';
import '../models/process_event.dart';
import '../models/telemedicine_case.dart';
import '../services/billing_calculator.dart';
import '../services/case_codes.dart';
import 'process_exception.dart';
import 'process_rules.dart';
import 'process_step.dart';

/// Transiciones del proceso. Cada función valida con [ProcessRules] y devuelve un caso
/// NUEVO (los modelos son inmutables) con su evento al final de la línea de tiempo.
///
/// Las usan el `CaseProvider` (acciones en vivo) y el generador de datos semilla (históricos).
class CaseWorkflow {
  const CaseWorkflow._();

  /// Instrucciones que acompañan el enlace de la videollamada (paso 5).
  static const confirmationInstructions = 'Ingresa 10 minutos antes. Firma tu consentimiento en la app.';

  // ----- Paso 1: solicitud de cita -----

  static TelemedicineCase request({
    required String id,
    required Patient patient,
    required MedicalService service,
    required RequestChannel channel,
    required String reason,
    required DateTime preferredDate,
    required DateTime at,
  }) {
    if (!service.requestable) {
      throw ProcessException('"${service.name}" no se solicita directamente: se genera durante el proceso.');
    }
    if (reason.trim().length < 10) {
      throw const ProcessException('Describe el motivo de consulta con al menos 10 caracteres.');
    }
    return TelemedicineCase(
      id: id,
      patientId: patient.id,
      serviceId: service.id,
      channel: channel,
      reason: reason.trim(),
      preferredDate: preferredDate,
      createdAt: at,
      currentStep: ProcessStep.reception,
      status: CaseStatus.active,
      events: [
        ProcessEvent(
          step: ProcessStep.requestAppointment,
          actor: Actor.patient,
          actorName: patient.fullName,
          at: at,
          title: 'Solicitud enviada por ${channel.label}',
          detail: service.name,
        ),
      ],
    );
  }

  // ----- Paso 2: recepción -----

  static TelemedicineCase registerReception(
    TelemedicineCase c, {
    required String staffName,
    String notes = '',
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.reception, UserRole.admission);
    return c.copyWith(
      reception: ReceptionData(registeredBy: staffName, notes: notes.trim()),
      currentStep: ProcessStep.insuranceValidation,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.reception,
          actor: Actor.admission,
          actorName: staffName,
          at: at,
          title: 'Solicitud registrada',
          detail: notes.trim(),
        ),
      ],
    );
  }

  // ----- Paso 3: validación con el seguro -----

  /// Aplica la respuesta del seguro. Si la rechaza, el caso queda en `insuranceRejected` en el paso 3.
  static TelemedicineCase applyInsuranceResult(
    TelemedicineCase c, {
    required InsuranceValidation result,
    required String staffName,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.insuranceValidation, UserRole.admission);
    if (result.approved) {
      return c.copyWith(
        insurance: result,
        currentStep: ProcessStep.scheduling,
        events: [
          ...c.events,
          ProcessEvent(
            step: ProcessStep.insuranceValidation,
            actor: Actor.admission,
            actorName: staffName,
            at: result.at,
            title: 'Seguro aprobado: ${result.coveragePercent}% de cobertura',
            detail: result.authorizationNumber ?? '',
          ),
        ],
      );
    }
    return c.copyWith(
      insurance: result,
      status: CaseStatus.insuranceRejected,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.insuranceValidation,
          actor: Actor.admission,
          actorName: staffName,
          at: result.at,
          title: 'Seguro rechazado',
          detail: result.message,
          kind: EventKind.rejected,
        ),
      ],
    );
  }

  /// Tras el rechazo: el paciente paga el 100% y el caso sigue al paso 4.
  static TelemedicineCase continueAsPrivate(TelemedicineCase c, {required String staffName, required DateTime at}) {
    ProcessRules.ensureCanResolveRejection(c, UserRole.admission);
    return c.copyWith(
      privatePay: true,
      status: CaseStatus.active,
      currentStep: ProcessStep.scheduling,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.insuranceValidation,
          actor: Actor.admission,
          actorName: staffName,
          at: at,
          title: 'Paciente privado (100%)',
          detail: 'Continúa sin cobertura del seguro',
        ),
      ],
    );
  }

  /// Cancela la solicitud: el paciente, hasta el paso 6; Admisión, tras un rechazo del seguro.
  static TelemedicineCase cancel(
    TelemedicineCase c, {
    required UserRole role,
    required String actorName,
    required DateTime at,
    String reason = '',
  }) {
    ProcessRules.ensureCanCancel(c, role);
    return c.copyWith(
      status: CaseStatus.cancelled,
      events: [
        ...c.events,
        ProcessEvent(
          step: c.currentStep,
          actor: role.actor,
          actorName: actorName,
          at: at,
          title: 'Solicitud cancelada',
          detail: reason.trim(),
          kind: EventKind.cancelled,
        ),
      ],
    );
  }

  // ----- Paso 4: agendamiento -----

  static TelemedicineCase schedule(
    TelemedicineCase c, {
    required Doctor doctor,
    required DateTime dateTime,
    required VideoPlatform platform,
    required String staffName,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.scheduling, UserRole.admission);
    return c.copyWith(
      appointment: Appointment(doctorId: doctor.id, dateTime: dateTime, platform: platform),
      currentStep: ProcessStep.patientConfirmation,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.scheduling,
          actor: Actor.admission,
          actorName: staffName,
          at: at,
          title: 'Cita agendada con ${doctor.displayName}',
          detail: platform.label,
        ),
      ],
    );
  }

  // ----- Paso 5: confirmación al paciente -----

  static TelemedicineCase confirm(
    TelemedicineCase c, {
    required String link,
    required RequestChannel via,
    required String staffName,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.patientConfirmation, UserRole.admission);
    if (via != RequestChannel.whatsapp && via != RequestChannel.email) {
      throw const ProcessException('La confirmación se envía por WhatsApp o por correo.');
    }
    return c.copyWith(
      confirmation: Confirmation(link: link, sentVia: via, instructions: confirmationInstructions, at: at),
      currentStep: ProcessStep.consentAdmission,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.patientConfirmation,
          actor: Actor.admission,
          actorName: staffName,
          at: at,
          title: 'Enlace enviado por ${via.label}',
          detail: link,
        ),
      ],
    );
  }

  // ----- Paso 6: consentimiento y admisión virtual -----

  static TelemedicineCase signConsent(
    TelemedicineCase c, {
    required Patient patient,
    required bool acceptedTerms,
    required bool acceptedDataUse,
    required bool identityConfirmed,
    required List<List<SignaturePoint>> signature,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.consentAdmission, UserRole.patient);
    _ensureOwnPatient(c, patient);
    if (!acceptedTerms || !acceptedDataUse || !identityConfirmed) {
      throw const ProcessException('Marca las tres casillas del consentimiento.');
    }
    if (!signature.any((stroke) => stroke.length >= 2)) {
      throw const ProcessException('La firma es obligatoria.');
    }
    return c.copyWith(
      consent: ConsentRecord(at: at, identityConfirmed: true, signature: signature),
      currentStep: ProcessStep.consultation,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.consentAdmission,
          actor: Actor.patient,
          actorName: patient.fullName,
          at: at,
          title: 'Consentimiento firmado',
          detail: 'Identidad confirmada y admisión virtual completa',
        ),
      ],
    );
  }

  // ----- Paso 7: consulta de telemedicina -----

  /// Acción auxiliar: el médico abre la consulta (no completa el paso).
  static TelemedicineCase startConsultation(TelemedicineCase c, {required Doctor doctor, required DateTime at}) {
    ProcessRules.ensureCanAssist(c, AssistAction.startConsultation, UserRole.doctor);
    _ensureAssignedDoctor(c, doctor);
    if (c.consultation != null) return c; // Ya estaba iniciada.
    return c.copyWith(
      consultation: ConsultationRecord(startedAt: at),
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.consultation,
          actor: Actor.doctor,
          actorName: doctor.displayName,
          at: at,
          title: 'Consulta iniciada',
          detail: c.appointment!.platform.label,
          kind: EventKind.started,
        ),
      ],
    );
  }

  static TelemedicineCase finishConsultation(
    TelemedicineCase c, {
    required Doctor doctor,
    required ClinicalNotes notes,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.consultation, UserRole.doctor);
    _ensureAssignedDoctor(c, doctor);
    final started = c.consultation;
    if (started == null) {
      throw const ProcessException('Primero inicia la consulta.');
    }
    if (!notes.isComplete) {
      throw const ProcessException('Escribe el motivo de consulta y el diagnóstico antes de finalizar.');
    }
    return c.copyWith(
      consultation: ConsultationRecord(startedAt: started.startedAt, endedAt: at, notes: notes),
      currentStep: ProcessStep.consultationResult,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.consultation,
          actor: Actor.doctor,
          actorName: doctor.displayName,
          at: at,
          title: 'Consulta realizada',
          detail: 'Diagnóstico: ${notes.diagnosis.trim()}',
        ),
      ],
    );
  }

  // ----- Paso 8: resultado de la consulta -----

  static TelemedicineCase issueResults(
    TelemedicineCase c, {
    required Doctor doctor,
    required String instructions,
    List<PrescriptionItem> medications = const [],
    List<MedicalOrder> orders = const [],
    Referral? referral,
    int? followUpInDays,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.consultationResult, UserRole.doctor);
    _ensureAssignedDoctor(c, doctor);
    if (instructions.trim().isEmpty) {
      throw const ProcessException('Las indicaciones son obligatorias.');
    }
    final results = ConsultationResults(
      instructions: instructions.trim(),
      prescription: medications.isEmpty
          ? null
          : Prescription(items: medications, verificationCode: CaseCodes.prescription(c.id)),
      orders: orders,
      referral: referral,
      followUpInDays: followUpInDays,
    );
    return c.copyWith(
      results: results,
      currentStep: ProcessStep.administrativeClosure,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.consultationResult,
          actor: Actor.doctor,
          actorName: doctor.displayName,
          at: at,
          title: 'Resultados emitidos',
          detail: _resultsSummary(results),
        ),
      ],
    );
  }

  // ----- Paso 9: cierre administrativo -----

  /// Acción auxiliar: registra la reclamación al seguro y su respuesta.
  static TelemedicineCase recordClaim(
    TelemedicineCase c, {
    required MedicalService service,
    required String claimNumber,
    required ClaimStatus status,
    required String staffName,
    required DateTime at,
  }) {
    ProcessRules.ensureCanAssist(c, AssistAction.submitClaim, UserRole.billing);
    final invoice = BillingCalculator.invoiceFor(c, service);
    if (invoice.insurerAmount == 0) {
      throw const ProcessException('No aplica reclamación: el paciente es privado.');
    }
    final billing = (c.billing ?? BillingRecord(invoice: invoice, claimStatus: ClaimStatus.pending))
        .copyWith(claimStatus: status, claimNumber: claimNumber);
    return c.copyWith(
      billing: billing,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.administrativeClosure,
          actor: Actor.billing,
          actorName: staffName,
          at: at,
          title: 'Reclamación ${status.label.toLowerCase()}',
          detail: claimNumber,
          kind: EventKind.claim,
        ),
      ],
    );
  }

  /// Acción auxiliar: registra el pago del copago (solo el método; nunca datos de tarjeta).
  static TelemedicineCase registerPayment(
    TelemedicineCase c, {
    required MedicalService service,
    required PaymentMethod method,
    required String staffName,
    required DateTime at,
  }) {
    ProcessRules.ensureCanAssist(c, AssistAction.registerPayment, UserRole.billing);
    final invoice = BillingCalculator.invoiceFor(c, service);
    if (invoice.copay == 0) {
      throw const ProcessException('No hay copago que cobrar.');
    }
    if (c.billing?.payment != null) {
      throw const ProcessException('El pago ya está registrado.');
    }
    final billing = (c.billing ?? BillingRecord(invoice: invoice, claimStatus: BillingCalculator.claimStatusOf(c, invoice)))
        .copyWith(payment: Payment(method: method, amount: invoice.copay, at: at));
    return c.copyWith(
      billing: billing,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.administrativeClosure,
          actor: Actor.billing,
          actorName: staffName,
          at: at,
          title: 'Copago registrado',
          detail: 'Pagado con ${method.label.toLowerCase()}',
          kind: EventKind.payment,
        ),
      ],
    );
  }

  static TelemedicineCase closeAdministratively(
    TelemedicineCase c, {
    required MedicalService service,
    required String staffName,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.administrativeClosure, UserRole.billing);
    final invoice = BillingCalculator.invoiceFor(c, service);
    if (!BillingCalculator.canClose(c, invoice)) {
      throw const ProcessException('Aún no se puede cerrar: revisa la auditoría, la reclamación y el pago.');
    }
    final billing = (c.billing ?? BillingRecord(invoice: invoice, claimStatus: BillingCalculator.claimStatusOf(c, invoice)))
        .copyWith(closedAt: at);
    return c.copyWith(
      billing: billing,
      currentStep: ProcessStep.followUp,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.administrativeClosure,
          actor: Actor.billing,
          actorName: staffName,
          at: at,
          title: 'Cierre administrativo completado',
          detail: 'Factura, reclamación, auditoría y pago',
        ),
      ],
    );
  }

  // ----- Paso 10: seguimiento al paciente -----

  /// Acción auxiliar: Admisión registra una llamada de seguimiento.
  static TelemedicineCase logFollowUpCall(
    TelemedicineCase c, {
    required String staffName,
    required String note,
    required DateTime at,
  }) {
    ProcessRules.ensureCanAssist(c, AssistAction.logFollowUpCall, UserRole.admission);
    if (note.trim().isEmpty) {
      throw const ProcessException('Escribe una nota de la llamada.');
    }
    final record = c.followUp ?? const FollowUpRecord();
    return c.copyWith(
      followUp: record.copyWith(calls: [...record.calls, FollowUpCall(at: at, byName: staffName, note: note.trim())]),
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.followUp,
          actor: Actor.admission,
          actorName: staffName,
          at: at,
          title: 'Llamada de seguimiento',
          detail: note.trim(),
          kind: EventKind.call,
        ),
      ],
    );
  }

  /// El paciente responde la encuesta: completa el paso 10 y el caso.
  static TelemedicineCase submitSurvey(
    TelemedicineCase c, {
    required Patient patient,
    required int rating,
    required int nps,
    String comment = '',
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.followUp, UserRole.patient);
    _ensureOwnPatient(c, patient);
    if (rating < 1 || rating > 5) {
      throw const ProcessException('Elige de 1 a 5 estrellas.');
    }
    if (nps < 0 || nps > 10) {
      throw const ProcessException('La recomendación va de 0 a 10.');
    }
    final record = c.followUp ?? const FollowUpRecord();
    return c.copyWith(
      status: CaseStatus.completed,
      followUp: record.copyWith(survey: Survey(rating: rating, nps: nps, comment: comment.trim(), at: at)),
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.followUp,
          actor: Actor.patient,
          actorName: patient.fullName,
          at: at,
          title: 'Encuesta respondida: $rating de 5 estrellas',
          detail: comment.trim(),
        ),
      ],
    );
  }

  // ----- Ayudantes -----

  static void _ensureOwnPatient(TelemedicineCase c, Patient patient) {
    if (patient.id != c.patientId) {
      throw const ProcessException('Este caso pertenece a otro paciente.');
    }
  }

  static void _ensureAssignedDoctor(TelemedicineCase c, Doctor doctor) {
    if (c.appointment?.doctorId != doctor.id) {
      throw const ProcessException('La cita está asignada a otro médico.');
    }
  }

  /// Resumen para la línea de tiempo, p. ej. "Receta (2) · Laboratorio (1) · Seguimiento en 15 días".
  static String _resultsSummary(ConsultationResults r) {
    final lab = r.ordersOf(OrderType.lab).length;
    final imaging = r.ordersOf(OrderType.imaging).length;
    final parts = <String>[
      if (r.prescription != null) 'Receta (${r.prescription!.items.length})',
      if (lab > 0) 'Laboratorio ($lab)',
      if (imaging > 0) 'Imágenes ($imaging)',
      if (r.referral != null) 'Referimiento a ${r.referral!.specialty.label}',
      if (r.followUpInDays != null) 'Seguimiento en ${r.followUpInDays} días',
    ];
    return parts.isEmpty ? 'Indicaciones' : parts.join(' · ');
  }
}
```

- [ ] **Step 8: Ejecutar las pruebas y verificar que pasan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/domain/process_rules_test.dart test/domain/billing_calculator_test.dart
```

Expected: `All tests passed!` (27 pruebas: 21 de reglas y 6 de facturación).

---

### Task 5: Agenda de los médicos

**Files:**
- Create: `saludconecta/lib/domain/services/schedule_service.dart`
- Test: `saludconecta/test/domain/schedule_service_test.dart`

**Interfaces:**
- Consumes: `Doctor`, `TelemedicineCase` y los fixtures (tarea 4).
- Produces:
  - **Constantes de `ScheduleService`:** `slotMinutes` (30), `horizonDays` (14), `breakHour` (12) y `minimumLead` (1 h).
  - **`ScheduleService.availableSlots({required Doctor doctor, required DateTime day, required Iterable<TelemedicineCase> cases, required DateTime now}) → List<DateTime>`.**
  - **`ScheduleService.bookedSlots(String doctorId, Iterable<TelemedicineCase> cases) → Set<DateTime>`.**
  - **`ScheduleService.availableDays({required Doctor doctor, required Iterable<TelemedicineCase> cases, required DateTime now}) → List<DateTime>`.**

- [ ] **Step 1: Escribir la prueba de la agenda**

Create `saludconecta/test/domain/schedule_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/schedule_service.dart';

import '../support/fixtures.dart';

void main() {
  // Lunes 9 de noviembre de 2026, 8:00.
  final monday8 = DateTime(2026, 11, 9, 8);
  final thursday = DateTime(2026, 11, 12);

  test('turnos de 30 minutos, sin la pausa de 12:00 a 13:00', () {
    final slots = ScheduleService.availableSlots(doctor: mendez, day: thursday, cases: const [], now: monday8);
    expect(slots, hasLength(16));
    expect(slots.first, DateTime(2026, 11, 12, 8));
    expect(slots.last, DateTime(2026, 11, 12, 16, 30));
    expect(slots.where((slot) => slot.hour == 12), isEmpty);
  });

  test('excluye los turnos ocupados por otros casos', () {
    // Este caso tiene cita el jueves a las 10:30 con el Dr. Méndez.
    final booked = caseAt(ProcessStep.patientConfirmation);
    final slots = ScheduleService.availableSlots(doctor: mendez, day: thursday, cases: [booked], now: monday8);
    expect(slots, isNot(contains(DateTime(2026, 11, 12, 10, 30))));
    expect(slots, hasLength(15));
  });

  test('excluye el pasado y la hora mínima de anticipación', () {
    final slots = ScheduleService.availableSlots(
      doctor: mendez,
      day: DateTime(2026, 11, 9),
      cases: const [],
      now: DateTime(2026, 11, 9, 10, 10),
    );
    expect(slots.first, DateTime(2026, 11, 9, 11, 30));
  });

  test('respeta los días laborables de cada médico', () {
    final saturday = DateTime(2026, 11, 14);
    final sunday = DateTime(2026, 11, 15);
    final jimenez = catalog.doctorById(SeedIds.jimenez);
    expect(ScheduleService.availableSlots(doctor: mendez, day: sunday, cases: const [], now: monday8), isEmpty);
    expect(ScheduleService.availableSlots(doctor: mendez, day: saturday, cases: const [], now: monday8), hasLength(8));
    expect(ScheduleService.availableSlots(doctor: jimenez, day: saturday, cases: const [], now: monday8), isEmpty);
  });

  test('días disponibles en los próximos 14 días, sin domingos', () {
    final days = ScheduleService.availableDays(doctor: mendez, cases: const [], now: monday8);
    expect(days, hasLength(12), reason: '14 días menos 2 domingos');
    expect(days.where((day) => day.weekday == DateTime.sunday), isEmpty);
    expect(days.first, DateTime(2026, 11, 9));
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/domain/schedule_service_test.dart
```

Expected: FAIL. No compila porque `schedule_service.dart` no existe.

- [ ] **Step 3: Crear el servicio de agenda**

Create `saludconecta/lib/domain/services/schedule_service.dart`:

```dart
import '../models/enums.dart';
import '../models/people.dart';
import '../models/telemedicine_case.dart';

/// Calcula los turnos disponibles de los médicos (paso 4).
class ScheduleService {
  const ScheduleService._();

  static const slotMinutes = 30;
  static const horizonDays = 14;

  /// Hora de la pausa del mediodía (12:00–13:00), que no se agenda.
  static const breakHour = 12;

  /// No se agenda nada antes de una hora desde ahora.
  static const minimumLead = Duration(hours: 1);

  /// Turnos libres de [doctor] el día [day].
  static List<DateTime> availableSlots({
    required Doctor doctor,
    required DateTime day,
    required Iterable<TelemedicineCase> cases,
    required DateTime now,
  }) {
    final hours = doctor.schedule[day.weekday];
    if (hours == null) return const [];
    final booked = bookedSlots(doctor.id, cases);
    final earliest = now.add(minimumLead);
    final slots = <DateTime>[];
    for (var minute = hours.startHour * 60; minute < hours.endHour * 60; minute += slotMinutes) {
      if (minute ~/ 60 == breakHour) continue;
      final slot = DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);
      if (slot.isBefore(earliest) || booked.contains(slot)) continue;
      slots.add(slot);
    }
    return slots;
  }

  /// Horas ya ocupadas por citas de casos no cancelados.
  static Set<DateTime> bookedSlots(String doctorId, Iterable<TelemedicineCase> cases) {
    return {
      for (final c in cases)
        if (c.status != CaseStatus.cancelled && c.appointment != null && c.appointment!.doctorId == doctorId)
          c.appointment!.dateTime,
    };
  }

  /// Días (desde hoy y dentro de los próximos 14) con al menos un turno libre.
  static List<DateTime> availableDays({
    required Doctor doctor,
    required Iterable<TelemedicineCase> cases,
    required DateTime now,
  }) {
    final days = <DateTime>[];
    for (var i = 0; i < horizonDays; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      if (availableSlots(doctor: doctor, day: day, cases: cases, now: now).isNotEmpty) {
        days.add(day);
      }
    }
    return days;
  }
}
```

- [ ] **Step 4: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/domain/schedule_service_test.dart
```

Expected: `All tests passed!` (5 pruebas).

---

### Task 6: Estadísticas para las gráficas y avisos al paciente

**Files:**
- Create: `saludconecta/lib/domain/services/stats_calculator.dart`, `saludconecta/lib/domain/services/notification_builder.dart`
- Test: `saludconecta/test/domain/stats_calculator_test.dart`, `saludconecta/test/domain/notification_builder_test.dart`

**Interfaces:**
- Consumes: modelos, `CaseWorkflow` y los fixtures.
- Produces (en la etapa 9 alimentan las gráficas, y en la 5 la campana del paciente):
  - **Tipos de resultado:**
    - `MonthlyActivity{month, requests, consultations}`;
    - `MonthlyBilling{month, insurerAmount, copay}`;
    - `MonthlyRating{month, average?}`;
    - `OperationKpis{requestsThisMonth, casesInProcess, averageDaysToConsultation, rejectionRate}`;
    - `ResultsSummary{prescriptions, labOrders, imagingOrders, referrals}`;
    - `CoverageSplit{covered, paid}`.
  - **Funciones estáticas de `StatsCalculator`:**

    | Grupo | Funciones |
    |---|---|
    | Ventana de tiempo | `monthsUpTo(now)`, `monthOf(date)`, `inWindow(cases, now)` |
    | Operación | `operationKpis(cases, now)`, `requestsByChannel(cases)`, `monthlyActivity(cases, now)`, `funnel(cases)`, `averageHoursPerStage(cases)` |
    | Clínico | `consultationsBySpecialty(cases, servicesById)`, `platformUsage(cases)`, `resultsIssued(cases)` |
    | Financiero | `monthlyBilling(cases, now)`, `claimsByStatus(cases)`, `billingByInsurer(cases, patientsById)` |
    | Satisfacción | `surveysOf(cases)`, `averageRating(cases)`, `nps(cases)`, `ratingDistribution(cases)`, `monthlyRating(cases, now)` |
    | Perfil del paciente | `coverageSplit(patientCases)` |

  - **Avisos:**
    - `PatientNotification{caseId, at, title, body}`;
    - `NotificationBuilder({required String Function(DateTime) formatDateTime, required String Function(String doctorId) doctorName})`, con `.forPatient(cases, {limit = 20}) → List<PatientNotification>`, del aviso más reciente al más antiguo.

- [ ] **Step 1: Escribir la prueba de las estadísticas**

Create `saludconecta/test/domain/stats_calculator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/stats_calculator.dart';

import '../support/fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 20, 12);
  // Conjunto pequeño y fijo. Todos los casos son de María y se crearon el 9 de noviembre de 2026:
  // A, D y E completados; B pendiente de recepción; C cancelado por el paciente.
  final a = caseAt(null, id: 'TM-2026-0001', rating: 5, nps: 10);
  final b = newCase(id: 'TM-2026-0002', channel: RequestChannel.email);
  final c = CaseWorkflow.cancel(newCase(id: 'TM-2026-0003'), role: UserRole.patient, actorName: maria.fullName, at: start);
  final d = caseAt(null, id: 'TM-2026-0004', channel: RequestChannel.webPortal, rating: 4, nps: 9);
  final e = caseAt(null, id: 'TM-2026-0005', channel: RequestChannel.phone, rating: 2, nps: 3);
  final cases = [a, b, c, d, e];

  test('solicitudes por canal', () {
    final byChannel = StatsCalculator.requestsByChannel(cases);
    expect(byChannel[RequestChannel.whatsapp], 2);
    expect(byChannel[RequestChannel.email], 1);
    expect(byChannel[RequestChannel.webPortal], 1);
    expect(byChannel[RequestChannel.phone], 1);
    expect(byChannel[RequestChannel.mobile], 0);
  });

  test('embudo: cuántos casos completaron cada paso', () {
    final funnel = StatsCalculator.funnel(cases);
    expect(funnel[ProcessStep.requestAppointment], 5);
    expect(funnel[ProcessStep.reception], 3);
    expect(funnel[ProcessStep.followUp], 3);
  });

  test('tiempo promedio por etapa', () {
    final hours = StatsCalculator.averageHoursPerStage(cases);
    expect(hours[ProcessStep.reception], 1.0);
    // Consentimiento en h5, fin de la consulta en h7.
    expect(hours[ProcessStep.consultation], 2.0);
    expect(hours.containsKey(ProcessStep.requestAppointment), isFalse);
  });

  test('NPS = % de promotores − % de detractores', () {
    // 10 y 9 son promotores, 3 es detractor: (2 − 1) / 3 = 33%.
    expect(StatsCalculator.nps(cases), 33);
    expect(StatsCalculator.averageRating(cases), closeTo(3.67, 0.01));
    expect(StatsCalculator.ratingDistribution(cases), {1: 0, 2: 1, 3: 0, 4: 1, 5: 1});
  });

  test('facturación mensual: monto del seguro y copago', () {
    final months = StatsCalculator.monthlyBilling(cases, now);
    expect(months, hasLength(12));
    expect(months.last.month, DateTime(2026, 11));
    expect(months.last.insurerAmount, 3600, reason: '3 casos × RD\$1,200');
    expect(months.last.copay, 900, reason: '3 casos × RD\$300');
    expect(months.first.insurerAmount, 0);
  });

  test('indicadores de operación', () {
    final kpis = StatsCalculator.operationKpis(cases, now);
    expect(kpis.requestsThisMonth, 5);
    expect(kpis.casesInProcess, 1);
    expect(kpis.rejectionRate, 0);
    expect(kpis.averageDaysToConsultation, closeTo(7 / 24, 0.001));
  });

  test('consultas por especialidad, plataformas y resultados emitidos', () {
    final servicesById = {for (final s in catalog.services) s.id: s};
    expect(StatsCalculator.consultationsBySpecialty(cases, servicesById)[Specialty.generalMedicine], 3);
    expect(StatsCalculator.platformUsage(cases)[VideoPlatform.teams], 3);
    final results = StatsCalculator.resultsIssued(cases);
    expect(results.prescriptions, 3);
    expect(results.labOrders, 0);
  });

  test('reclamaciones por estado y facturación por aseguradora', () {
    expect(
      StatsCalculator.claimsByStatus(cases),
      {ClaimStatus.approved: 3, ClaimStatus.pending: 0, ClaimStatus.objected: 0},
    );
    final patientsById = {for (final p in catalog.patients) p.id: p};
    expect(StatsCalculator.billingByInsurer(cases, patientsById), {'salud-plena': 3600});
  });

  test('lo que cubrió el seguro y lo que pagó la paciente', () {
    final split = StatsCalculator.coverageSplit(cases);
    expect(split.covered, 3600);
    expect(split.paid, 900);
  });

  test('ventana de 12 meses, actividad y satisfacción por mes', () {
    final months = StatsCalculator.monthsUpTo(now);
    expect(months.first, DateTime(2025, 12));
    expect(months.last, DateTime(2026, 11));
    final activity = StatsCalculator.monthlyActivity(cases, now);
    expect(activity.last.requests, 5);
    expect(activity.last.consultations, 3);
    final ratings = StatsCalculator.monthlyRating(cases, now);
    expect(ratings.last.average, closeTo(3.67, 0.01));
    expect(ratings.first.average, isNull);
  });
}
```

- [ ] **Step 2: Escribir la prueba de los avisos**

Create `saludconecta/test/domain/notification_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/notification_builder.dart';

import '../support/fixtures.dart';

void main() {
  final builder = NotificationBuilder(
    formatDateTime: (d) => '${d.day}/${d.month} ${d.hour}:${d.minute}',
    doctorName: (id) => catalog.doctorById(id).displayName,
  );

  test('convierte los eventos del personal en avisos, del más reciente al más antiguo', () {
    final notifications = builder.forPatient([caseAt(ProcessStep.consentAdmission)]);
    expect(notifications.map((n) => n.title), [
      'Te enviamos el enlace por WhatsApp',
      'Cita agendada',
      'Tu seguro aprobó 80% de cobertura',
      'Recibimos tu solicitud',
    ]);
    expect(notifications[1].body, '12/11 10:30 con Dr. Carlos Méndez por MS Teams.');
    expect(notifications.first.caseId, 'TM-2026-0100');
  });

  test('las acciones de la propia paciente no generan avisos', () {
    expect(builder.forPatient([newCase()]), isEmpty);
  });
}
```

- [ ] **Step 3: Ejecutar las pruebas y verificar que fallan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/domain/stats_calculator_test.dart test/domain/notification_builder_test.dart
```

Expected: FAIL. No compila porque `stats_calculator.dart` y `notification_builder.dart` no existen.

- [ ] **Step 4: Crear la calculadora de estadísticas**

Create `saludconecta/lib/domain/services/stats_calculator.dart`:

```dart
import '../models/case_records.dart';
import '../models/catalog.dart';
import '../models/enums.dart';
import '../models/people.dart';
import '../models/telemedicine_case.dart';
import '../process/process_step.dart';

/// Solicitudes y consultas de un mes (gráfica de líneas de Operación).
class MonthlyActivity {
  const MonthlyActivity({required this.month, required this.requests, required this.consultations});

  final DateTime month;
  final int requests;
  final int consultations;
}

/// Lo facturado en un mes: parte del seguro y copago.
class MonthlyBilling {
  const MonthlyBilling({required this.month, required this.insurerAmount, required this.copay});

  final DateTime month;
  final int insurerAmount;
  final int copay;
}

/// Calificación promedio de un mes; `null` si no hubo encuestas.
class MonthlyRating {
  const MonthlyRating({required this.month, this.average});

  final DateTime month;
  final double? average;
}

/// Indicadores clave de la pestaña Operación.
class OperationKpis {
  const OperationKpis({
    required this.requestsThisMonth,
    required this.casesInProcess,
    required this.averageDaysToConsultation,
    required this.rejectionRate,
  });

  final int requestsThisMonth;
  final int casesInProcess;
  final double averageDaysToConsultation;

  /// % de las validaciones que el seguro rechazó.
  final double rejectionRate;
}

/// Cuántos casos tienen cada tipo de resultado.
class ResultsSummary {
  const ResultsSummary({
    required this.prescriptions,
    required this.labOrders,
    required this.imagingOrders,
    required this.referrals,
  });

  final int prescriptions;
  final int labOrders;
  final int imagingOrders;
  final int referrals;
}

/// Lo que cubrió el seguro y lo que pagó el paciente.
class CoverageSplit {
  const CoverageSplit({required this.covered, required this.paid});

  final int covered;
  final int paid;
}

/// Funciones puras que alimentan las gráficas (§7 del spec).
class StatsCalculator {
  const StatsCalculator._();

  static const windowMonths = 12;

  /// Primer día de cada mes de la ventana, del más antiguo al actual.
  static List<DateTime> monthsUpTo(DateTime now) => [
        for (var i = windowMonths - 1; i >= 0; i--) DateTime(now.year, now.month - i),
      ];

  static DateTime monthOf(DateTime date) => DateTime(date.year, date.month);

  /// Casos creados dentro de la ventana de 12 meses.
  static List<TelemedicineCase> inWindow(Iterable<TelemedicineCase> cases, DateTime now) {
    final start = monthsUpTo(now).first;
    return [
      for (final c in cases)
        if (!c.createdAt.isBefore(start)) c,
    ];
  }

  // ----- Operación -----

  static OperationKpis operationKpis(Iterable<TelemedicineCase> cases, DateTime now) {
    final thisMonth = monthOf(now);
    var requestsThisMonth = 0;
    var inProcess = 0;
    var validated = 0;
    var rejected = 0;
    final daysToConsultation = <double>[];
    for (final c in cases) {
      if (monthOf(c.createdAt) == thisMonth) requestsThisMonth++;
      if (c.status.isOpen) inProcess++;
      final insurance = c.insurance;
      if (insurance != null) {
        validated++;
        if (!insurance.approved) rejected++;
      }
      final consulted = c.completedAt(ProcessStep.consultation);
      if (consulted != null) daysToConsultation.add(_hours(c.createdAt, consulted) / 24);
    }
    return OperationKpis(
      requestsThisMonth: requestsThisMonth,
      casesInProcess: inProcess,
      averageDaysToConsultation: _average(daysToConsultation),
      rejectionRate: validated == 0 ? 0 : rejected * 100 / validated,
    );
  }

  static Map<RequestChannel, int> requestsByChannel(Iterable<TelemedicineCase> cases) {
    final counts = {for (final channel in RequestChannel.values) channel: 0};
    for (final c in cases) {
      counts[c.channel] = counts[c.channel]! + 1;
    }
    return counts;
  }

  /// Solicitudes (por mes de creación) y consultas realizadas (por mes de la consulta).
  static List<MonthlyActivity> monthlyActivity(Iterable<TelemedicineCase> cases, DateTime now) {
    final months = monthsUpTo(now);
    final requests = {for (final m in months) m: 0};
    final consultations = {for (final m in months) m: 0};
    for (final c in cases) {
      final created = monthOf(c.createdAt);
      if (requests.containsKey(created)) requests[created] = requests[created]! + 1;
      final consulted = c.completedAt(ProcessStep.consultation);
      if (consulted == null) continue;
      final month = monthOf(consulted);
      if (consultations.containsKey(month)) consultations[month] = consultations[month]! + 1;
    }
    return [
      for (final m in months) MonthlyActivity(month: m, requests: requests[m]!, consultations: consultations[m]!),
    ];
  }

  /// Embudo: cuántos casos completaron cada paso.
  static Map<ProcessStep, int> funnel(Iterable<TelemedicineCase> cases) {
    final counts = {for (final step in ProcessStep.values) step: 0};
    for (final c in cases) {
      for (final step in c.completedSteps) {
        counts[step] = counts[step]! + 1;
      }
    }
    return counts;
  }

  /// Horas promedio entre la finalización del paso anterior y la del paso (pasos 2–10).
  static Map<ProcessStep, double> averageHoursPerStage(Iterable<TelemedicineCase> cases) {
    final result = <ProcessStep, double>{};
    for (final step in ProcessStep.values.skip(1)) {
      final hours = <double>[];
      for (final c in cases) {
        final start = c.completedAt(step.previous!);
        final end = c.completedAt(step);
        if (start != null && end != null) hours.add(_hours(start, end));
      }
      result[step] = _average(hours);
    }
    return result;
  }

  // ----- Clínico -----

  static Map<Specialty, int> consultationsBySpecialty(
    Iterable<TelemedicineCase> cases,
    Map<String, MedicalService> servicesById,
  ) {
    final counts = {for (final s in Specialty.values) s: 0};
    for (final c in cases) {
      final specialty = servicesById[c.serviceId]?.specialty;
      if (specialty != null && c.isStepCompleted(ProcessStep.consultation)) {
        counts[specialty] = counts[specialty]! + 1;
      }
    }
    return counts;
  }

  static Map<VideoPlatform, int> platformUsage(Iterable<TelemedicineCase> cases) {
    final counts = {for (final p in VideoPlatform.values) p: 0};
    for (final c in cases) {
      final appointment = c.appointment;
      if (appointment != null && c.isStepCompleted(ProcessStep.consultation)) {
        counts[appointment.platform] = counts[appointment.platform]! + 1;
      }
    }
    return counts;
  }

  static ResultsSummary resultsIssued(Iterable<TelemedicineCase> cases) {
    var prescriptions = 0;
    var lab = 0;
    var imaging = 0;
    var referrals = 0;
    for (final c in cases) {
      final r = c.results;
      if (r == null) continue;
      if (r.prescription != null) prescriptions++;
      if (r.ordersOf(OrderType.lab).isNotEmpty) lab++;
      if (r.ordersOf(OrderType.imaging).isNotEmpty) imaging++;
      if (r.referral != null) referrals++;
    }
    return ResultsSummary(prescriptions: prescriptions, labOrders: lab, imagingOrders: imaging, referrals: referrals);
  }

  // ----- Financiero -----

  /// Facturación por mes de cierre: monto a cargo del seguro y copago.
  static List<MonthlyBilling> monthlyBilling(Iterable<TelemedicineCase> cases, DateTime now) {
    final months = monthsUpTo(now);
    final insurer = {for (final m in months) m: 0};
    final copay = {for (final m in months) m: 0};
    for (final c in cases) {
      final billing = c.billing;
      final closedAt = billing?.closedAt;
      if (billing == null || closedAt == null) continue;
      final month = monthOf(closedAt);
      if (!insurer.containsKey(month)) continue;
      insurer[month] = insurer[month]! + billing.invoice.insurerAmount;
      copay[month] = copay[month]! + billing.invoice.copay;
    }
    return [
      for (final m in months) MonthlyBilling(month: m, insurerAmount: insurer[m]!, copay: copay[m]!),
    ];
  }

  /// Reclamaciones por estado (sin las que no aplican).
  static Map<ClaimStatus, int> claimsByStatus(Iterable<TelemedicineCase> cases) {
    final counts = {ClaimStatus.approved: 0, ClaimStatus.pending: 0, ClaimStatus.objected: 0};
    for (final c in cases) {
      final status = c.billing?.claimStatus;
      if (status != null && counts.containsKey(status)) counts[status] = counts[status]! + 1;
    }
    return counts;
  }

  /// Monto a cargo de cada aseguradora en los casos cerrados (clave: id de la aseguradora).
  static Map<String, int> billingByInsurer(Iterable<TelemedicineCase> cases, Map<String, Patient> patientsById) {
    final totals = <String, int>{};
    for (final c in cases) {
      final billing = c.billing;
      final patient = patientsById[c.patientId];
      if (billing == null || billing.closedAt == null || patient == null) continue;
      if (billing.invoice.insurerAmount == 0) continue;
      final insurerId = patient.affiliation.insurerId;
      totals[insurerId] = (totals[insurerId] ?? 0) + billing.invoice.insurerAmount;
    }
    return totals;
  }

  // ----- Satisfacción -----

  static List<Survey> surveysOf(Iterable<TelemedicineCase> cases) => [
        for (final c in cases)
          if (c.followUp?.survey != null) c.followUp!.survey!,
      ];

  static double averageRating(Iterable<TelemedicineCase> cases) =>
      _average([for (final s in surveysOf(cases)) s.rating.toDouble()]);

  /// NPS = % de promotores (9–10) − % de detractores (0–6), redondeado.
  static int nps(Iterable<TelemedicineCase> cases) {
    final surveys = surveysOf(cases);
    if (surveys.isEmpty) return 0;
    final promoters = surveys.where((s) => s.nps >= 9).length;
    final detractors = surveys.where((s) => s.nps <= 6).length;
    return ((promoters - detractors) * 100 / surveys.length).round();
  }

  static Map<int, int> ratingDistribution(Iterable<TelemedicineCase> cases) {
    final counts = {for (var stars = 1; stars <= 5; stars++) stars: 0};
    for (final s in surveysOf(cases)) {
      counts[s.rating] = counts[s.rating]! + 1;
    }
    return counts;
  }

  static List<MonthlyRating> monthlyRating(Iterable<TelemedicineCase> cases, DateTime now) {
    final months = monthsUpTo(now);
    final ratings = {for (final m in months) m: <double>[]};
    for (final s in surveysOf(cases)) {
      ratings[monthOf(s.at)]?.add(s.rating.toDouble());
    }
    return [
      for (final m in months) MonthlyRating(month: m, average: ratings[m]!.isEmpty ? null : _average(ratings[m]!)),
    ];
  }

  // ----- Perfil del paciente -----

  /// Suma, en los casos cerrados, lo cubierto por el seguro y lo pagado por el paciente.
  static CoverageSplit coverageSplit(Iterable<TelemedicineCase> patientCases) {
    var covered = 0;
    var paid = 0;
    for (final c in patientCases) {
      final billing = c.billing;
      if (billing == null || billing.closedAt == null) continue;
      covered += billing.invoice.insurerAmount;
      paid += billing.invoice.copay;
    }
    return CoverageSplit(covered: covered, paid: paid);
  }

  static double _hours(DateTime from, DateTime to) => to.difference(from).inMinutes / 60;

  static double _average(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
}
```

- [ ] **Step 5: Crear el constructor de avisos**

Create `saludconecta/lib/domain/services/notification_builder.dart`:

```dart
import '../models/enums.dart';
import '../models/process_event.dart';
import '../models/telemedicine_case.dart';
import '../process/process_step.dart';

/// Un aviso para el paciente (campana del Inicio).
class PatientNotification {
  const PatientNotification({required this.caseId, required this.at, required this.title, required this.body});

  final String caseId;
  final DateTime at;
  final String title;
  final String body;
}

/// Convierte los eventos de los casos del paciente en avisos legibles.
class NotificationBuilder {
  const NotificationBuilder({required this.formatDateTime, required this.doctorName});

  /// Formatea fecha y hora (en la app: `Formatters.dateTime`).
  final String Function(DateTime) formatDateTime;

  /// Nombre del médico por su id.
  final String Function(String doctorId) doctorName;

  /// Avisos de los casos del paciente, del más reciente al más antiguo.
  List<PatientNotification> forPatient(Iterable<TelemedicineCase> cases, {int limit = 20}) {
    final items = <PatientNotification>[];
    for (final c in cases) {
      for (final e in c.events) {
        final notification = _describe(c, e);
        if (notification != null) items.add(notification);
      }
    }
    items.sort((a, b) => b.at.compareTo(a.at));
    return items.take(limit).toList();
  }

  PatientNotification? _describe(TelemedicineCase c, ProcessEvent e) {
    // Las acciones del propio paciente no generan aviso.
    if (e.actor == Actor.patient) return null;
    PatientNotification make(String title, String body) =>
        PatientNotification(caseId: c.id, at: e.at, title: title, body: body);

    switch (e.kind) {
      case EventKind.rejected:
        return make('Tu seguro no aprobó la cobertura', '${e.detail}. Admisión te contactará para continuar.');
      case EventKind.cancelled:
        return make('Tu solicitud fue cancelada', 'Caso ${c.id}.');
      case EventKind.call:
        return make('Te llamamos para dar seguimiento', e.detail);
      case EventKind.started || EventKind.claim || EventKind.payment:
        return null;
      case EventKind.completed:
        break;
    }

    final insurance = c.insurance;
    final appointment = c.appointment;
    switch (e.step) {
      case ProcessStep.reception:
        return make('Recibimos tu solicitud', 'Admisión registró tu caso ${c.id}.');
      case ProcessStep.insuranceValidation:
        if (c.privatePay) {
          return make('Continuarás como paciente privado', 'Tu atención no tendrá cobertura del seguro.');
        }
        return make(
          'Tu seguro aprobó ${insurance?.coveragePercent ?? 0}% de cobertura',
          'Autorización ${insurance?.authorizationNumber ?? '-'}.',
        );
      case ProcessStep.scheduling:
        if (appointment == null) return null;
        return make(
          'Cita agendada',
          '${formatDateTime(appointment.dateTime)} con ${doctorName(appointment.doctorId)} '
              'por ${appointment.platform.label}.',
        );
      case ProcessStep.patientConfirmation:
        return make(
          'Te enviamos el enlace por ${c.confirmation?.sentVia.label ?? 'WhatsApp'}',
          'Firma tu consentimiento en la app.',
        );
      case ProcessStep.consultationResult:
        return make('Tus resultados están listos', 'Revisa tu receta, tus órdenes y tus indicaciones.');
      case ProcessStep.administrativeClosure:
        return make('Tu atención fue cerrada', 'Cuéntanos cómo te fue en la encuesta de satisfacción.');
      case ProcessStep.requestAppointment ||
            ProcessStep.consentAdmission ||
            ProcessStep.consultation ||
            ProcessStep.followUp:
        return null;
    }
  }
}
```

- [ ] **Step 6: Ejecutar las pruebas y verificar que pasan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/domain/stats_calculator_test.dart test/domain/notification_builder_test.dart
```

Expected: `All tests passed!` (12 pruebas: 10 de estadísticas y 2 de avisos).

---

### Task 7: Repositorio de casos, semilla de casos y commit de la etapa

**Files:**
- Create: `saludconecta/lib/data/repositories/case_repository.dart`, `saludconecta/lib/data/seed/seed_cases.dart`
- Test: `saludconecta/test/data/case_repository_test.dart`, `saludconecta/test/data/seed_cases_test.dart`
- Modify: `docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md` (estado de la etapa 2)

**Interfaces:**
- Consumes: todo lo anterior. `SeedCases` usa `CaseWorkflow`, `CaseCodes`, `BillingCalculator`, `ScheduleService` y `StatsCalculator.monthsUpTo`.
- Produces (en la etapa 4, el `CaseProvider` arma su repositorio con `InMemoryCaseRepository(SeedCases.generate(now: DateTime.now(), catalog: catalog))`):
  - **`abstract class CaseRepository`:** `getAll()`, `getById(id)`, `save(case)` y `nextId(DateTime at)`.
  - **`InMemoryCaseRepository([Iterable<TelemedicineCase> initial])`.**
  - **`SeedCases.generate({required DateTime now, required CatalogRepository catalog}) → List<TelemedicineCase>`.**

- [ ] **Step 1: Escribir las pruebas del repositorio y de la semilla**

Create `saludconecta/test/data/case_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/repositories/case_repository.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../support/fixtures.dart';

void main() {
  test('el siguiente ID continúa la secuencia', () {
    final repo = InMemoryCaseRepository();
    expect(repo.nextId(DateTime(2026, 11, 9)), 'TM-2026-0001');
    repo.save(newCase(id: 'TM-2026-0007'));
    expect(repo.nextId(DateTime(2026, 11, 9)), 'TM-2026-0008');
  });

  test('guardar reemplaza el caso con el mismo ID', () {
    final c = newCase(id: 'TM-2026-0007');
    final repo = InMemoryCaseRepository([c]);
    expect(repo.getById('TM-2026-0007'), same(c));
    repo.save(CaseWorkflow.registerReception(c, staffName: ana, at: start));
    expect(repo.getAll(), hasLength(1));
    expect(repo.getById('TM-2026-0007')!.currentStep, ProcessStep.insuranceValidation);
    expect(repo.getById('TM-2026-9999'), isNull);
  });
}
```

Create `saludconecta/test/data/seed_cases_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/seed/seed_cases.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/models/telemedicine_case.dart';
import 'package:saludconecta/domain/process/process_step.dart';

void main() {
  final catalog = SeedCatalog.repository();
  final now = DateTime(2026, 11, 9, 10);
  final cases = SeedCases.generate(now: now, catalog: catalog);

  String fingerprint(List<TelemedicineCase> list) => [
        for (final c in list)
          '${c.id}|${c.patientId}|${c.status.name}|${c.currentStep.name}|${c.events.length}|${c.updatedAt}',
      ].join('\n');

  test('es determinista: el mismo now produce los mismos casos', () {
    expect(fingerprint(SeedCases.generate(now: now, catalog: catalog)), fingerprint(cases));
  });

  test('genera unos 200 casos históricos, todos terminados y variados', () {
    final closed = cases.where((c) => !c.isOpen).toList();
    expect(closed.length, inInclusiveRange(150, 230));
    final completed = closed.where((c) => c.status == CaseStatus.completed).length;
    expect(completed / closed.length, greaterThan(0.8));
    expect(cases.any((c) => c.privatePay), isTrue, reason: 'hay rechazos que siguieron como privado');
    expect(cases.any((c) => c.billing?.claimStatus == ClaimStatus.objected), isTrue, reason: 'hay glosas');
  });

  test('hay 10 casos en vivo, uno por cada paso pendiente del 2 al 10', () {
    final open = cases.where((c) => c.isOpen).toList();
    expect(open, hasLength(10));
    expect(open.map((c) => c.currentStep.number).toList()..sort(), [2, 3, 3, 4, 5, 6, 7, 8, 9, 10]);
  });

  test('uno de los casos en vivo es del paciente con afiliación inactiva', () {
    final inactive = cases.where((c) => c.isOpen && !catalog.patientById(c.patientId).affiliation.active).toList();
    expect(inactive, hasLength(1));
    expect(inactive.single.patientId, SeedIds.pedro);
    expect(inactive.single.currentStep, ProcessStep.insuranceValidation);
  });

  test('María tiene 4 consultas completadas y ningún caso abierto', () {
    final maria = cases.where((c) => c.patientId == SeedIds.maria).toList();
    expect(maria.where((c) => c.status == CaseStatus.completed), hasLength(4));
    expect(maria.where((c) => c.isOpen), isEmpty);
  });

  test('los eventos están en orden y ninguno ocurre después de now', () {
    for (final c in cases) {
      for (var i = 1; i < c.events.length; i++) {
        expect(c.events[i].at.isBefore(c.events[i - 1].at), isFalse, reason: '${c.id}: evento $i fuera de orden');
      }
      expect(c.updatedAt.isAfter(now), isFalse, reason: c.id);
    }
  });

  test('funciona con fechas límite (inicio de año, fin de mes, año bisiesto)', () {
    for (final date in [DateTime(2026, 1, 1, 0, 5), DateTime(2026, 3, 31, 23, 59), DateTime(2028, 2, 29, 12)]) {
      final generated = SeedCases.generate(now: date, catalog: catalog);
      expect(generated.where((c) => c.isOpen), hasLength(10), reason: '$date');
    }
  });
}
```

- [ ] **Step 2: Ejecutar las pruebas y verificar que fallan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/data/case_repository_test.dart test/data/seed_cases_test.dart
```

Expected: FAIL. No compila porque `case_repository.dart` y `seed_cases.dart` no existen.

- [ ] **Step 3: Crear el repositorio de casos**

Create `saludconecta/lib/data/repositories/case_repository.dart`:

```dart
import '../../domain/models/telemedicine_case.dart';

/// Almacén de casos de telemedicina.
abstract class CaseRepository {
  /// Todos los casos, en orden de inserción.
  List<TelemedicineCase> getAll();

  TelemedicineCase? getById(String id);

  /// Inserta un caso o reemplaza el que tenga el mismo `id`.
  void save(TelemedicineCase telemedicineCase);

  /// Siguiente ID libre: "TM-<año>-<secuencia de 4 dígitos>".
  String nextId(DateTime at);
}

/// Implementación en memoria: al reiniciar la app se vuelve a los datos semilla.
class InMemoryCaseRepository implements CaseRepository {
  InMemoryCaseRepository([Iterable<TelemedicineCase> initial = const []]) {
    for (final c in initial) {
      _cases[c.id] = c;
    }
  }

  // El mapa conserva el orden de inserción.
  final _cases = <String, TelemedicineCase>{};

  @override
  List<TelemedicineCase> getAll() => List.unmodifiable(_cases.values);

  @override
  TelemedicineCase? getById(String id) => _cases[id];

  @override
  void save(TelemedicineCase telemedicineCase) {
    _cases[telemedicineCase.id] = telemedicineCase;
  }

  @override
  String nextId(DateTime at) {
    var lastSequence = 0;
    for (final id in _cases.keys) {
      final sequence = int.tryParse(id.split('-').last) ?? 0;
      if (sequence > lastSequence) lastSequence = sequence;
    }
    return 'TM-${at.year}-${(lastSequence + 1).toString().padLeft(4, '0')}';
  }
}
```

- [ ] **Step 4: Crear el generador de casos semilla**

Create `saludconecta/lib/data/seed/seed_cases.dart`:

```dart
import 'dart:math';

import '../../domain/models/case_records.dart';
import '../../domain/models/catalog.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/people.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/case_workflow.dart';
import '../../domain/process/process_step.dart';
import '../../domain/services/billing_calculator.dart';
import '../../domain/services/case_codes.dart';
import '../../domain/services/schedule_service.dart';
import '../../domain/services/stats_calculator.dart';
import '../repositories/catalog_repository.dart';
import 'seed_catalog.dart';

/// Genera los casos de demostración:
/// - unos 200 casos históricos repartidos en los últimos 12 meses, todos terminados;
/// - 10 casos "en vivo", detenidos uno en cada paso pendiente del 2 al 10.
///
/// Es determinista: con el mismo [now] produce exactamente los mismos casos.
class SeedCases {
  const SeedCases._();

  static List<TelemedicineCase> generate({required DateTime now, required CatalogRepository catalog}) {
    final random = Random(2026);
    final stories = [
      ..._mariaHistory(now, catalog, random),
      ..._history(now, catalog, random),
      ..._live(now, catalog),
    ];
    // Los IDs siguen el orden de creación: TM-<año>-0001, TM-<año>-0002…
    stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [
      for (var i = 0; i < stories.length; i++)
        stories[i].build('TM-${stories[i].createdAt.year}-${(i + 1).toString().padLeft(4, '0')}', catalog),
    ];
  }

  // ----- Históricos -----

  /// María tiene 4 consultas completadas (para las gráficas de su perfil).
  static List<_Story> _mariaHistory(DateTime now, CatalogRepository catalog, Random random) {
    final maria = catalog.patientById(SeedIds.maria);
    const visits = [
      (10, SeedIds.generalConsult, 5),
      (7, SeedIds.nutrition, 4),
      (4, SeedIds.internalMedicine, 5),
      (1, SeedIds.generalConsult, 5),
    ];
    return [
      for (final (monthsAgo, serviceId, stars) in visits)
        _sample(
          random,
          catalog,
          createdAt: DateTime(now.year, now.month - monthsAgo, 10, 9, 30),
          patient: maria,
          service: catalog.serviceById(serviceId),
          forceCompleted: true,
          stars: stars,
        ),
    ];
  }

  /// Casos de los últimos 12 meses: el volumen sube de ~10 a ~24 casos por mes.
  static List<_Story> _history(DateTime now, CatalogRepository catalog, Random random) {
    final stories = <_Story>[];
    final months = StatsCalculator.monthsUpTo(now);
    final latestEnd = now.subtract(const Duration(hours: 1));
    // María tiene su historia fija y Pedro (afiliación inactiva) solo aparece en vivo.
    final patients = [
      for (final p in catalog.patients)
        if (p.id != SeedIds.maria && p.id != SeedIds.pedro) p,
    ];
    for (var m = 0; m < months.length; m++) {
      final monthStart = months[m];
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1);
      final isCurrent = m == months.length - 1;
      var count = (10 + 14 * m / (months.length - 1)).round();
      if (isCurrent) {
        // Del mes actual solo se genera la parte que ya transcurrió.
        final elapsed = now.difference(monthStart).inMinutes / nextMonth.difference(monthStart).inMinutes;
        count = (count * elapsed).round();
      }
      for (var i = 0; i < count; i++) {
        final story = _sample(
          random,
          catalog,
          createdAt: _randomMoment(random, monthStart, isCurrent ? now : nextMonth),
          patient: patients[random.nextInt(patients.length)],
          service: catalog.serviceById(_weighted(random, _serviceWeights)),
        );
        // Si no alcanzaría a terminar antes de "ahora", no se genera: así los únicos
        // casos abiertos son los 10 en vivo.
        if (story.endsAt.isAfter(latestEnd)) continue;
        stories.add(story);
      }
    }
    return stories;
  }

  /// Arma la historia de un caso con las distribuciones y duraciones del §13 del spec.
  static _Story _sample(
    Random random,
    CatalogRepository catalog, {
    required DateTime createdAt,
    required Patient patient,
    required MedicalService service,
    bool forceCompleted = false,
    int? stars,
  }) {
    final specialty = service.specialty!;
    final doctor = catalog.doctorsFor(specialty).first;
    final template = _templates[specialty]![random.nextInt(2)];

    // Desenlace: 6% rechazo del seguro (la mitad sigue como privado), 5% cancela el paciente.
    final roll = random.nextDouble();
    final rejected = !forceCompleted && roll < 0.06;
    final patientCancels = !forceCompleted && !rejected && roll < 0.11;
    final continuesPrivate = random.nextBool();
    final cancelAt = ProcessStep.fromNumber(2 + random.nextInt(5));

    // Detalles de la atención. Psicología y Nutrición (licenciadas) no recetan medicamentos.
    final channel = _weighted(random, _channelWeights);
    final platform = _weighted(random, _platformWeights);
    final confirmVia = random.nextDouble() < 0.7 ? RequestChannel.whatsapp : RequestChannel.email;
    final wantsPrescription = random.nextDouble() < 0.85;
    final medications = wantsPrescription ? template.medications : const <PrescriptionItem>[];
    final labs = random.nextDouble() < 0.40 ? _pickSome(random, _labTests, 1 + random.nextInt(2)) : const <String>[];
    final imaging =
        random.nextDouble() < 0.20 ? [_imagingTests[random.nextInt(_imagingTests.length)]] : const <String>[];
    final referral = random.nextDouble() < 0.12
        ? Referral(specialty: _otherSpecialty(random, specialty), reason: 'Evaluación presencial por especialista')
        : null;
    final followUpInDays = random.nextDouble() < 0.30 ? const [7, 15, 30][random.nextInt(3)] : null;
    // `<int>` explícito: sin él, el `??` haría que Dart infiera `int?`.
    final rating = stars ?? _weighted<int>(random, _ratingWeights);
    final comments = _comments[rating]!;

    // Tiempos de cada momento del caso.
    final times = <_At, DateTime>{};
    var t = createdAt;
    DateTime advance(double minHours, double maxHours) => t = t.add(_hours(random, minHours, maxHours));
    times[_At.reception] = advance(0.5, 4);
    times[_At.validation] = advance(0.2, 2);
    if (rejected) times[_At.resolution] = advance(0.2, 3);
    times[_At.scheduling] = advance(1, 24);
    times[_At.confirmation] = advance(0.1, 2);
    final appointment = _appointmentSlot(
      random,
      doctor,
      day: DateTime(createdAt.year, createdAt.month, createdAt.day + 1 + random.nextInt(5)),
      notBefore: t.add(const Duration(hours: 1)),
    );
    times[_At.consent] = t.add(appointment.difference(t) * (0.2 + random.nextDouble() * 0.7));
    t = appointment;
    times[_At.start] = advance(0, 10 / 60);
    times[_At.end] = advance(15 / 60, 40 / 60);
    final results = advance(0.2, 2);
    times[_At.results] = results;
    final closure = advance(1, 72);
    times[_At.claim] = results.add(closure.difference(results) * 0.4);
    times[_At.payment] = results.add(closure.difference(results) * 0.7);
    times[_At.closure] = closure;
    final survey = advance(24, 120);
    times[_At.call] = closure.add(survey.difference(closure) * 0.5);
    times[_At.survey] = survey;

    // Los casos que terminan antes (cancelados) pierden los momentos posteriores.
    if (rejected && !continuesPrivate) {
      final end = times[_At.resolution]!;
      times.removeWhere((_, time) => time.isAfter(end));
    }
    if (patientCancels) {
      final previous = switch (cancelAt) {
        ProcessStep.reception => createdAt,
        ProcessStep.insuranceValidation => times[_At.reception]!,
        ProcessStep.scheduling => times[_At.validation]!,
        ProcessStep.patientConfirmation => times[_At.scheduling]!,
        _ => times[_At.confirmation]!,
      };
      times.removeWhere((_, time) => time.isAfter(previous));
      times[_At.cancellation] = previous.add(_hours(random, 1, 24));
    }
    final callNote = random.nextDouble() < 0.25 ? _callNotes[random.nextInt(_callNotes.length)] : null;
    if (callNote == null) times.remove(_At.call);

    return _Story(
      createdAt: createdAt,
      patient: patient,
      service: service,
      doctor: doctor,
      channel: channel,
      reason: template.notes.chiefComplaint,
      times: times,
      cancelAt: patientCancels ? cancelAt : null,
      rejection: rejected ? _rejectionMessages[random.nextInt(_rejectionMessages.length)] : null,
      continuesPrivate: continuesPrivate,
      receptionNotes: _receptionNotes[random.nextInt(_receptionNotes.length)],
      appointment: appointment,
      platform: platform,
      confirmVia: confirmVia,
      notes: template.notes,
      medications: medications,
      orders: [
        for (final test in labs) MedicalOrder(type: OrderType.lab, description: test),
        for (final test in imaging) MedicalOrder(type: OrderType.imaging, description: test),
      ],
      referral: referral,
      instructions: _instructions[random.nextInt(_instructions.length)],
      followUpInDays: followUpInDays,
      paymentMethod: _weighted(random, _paymentWeights),
      claimAfterClosure: _weighted(random, _claimWeights),
      callNote: callNote,
      rating: rating,
      nps: _npsFor(random, rating),
      comment: comments[random.nextInt(comments.length)],
    );
  }

  // ----- En vivo -----

  /// Los 10 casos en vivo: uno detenido en cada paso pendiente, del 2 al 10 (tabla del §13 del spec).
  static List<_Story> _live(DateTime now, CatalogRepository catalog) {
    Patient patient(String id) => catalog.patientById(id);
    MedicalService service(String id) => catalog.serviceById(id);
    DateTime ago(int hours, [int minutes = 0]) => now.subtract(Duration(hours: hours, minutes: minutes));
    final mendez = catalog.doctorById(SeedIds.mendez);
    final jimenez = catalog.doctorById(SeedIds.jimenez);
    final soon = _ceilToHalfHour(now.add(const Duration(minutes: 10)));
    final earlierToday = _floorToHalfHour(ago(3));
    final yesterday = _floorToHalfHour(ago(27));
    final fourDaysAgo = _floorToHalfHour(ago(96));
    return [
      // L1 · José · pendiente el paso 2 (bandeja "Nuevas" de Admisión).
      _Story(
        createdAt: ago(2),
        patient: patient(SeedIds.jose),
        service: service(SeedIds.generalConsult),
        doctor: mendez,
        channel: RequestChannel.whatsapp,
        reason: 'Dolor de garganta y fiebre desde ayer',
        times: const {},
        stopAt: ProcessStep.reception,
      ),
      // L2 · Carmen · pendiente el paso 3 (el seguro aprobará).
      _Story(
        createdAt: ago(6),
        patient: patient(SeedIds.carmen),
        service: service(SeedIds.cardiology),
        doctor: catalog.doctorById(SeedIds.santana),
        channel: RequestChannel.webPortal,
        reason: 'Seguimiento de palpitaciones y presión arterial',
        times: {_At.reception: ago(5)},
        receptionNotes: 'Paciente con estudios previos.',
        stopAt: ProcessStep.insuranceValidation,
      ),
      // L3 · Pedro (afiliación inactiva) · pendiente el paso 3 (el seguro rechazará).
      _Story(
        createdAt: ago(24),
        patient: patient(SeedIds.pedro),
        service: service(SeedIds.internalMedicine),
        doctor: jimenez,
        channel: RequestChannel.phone,
        reason: 'Control de glicemia y cansancio frecuente',
        times: {_At.reception: ago(23)},
        stopAt: ProcessStep.insuranceValidation,
      ),
      // L4 · Luisa · pendiente el paso 4 (agendar).
      _Story(
        createdAt: ago(29),
        patient: patient(SeedIds.luisa),
        service: service(SeedIds.gynecology),
        doctor: catalog.doctorById(SeedIds.nunez),
        channel: RequestChannel.mobile,
        reason: 'Control ginecológico de seguimiento anual',
        times: {_At.reception: ago(28), _At.validation: ago(27)},
        stopAt: ProcessStep.scheduling,
      ),
      // L5 · Ramón · pendiente el paso 5 (enviar el enlace; Dra. Jiménez por Zoom).
      _Story(
        createdAt: ago(48),
        patient: patient(SeedIds.ramon),
        service: service(SeedIds.internalMedicine),
        doctor: jimenez,
        channel: RequestChannel.email,
        reason: 'Revisión del tratamiento para la presión arterial',
        times: {_At.reception: ago(47), _At.validation: ago(46, 30), _At.scheduling: ago(24)},
        appointment: _nextWorkingDayAt(jimenez, now, hour: 10),
        platform: VideoPlatform.zoom,
        stopAt: ProcessStep.patientConfirmation,
      ),
      // L6 · José · pendiente el paso 6 (firmar el consentimiento; Dr. Méndez por Teams).
      _Story(
        createdAt: ago(72),
        patient: patient(SeedIds.jose),
        service: service(SeedIds.postConsultFollowUp),
        doctor: mendez,
        channel: RequestChannel.whatsapp,
        reason: 'Seguimiento después de la consulta por faringitis',
        times: {_At.reception: ago(71), _At.validation: ago(70), _At.scheduling: ago(50), _At.confirmation: ago(49)},
        appointment: _nextWorkingDayAt(mendez, now, hour: 9),
        platform: VideoPlatform.teams,
        stopAt: ProcessStep.consentAdmission,
      ),
      // L7 · Carmen · pendiente el paso 7: "Paciente en sala de espera" (Dr. Méndez por Meet).
      _Story(
        createdAt: ago(75),
        patient: patient(SeedIds.carmen),
        service: service(SeedIds.generalConsult),
        doctor: mendez,
        channel: RequestChannel.whatsapp,
        reason: 'Dolor lumbar desde hace una semana',
        times: {
          _At.reception: ago(74),
          _At.validation: ago(73),
          _At.scheduling: ago(52),
          _At.confirmation: ago(51),
          _At.consent: ago(0, 30),
        },
        appointment: soon,
        platform: VideoPlatform.meet,
        stopAt: ProcessStep.consultation,
      ),
      // L8 · Luisa · pendiente el paso 8 (emitir resultados; Dr. Méndez).
      _Story(
        createdAt: ago(98),
        patient: patient(SeedIds.luisa),
        service: service(SeedIds.resultsReview),
        doctor: mendez,
        channel: RequestChannel.webPortal,
        reason: 'Revisión de resultados de laboratorio recientes',
        times: {
          _At.reception: ago(97),
          _At.validation: ago(96),
          _At.scheduling: ago(80),
          _At.confirmation: ago(79),
          _At.consent: ago(5),
          _At.start: earlierToday,
          _At.end: earlierToday.add(const Duration(minutes: 25)),
        },
        appointment: earlierToday,
        platform: VideoPlatform.teams,
        notes: const ClinicalNotes(
          chiefComplaint: 'Revisión de hemograma y perfil lipídico',
          assessment: 'Valores normales, salvo el colesterol LDL elevado.',
          diagnosis: 'Dislipidemia leve',
          plan: 'Dieta baja en grasas y control en 3 meses.',
        ),
        stopAt: ProcessStep.consultationResult,
      ),
      // L9 · Ramón · pendiente el paso 9 (cierre administrativo; Dra. Jiménez).
      _Story(
        createdAt: ago(150),
        patient: patient(SeedIds.ramon),
        service: service(SeedIds.chronicCare),
        doctor: jimenez,
        channel: RequestChannel.phone,
        reason: 'Control mensual de diabetes e hipertensión',
        times: {
          _At.reception: ago(149),
          _At.validation: ago(148),
          _At.scheduling: ago(130),
          _At.confirmation: ago(129),
          _At.consent: ago(30),
          _At.start: yesterday,
          _At.end: yesterday.add(const Duration(minutes: 30)),
          _At.results: yesterday.add(const Duration(hours: 1)),
        },
        appointment: yesterday,
        platform: VideoPlatform.zoom,
        notes: const ClinicalNotes(
          chiefComplaint: 'Control mensual de diabetes e hipertensión',
          assessment: 'Glicemias en ayunas entre 130 y 150 mg/dl.',
          diagnosis: 'Diabetes mellitus tipo 2 e hipertensión arterial',
          plan: 'Ajustar la dieta y repetir los análisis.',
        ),
        medications: const [
          PrescriptionItem(
            medication: 'Metformina 850 mg',
            dose: '1 tableta',
            frequency: 'Cada 12 horas',
            duration: '30 días',
          ),
          PrescriptionItem(medication: 'Losartán 50 mg', dose: '1 tableta', frequency: 'Cada 24 horas', duration: '30 días'),
        ],
        orders: const [
          MedicalOrder(type: OrderType.lab, description: 'Hemograma'),
          MedicalOrder(type: OrderType.lab, description: 'Glicemia'),
        ],
        instructions: 'Tomar los medicamentos con las comidas y medir la glicemia en ayunas.',
        followUpInDays: 30,
        stopAt: ProcessStep.administrativeClosure,
      ),
      // L10 · José · pendiente el paso 10 (encuesta o llamada de seguimiento).
      _Story(
        createdAt: ago(200),
        patient: patient(SeedIds.jose),
        service: service(SeedIds.medicalGuidance),
        doctor: mendez,
        channel: RequestChannel.webPortal,
        reason: 'Orientación sobre vacunas para adultos',
        times: {
          _At.reception: ago(199),
          _At.validation: ago(198),
          _At.scheduling: ago(180),
          _At.confirmation: ago(179),
          _At.consent: ago(100),
          _At.start: fourDaysAgo,
          _At.end: fourDaysAgo.add(const Duration(minutes: 20)),
          _At.results: fourDaysAgo.add(const Duration(hours: 1)),
          _At.claim: ago(50),
          _At.payment: ago(49),
          _At.closure: ago(24),
        },
        appointment: fourDaysAgo,
        platform: VideoPlatform.meet,
        notes: const ClinicalNotes(
          chiefComplaint: 'Orientación sobre vacunas para adultos',
          assessment: 'Esquema de vacunación incompleto.',
          diagnosis: 'Consejería de vacunación',
          plan: 'Aplicar refuerzos de influenza y tétanos.',
        ),
        instructions: 'Acudir al vacunatorio con la cédula y la tarjeta de vacunas.',
        stopAt: ProcessStep.followUp,
      ),
    ];
  }

  // ----- Ayudantes -----

  static Duration _hours(Random random, double min, double max) =>
      Duration(minutes: ((min + random.nextDouble() * (max - min)) * 60).round());

  /// Un momento al azar entre [start] y [end], preferiblemente entre las 7:00 y las 22:00.
  static DateTime _randomMoment(Random random, DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;
    for (var attempt = 0; attempt < 10; attempt++) {
      final day = start.day + random.nextInt(days);
      final moment = DateTime(start.year, start.month, day, 7 + random.nextInt(15), random.nextInt(60));
      if (!moment.isBefore(start) && moment.isBefore(end)) return moment;
    }
    return start.add(Duration(minutes: random.nextInt(max(1, end.difference(start).inMinutes))));
  }

  /// Un turno del médico desde [day] (o en los días siguientes), no antes de [notBefore].
  static DateTime _appointmentSlot(
    Random random,
    Doctor doctor, {
    required DateTime day,
    required DateTime notBefore,
  }) {
    for (var offset = 0; offset < 30; offset++) {
      final date = DateTime(day.year, day.month, day.day + offset);
      final hours = doctor.schedule[date.weekday];
      if (hours == null) continue;
      final slots = [
        for (var minute = hours.startHour * 60; minute < hours.endHour * 60; minute += ScheduleService.slotMinutes)
          if (minute ~/ 60 != ScheduleService.breakHour)
            DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60),
      ].where((slot) => !slot.isBefore(notBefore)).toList();
      if (slots.isNotEmpty) return slots[random.nextInt(slots.length)];
    }
    throw StateError('${doctor.displayName} no tiene horario disponible.');
  }

  /// El siguiente día laborable del médico (desde mañana) a la hora indicada.
  static DateTime _nextWorkingDayAt(Doctor doctor, DateTime now, {required int hour}) {
    for (var offset = 1; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset, hour);
      if (doctor.schedule.containsKey(day.weekday)) return day;
    }
    return DateTime(now.year, now.month, now.day + 1, hour);
  }

  static DateTime _floorToHalfHour(DateTime t) => DateTime(t.year, t.month, t.day, t.hour, t.minute < 30 ? 0 : 30);

  static DateTime _ceilToHalfHour(DateTime t) {
    final floor = _floorToHalfHour(t);
    return floor == t ? t : floor.add(const Duration(minutes: 30));
  }

  static List<String> _pickSome(Random random, List<String> items, int count) =>
      ([...items]..shuffle(random)).take(count).toList();

  static Specialty _otherSpecialty(Random random, Specialty current) {
    const specialists = [Specialty.cardiology, Specialty.internalMedicine, Specialty.gynecology, Specialty.pediatrics];
    final options = [
      for (final s in specialists)
        if (s != current) s,
    ];
    return options[random.nextInt(options.length)];
  }

  static int _npsFor(Random random, int stars) => switch (stars) {
        5 => 9 + random.nextInt(2),
        4 => 7 + random.nextInt(3),
        3 => 5 + random.nextInt(3),
        2 => 2 + random.nextInt(4),
        _ => random.nextInt(4),
      };
}

/// Elige una clave al azar según su peso.
T _weighted<T>(Random random, Map<T, int> weights) {
  final total = weights.values.fold(0, (sum, weight) => sum + weight);
  var roll = random.nextInt(total);
  for (final entry in weights.entries) {
    if (roll < entry.value) return entry.key;
    roll -= entry.value;
  }
  return weights.keys.last;
}

/// Momentos de un caso: cuándo ocurre cada cosa.
enum _At {
  reception,
  validation,
  resolution,
  scheduling,
  confirmation,
  consent,
  start,
  end,
  results,
  claim,
  payment,
  closure,
  call,
  survey,
  cancellation,
}

/// Guion de un caso: quién lo pide, qué pasa y cuándo.
/// [build] lo convierte en un caso real aplicando [CaseWorkflow] paso a paso.
class _Story {
  _Story({
    required this.createdAt,
    required this.patient,
    required this.service,
    required this.doctor,
    required this.channel,
    required this.reason,
    required this.times,
    this.stopAt,
    this.cancelAt,
    this.rejection,
    this.continuesPrivate = false,
    this.receptionNotes = '',
    this.appointment,
    this.platform = VideoPlatform.teams,
    this.confirmVia = RequestChannel.whatsapp,
    this.notes = const ClinicalNotes(),
    this.medications = const [],
    this.orders = const [],
    this.referral,
    this.instructions = '',
    this.followUpInDays,
    this.paymentMethod = PaymentMethod.card,
    this.claimAfterClosure = ClaimStatus.approved,
    this.callNote,
    this.rating = 5,
    this.nps = 10,
    this.comment = '',
  });

  final DateTime createdAt;
  final Patient patient;
  final MedicalService service;
  final Doctor doctor;
  final RequestChannel channel;
  final String reason;

  /// Cuándo ocurre cada momento del caso.
  final Map<_At, DateTime> times;

  /// Casos en vivo: el caso se detiene con este paso PENDIENTE.
  final ProcessStep? stopAt;

  /// El paciente cancela mientras este paso está pendiente.
  final ProcessStep? cancelAt;

  /// Mensaje del rechazo del seguro; `null` si el seguro aprueba.
  final String? rejection;
  final bool continuesPrivate;
  final String receptionNotes;
  final DateTime? appointment;
  final VideoPlatform platform;
  final RequestChannel confirmVia;
  final ClinicalNotes notes;
  final List<PrescriptionItem> medications;
  final List<MedicalOrder> orders;
  final Referral? referral;
  final String instructions;
  final int? followUpInDays;
  final PaymentMethod paymentMethod;

  /// Estado de la reclamación después del cierre (respuesta posterior de la ARS).
  final ClaimStatus claimAfterClosure;

  /// Nota de la llamada de seguimiento; `null` si no hubo llamada.
  final String? callNote;
  final int rating;
  final int nps;
  final String comment;

  /// Momento del último evento: sirve para descartar casos que terminarían después de "ahora".
  DateTime get endsAt => times.values.fold(createdAt, (latest, time) => time.isAfter(latest) ? time : latest);

  TelemedicineCase build(String id, CatalogRepository catalog) {
    final admission = catalog.staffFor(Actor.admission).fullName;
    final billingStaff = catalog.staffFor(Actor.billing).fullName;
    DateTime at(_At moment) => times[moment]!;
    TelemedicineCase cancelled(TelemedicineCase c) => CaseWorkflow.cancel(
          c,
          role: UserRole.patient,
          actorName: patient.fullName,
          at: at(_At.cancellation),
          reason: 'El paciente canceló la cita',
        );

    // Paso 1
    var c = CaseWorkflow.request(
      id: id,
      patient: patient,
      service: service,
      channel: channel,
      reason: reason,
      preferredDate: DateTime(createdAt.year, createdAt.month, createdAt.day + 2),
      at: createdAt,
    );

    // Paso 2
    if (stopAt == ProcessStep.reception) return c;
    if (cancelAt == ProcessStep.reception) return cancelled(c);
    c = CaseWorkflow.registerReception(c, staffName: admission, notes: receptionNotes, at: at(_At.reception));

    // Paso 3
    if (stopAt == ProcessStep.insuranceValidation) return c;
    if (cancelAt == ProcessStep.insuranceValidation) return cancelled(c);
    final rejectionMessage = rejection;
    if (rejectionMessage == null) {
      final insurer = catalog.insurerById(patient.affiliation.insurerId);
      final validatedAt = at(_At.validation);
      c = CaseWorkflow.applyInsuranceResult(
        c,
        staffName: admission,
        result: InsuranceValidation(
          approved: true,
          coveragePercent: insurer.coverageFor(patient.affiliation.plan, service),
          authorizationNumber: CaseCodes.authorization(id, validatedAt),
          message: 'Cobertura aprobada por ${insurer.name}',
          at: validatedAt,
        ),
      );
    } else {
      c = CaseWorkflow.applyInsuranceResult(
        c,
        staffName: admission,
        result: InsuranceValidation(
          approved: false,
          coveragePercent: 0,
          message: rejectionMessage,
          at: at(_At.validation),
        ),
      );
      if (!continuesPrivate) {
        return CaseWorkflow.cancel(
          c,
          role: UserRole.admission,
          actorName: admission,
          at: at(_At.resolution),
          reason: 'El paciente no desea continuar como privado',
        );
      }
      c = CaseWorkflow.continueAsPrivate(c, staffName: admission, at: at(_At.resolution));
    }

    // Paso 4
    if (stopAt == ProcessStep.scheduling) return c;
    if (cancelAt == ProcessStep.scheduling) return cancelled(c);
    c = CaseWorkflow.schedule(
      c,
      doctor: doctor,
      dateTime: appointment!,
      platform: platform,
      staffName: admission,
      at: at(_At.scheduling),
    );

    // Paso 5
    if (stopAt == ProcessStep.patientConfirmation) return c;
    if (cancelAt == ProcessStep.patientConfirmation) return cancelled(c);
    c = CaseWorkflow.confirm(
      c,
      link: CaseCodes.meetingLink(id, platform),
      via: confirmVia,
      staffName: admission,
      at: at(_At.confirmation),
    );

    // Paso 6
    if (stopAt == ProcessStep.consentAdmission) return c;
    if (cancelAt == ProcessStep.consentAdmission) return cancelled(c);
    c = CaseWorkflow.signConsent(
      c,
      patient: patient,
      acceptedTerms: true,
      acceptedDataUse: true,
      identityConfirmed: true,
      signature: _seedSignature,
      at: at(_At.consent),
    );

    // Paso 7
    if (stopAt == ProcessStep.consultation) return c;
    c = CaseWorkflow.startConsultation(c, doctor: doctor, at: at(_At.start));
    c = CaseWorkflow.finishConsultation(c, doctor: doctor, notes: notes, at: at(_At.end));

    // Paso 8
    if (stopAt == ProcessStep.consultationResult) return c;
    c = CaseWorkflow.issueResults(
      c,
      doctor: doctor,
      instructions: instructions,
      medications: medications,
      orders: orders,
      referral: referral,
      followUpInDays: followUpInDays,
      at: at(_At.results),
    );

    // Paso 9
    if (stopAt == ProcessStep.administrativeClosure) return c;
    final invoice = BillingCalculator.invoiceFor(c, service);
    if (invoice.insurerAmount > 0) {
      c = CaseWorkflow.recordClaim(
        c,
        service: service,
        claimNumber: CaseCodes.claim(id),
        status: ClaimStatus.approved,
        staffName: billingStaff,
        at: at(_At.claim),
      );
    }
    if (invoice.copay > 0) {
      c = CaseWorkflow.registerPayment(
        c,
        service: service,
        method: paymentMethod,
        staffName: billingStaff,
        at: at(_At.payment),
      );
    }
    c = CaseWorkflow.closeAdministratively(c, service: service, staffName: billingStaff, at: at(_At.closure));
    if (invoice.insurerAmount > 0 && claimAfterClosure != ClaimStatus.approved) {
      // Respuesta posterior de la ARS (solo en los datos históricos): pendiente de pago o glosada.
      c = c.copyWith(billing: c.billing!.copyWith(claimStatus: claimAfterClosure));
    }

    // Paso 10
    if (stopAt == ProcessStep.followUp) return c;
    final note = callNote;
    if (note != null) {
      c = CaseWorkflow.logFollowUpCall(c, staffName: admission, note: note, at: at(_At.call));
    }
    return CaseWorkflow.submitSurvey(
      c,
      patient: patient,
      rating: rating,
      nps: nps,
      comment: comment,
      at: at(_At.survey),
    );
  }
}

/// Plantilla clínica por especialidad: notas y medicamentos típicos.
class _Template {
  const _Template(this.notes, this.medications);

  final ClinicalNotes notes;
  final List<PrescriptionItem> medications;
}

/// Firma de ejemplo para los consentimientos de la semilla.
const _seedSignature = [
  [
    SignaturePoint(0.08, 0.62),
    SignaturePoint(0.18, 0.35),
    SignaturePoint(0.28, 0.7),
    SignaturePoint(0.38, 0.3),
    SignaturePoint(0.48, 0.66),
  ],
  [SignaturePoint(0.55, 0.55), SignaturePoint(0.7, 0.42), SignaturePoint(0.92, 0.5)],
];

// Distribuciones del §13 del spec (pesos en %).
const _serviceWeights = {
  SeedIds.generalConsult: 30,
  SeedIds.internalMedicine: 12,
  SeedIds.pediatrics: 10,
  SeedIds.gynecology: 8,
  SeedIds.cardiology: 6,
  SeedIds.psychology: 8,
  SeedIds.nutrition: 6,
  SeedIds.secondOpinion: 3,
  SeedIds.chronicCare: 7,
  SeedIds.postConsultFollowUp: 5,
  SeedIds.postOpFollowUp: 2,
  SeedIds.resultsReview: 2,
  SeedIds.medicalGuidance: 1,
};
const _channelWeights = {
  RequestChannel.whatsapp: 32,
  RequestChannel.webPortal: 25,
  RequestChannel.mobile: 18,
  RequestChannel.phone: 15,
  RequestChannel.email: 10,
};
const _platformWeights = {VideoPlatform.teams: 40, VideoPlatform.zoom: 30, VideoPlatform.meet: 30};
const _ratingWeights = {5: 55, 4: 30, 3: 10, 2: 3, 1: 2};
const _claimWeights = {ClaimStatus.approved: 90, ClaimStatus.pending: 6, ClaimStatus.objected: 4};
const _paymentWeights = {PaymentMethod.card: 50, PaymentMethod.cash: 30, PaymentMethod.transfer: 20};

const _labTests = ['Hemograma', 'Glicemia', 'Perfil lipídico', 'Creatinina', 'Examen de orina', 'TSH'];
const _imagingTests = ['Radiografía de tórax', 'Sonografía abdominal', 'Electrocardiograma', 'Mamografía'];
const _instructions = [
  'Tomar los medicamentos según la receta y mantener una buena hidratación.',
  'Acudir a emergencias si presenta fiebre alta o dificultad para respirar.',
  'Realizar los estudios indicados y agendar la revisión de resultados.',
  'Mantener una dieta balanceada y actividad física regular.',
];
const _receptionNotes = ['Datos del paciente verificados.', 'Se confirmó el teléfono de contacto.', 'Solicitud completa.', ''];
const _rejectionMessages = ['Afiliación inactiva', 'Servicio no cubierto por el plan', 'Límite anual de consultas alcanzado'];
const _callNotes = [
  'El paciente refiere mejoría.',
  'Se recordó la próxima cita de seguimiento.',
  'El paciente no tiene dudas sobre el tratamiento.',
];
const _comments = {
  5: ['Excelente atención, muy puntual.', 'El médico fue muy amable y claro.', 'Muy práctico no tener que salir de casa.', ''],
  4: ['Buena atención; la conexión falló un poco.', 'Todo bien, el proceso fue rápido.', ''],
  3: ['La espera para la cita fue larga.', 'Regular: tuve problemas con el enlace.', ''],
  2: ['La llamada se cortó varias veces.', ''],
  1: ['No pude conectarme a tiempo.', ''],
};

/// Dos plantillas clínicas por especialidad.
const _templates = <Specialty, List<_Template>>{
  Specialty.generalMedicine: [
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Fiebre y dolor de garganta desde hace dos días',
        assessment: 'Paciente estable, amígdalas inflamadas, sin dificultad para respirar.',
        diagnosis: 'Faringitis aguda',
        plan: 'Analgésico, hidratación y reposo; volver si la fiebre persiste.',
      ),
      [PrescriptionItem(medication: 'Acetaminofén 500 mg', dose: '1 tableta', frequency: 'Cada 8 horas', duration: '5 días')],
    ),
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Dolor de cabeza frecuente en las tardes',
        assessment: 'Sin signos neurológicos de alarma.',
        diagnosis: 'Cefalea tensional',
        plan: 'Pausas activas, higiene del sueño y analgésico si hace falta.',
      ),
      [PrescriptionItem(medication: 'Ibuprofeno 400 mg', dose: '1 tableta', frequency: 'Cada 8 horas', duration: '3 días')],
    ),
  ],
  Specialty.internalMedicine: [
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Control de la presión arterial',
        assessment: 'Presión de 135/85 mmHg medida en casa.',
        diagnosis: 'Hipertensión arterial controlada',
        plan: 'Continuar el tratamiento y una dieta baja en sal.',
      ),
      [PrescriptionItem(medication: 'Losartán 50 mg', dose: '1 tableta', frequency: 'Cada 24 horas', duration: '30 días')],
    ),
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Cansancio y sed frecuente',
        assessment: 'Refiere glicemias elevadas en las últimas semanas.',
        diagnosis: 'Diabetes mellitus tipo 2 en control',
        plan: 'Ajuste de la dieta y control de la glicemia.',
      ),
      [PrescriptionItem(medication: 'Metformina 850 mg', dose: '1 tableta', frequency: 'Cada 12 horas', duration: '30 días')],
    ),
  ],
  Specialty.pediatrics: [
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Tos y congestión nasal en niño de 5 años',
        assessment: 'Sin fiebre y en buen estado general.',
        diagnosis: 'Infección respiratoria alta',
        plan: 'Lavados nasales y abundantes líquidos.',
      ),
      [
        PrescriptionItem(
          medication: 'Acetaminofén jarabe 160 mg/5 ml',
          dose: '5 ml',
          frequency: 'Cada 6 horas si hay fiebre',
          duration: '3 días',
        ),
      ],
    ),
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Erupción leve en la piel de una niña de 3 años',
        assessment: 'Lesiones leves, sin fiebre.',
        diagnosis: 'Dermatitis de contacto',
        plan: 'Evitar el agente irritante e hidratar la piel.',
      ),
      [PrescriptionItem(medication: 'Loratadina jarabe 5 mg/5 ml', dose: '5 ml', frequency: 'Cada 24 horas', duration: '5 días')],
    ),
  ],
  Specialty.gynecology: [
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Control ginecológico de seguimiento',
        assessment: 'Sin síntomas de alarma.',
        diagnosis: 'Control ginecológico normal',
        plan: 'Mantener los controles anuales.',
      ),
      [PrescriptionItem(medication: 'Ácido fólico 1 mg', dose: '1 tableta', frequency: 'Cada 24 horas', duration: '30 días')],
    ),
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Dolor menstrual intenso',
        assessment: 'Ciclos regulares y dolor moderado.',
        diagnosis: 'Dismenorrea primaria',
        plan: 'Analgésico y calor local.',
      ),
      [PrescriptionItem(medication: 'Ibuprofeno 400 mg', dose: '1 tableta', frequency: 'Cada 8 horas', duration: '3 días')],
    ),
  ],
  Specialty.cardiology: [
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Palpitaciones ocasionales',
        assessment: 'Sin dolor de pecho ni desmayos.',
        diagnosis: 'Extrasístoles benignas',
        plan: 'Reducir la cafeína y hacer un electrocardiograma de control.',
      ),
      [PrescriptionItem(medication: 'Magnesio 400 mg', dose: '1 tableta', frequency: 'Cada 24 horas', duration: '30 días')],
    ),
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Seguimiento de la hipertensión',
        assessment: 'Buena adherencia al tratamiento.',
        diagnosis: 'Hipertensión arterial estadio 1',
        plan: 'Continuar el tratamiento y caminar 30 minutos al día.',
      ),
      [PrescriptionItem(medication: 'Amlodipino 5 mg', dose: '1 tableta', frequency: 'Cada 24 horas', duration: '30 días')],
    ),
  ],
  // Psicología y Nutrición no recetan medicamentos.
  Specialty.psychology: [
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Ansiedad relacionada con el trabajo',
        assessment: 'Síntomas leves, sin riesgo.',
        diagnosis: 'Trastorno de ansiedad leve',
        plan: 'Técnicas de respiración y sesiones semanales.',
      ),
      [],
    ),
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Dificultad para dormir desde hace un mes',
        assessment: 'Estrés reciente por cambios familiares.',
        diagnosis: 'Insomnio de conciliación',
        plan: 'Higiene del sueño y diario de sueño.',
      ),
      [],
    ),
  ],
  Specialty.nutrition: [
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Plan de alimentación para bajar de peso',
        assessment: 'Índice de masa corporal de 27.',
        diagnosis: 'Sobrepeso',
        plan: 'Plan de 1,800 kcal y actividad física.',
      ),
      [],
    ),
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Control del colesterol con la alimentación',
        assessment: 'Dieta alta en grasas saturadas.',
        diagnosis: 'Dislipidemia leve',
        plan: 'Dieta baja en grasas saturadas y más fibra.',
      ),
      [],
    ),
  ],
};
```

- [ ] **Step 5: Ejecutar las pruebas y verificar que pasan**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/data/case_repository_test.dart test/data/seed_cases_test.dart
```

Expected: `All tests passed!` (9 pruebas: 2 del repositorio y 7 de la semilla).

Si falla una prueba de la semilla, no hay que tocar las expectativas para que pase. La causa está en el generador: un evento fuera de orden, un caso histórico que quedó abierto, etc. Se corrige ahí.

- [ ] **Step 6: Suite completa, formato y análisis**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
$dart = 'C:\Users\Helen\dev\flutter\bin\dart.bat'
Set-Location saludconecta
& $dart format -l 120 lib test
& $flutter test
& $flutter analyze
```

Expected:
- `All tests passed!` (unas 74 pruebas: las 4 de la etapa 1 y unas 70 de esta etapa);
- `No issues found!`.

Si `flutter analyze` reporta algún aviso, se corrige en el código.

- [ ] **Step 7: Marcar la etapa en la hoja de ruta**

En `docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md`, en la fila de la etapa 2, cambiar el estado `pendiente` por `hecha`.

- [ ] **Step 8: Commit de la etapa 2**

```powershell
git add saludconecta docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md
git status --short
git commit -m "feat: dominio y datos de SaludConecta (etapa 2)" -m "Modelos, reglas y flujo del proceso de 10 pasos, facturación, agenda, estadísticas, avisos, gateways simulados y datos semilla deterministas, con pruebas unitarias."
git log --oneline -3
```

Expected:
- el commit tiene como autor `FDLG301201`;
- `git status` ya no muestra cambios pendientes.

Siguiente paso: escribir el plan de la etapa 3, `2026-11-09-saludconecta-03-ilustraciones.md` (ilustraciones e infografías).
