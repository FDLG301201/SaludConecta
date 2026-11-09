# SaludConecta — Diseño de la app de telemedicina

- **Asignatura:** ISO910 (UNAPEC), proyecto en equipo del 2do parcial
- **Fecha:** 2026-11-08
- **Estado:** diseño aprobado por secciones en la sesión de brainstorming

## 1. Contexto y alcance

El proyecto pide una app en Flutter, una PPT de máximo 20 diapositivas y un video de la exposición con cámara abierta. La evaluación da importancia a la explicación del código y a la arquitectura de Flutter, y valora **gráficas, imágenes y diagramas**.

La app implementa las dos infografías que entregó el equipo:

1. *Proceso Integral de Telemedicina entre Pacientes y el Sistema de Salud*: 10 pasos y 5 actores.
2. *Servicios de telemedicina*: 24 servicios en 3 grupos y los canales disponibles.

**Este documento cubre solo la app.** La PPT y el guion del video son un sub-proyecto posterior con su propio diseño.

## 2. Decisiones

| Tema | Decisión |
|---|---|
| Nombre | **SaludConecta**, lema "Más acceso, mejor salud" (constantes en `app_info.dart`) |
| Roles | Multi-rol: Paciente, Admisión, Médico y Facturación son interactivos. El 5.º actor (Personal de apoyo y tecnología) aparece en diagramas, en la prueba de conexión y como contacto de soporte, pero no es un rol |
| Datos | Todo local, en memoria, con datos semilla deterministas. Sin backend ni persistencia; al reiniciar la app vuelve al estado inicial. Repositorios detrás de interfaces |
| Estado | `provider` (ChangeNotifier) |
| Navegación | `go_router` con `redirect` por rol |
| Imágenes | Ilustraciones SVG propias (estilo plano uniforme) + las 2 infografías del equipo |
| Videollamada | Simulada con ilustraciones. Sin cámara real: durante la grabación de la exposición la webcam la ocupa el programa de grabación |
| Idioma | UI en español; identificadores en inglés; comentarios en español para apoyar la exposición |
| Plataformas | Android (emulador `Pixel_3a_API_34_extension_level_7_x86_64`) principal; Chrome de respaldo. Sin Windows desktop (faltan componentes de Visual Studio) |
| SDK | Flutter 3.19.0 / Dart 3.3.0 en `C:\Users\Helen\dev\flutter` (no está en el PATH; se invoca con ruta completa). No se actualiza la instalación |
| Versionado | git local en la raíz del repositorio, un commit por etapa terminada, sin push |
| Equipo | Nombres pendientes; quedan en `app_info.dart` para llenarlos antes de entregar |

## 3. Estructura del repositorio

```
Proyecto2doParcial/              ← raíz del repositorio git
├── docs/superpowers/
│   ├── specs/                   ← este documento
│   └── plans/                   ← plan de implementación
└── saludconecta/                ← proyecto Flutter (entregable "Fuentes")
    ├── lib/
    │   ├── main.dart            arranque: initializeDateFormatting + MultiProvider + runApp
    │   ├── app.dart             MaterialApp.router (tema, idioma español, rutas)
    │   ├── core/
    │   │   ├── constants/       app_info.dart (nombre, lema, curso, equipo)
    │   │   ├── theme/           app_colors.dart, app_theme.dart
    │   │   ├── router/          app_router.dart (rutas + redirect)
    │   │   ├── utils/           formatters.dart (fechas en español, montos RD$)
    │   │   └── widgets/         widgets reutilizables (ver §8)
    │   ├── domain/
    │   │   ├── models/          entidades y enums (ver §4)
    │   │   ├── process/         process_step.dart, process_rules.dart, process_exception.dart
    │   │   └── services/        billing_calculator.dart, stats_calculator.dart,
    │   │                        schedule_service.dart, notification_builder.dart
    │   ├── data/
    │   │   ├── repositories/    case_repository.dart, catalog_repository.dart (interfaz + en memoria)
    │   │   ├── seed/            seed_catalog.dart, seed_cases.dart (generador determinista)
    │   │   └── gateways/        insurance_gateway.dart (seguro simulado)
    │   ├── state/               session_provider.dart, case_provider.dart
    │   └── features/
    │       ├── auth/            bienvenida, selección de rol, ingreso
    │       ├── patient/         pantallas del paciente
    │       ├── admission/       pantallas de Admisión
    │       ├── doctor/          pantallas del Médico
    │       ├── billing/         pantallas de Facturación
    │       └── shared/          detalle del caso, videollamada, diagramas, indicadores, acerca de
    ├── assets/
    │   ├── illustrations/       SVG propios (ver §9)
    │   └── images/              infografia_proceso.webp, infografia_servicios.webp
    ├── test/                    pruebas unitarias y de widgets (ver §12)
    └── README.md                cómo ejecutar + guion de demo
```

El proyecto se crea con `flutter create --org edu.unapec.iso910 --project-name saludconecta --platforms android,web saludconecta`. La etiqueta de la app (Android y web) es "SaludConecta".

### Capas y dependencias

```
Presentación (features/, core/widgets)  ──acciones──▶  Estado (state/)
            ▲                                              │
            └──────────── notifyListeners() ◀──────────────┤
                                                           ▼
                                   Dominio (domain/)  ◀──  Datos (data/)
```

- **Presentación** solo lee y llama al **Estado**; nunca toca repositorios directamente.
- **Estado** (`ChangeNotifier`) orquesta: aplica las reglas del **Dominio** y guarda en los **Datos**.
- **Dominio** y **Datos** son Dart puro: no importan Flutter y se prueban sin interfaz. Los íconos de pasos, servicios y canales se asignan en `core/` con un mapeo `iconKey → IconData`, para que los modelos no dependan de Flutter.

### Paquetes

`provider`, `go_router`, `fl_chart`, `flutter_svg`, `intl`, `flutter_localizations` (SDK), `qr_flutter`, `url_launcher`. Se usan las versiones más recientes compatibles con Dart 3.3 / Flutter 3.19, según resuelva `flutter pub add`.

## 4. Modelo de dominio

Los modelos son inmutables (`final` + `copyWith`). Los IDs son `String`.

### Enums

- `UserRole { patient, admission, doctor, billing }`: roles que inician sesión.
- `Actor { patient, admission, doctor, support, billing }`: los 5 actores de la infografía, para diagramas y eventos.
- `ProcessStep`: los 10 pasos en orden. Cada uno tiene `number` (1–10), `title`, `description` (texto de la infografía), `actor` (actor principal, para colores) y `owners` (roles que pueden completarlo).

  | # | Valor | Título | Dueños |
  |---|---|---|---|
  | 1 | `requestAppointment` | Solicitud de cita | paciente |
  | 2 | `reception` | Recepción en Hospital / PSS | admisión |
  | 3 | `insuranceValidation` | Validación con el seguro | admisión |
  | 4 | `scheduling` | Agendamiento | admisión |
  | 5 | `patientConfirmation` | Confirmación al paciente | admisión |
  | 6 | `consentAdmission` | Consentimiento y admisión virtual | paciente |
  | 7 | `consultation` | Consulta de telemedicina | médico |
  | 8 | `consultationResult` | Resultado de la consulta | médico |
  | 9 | `administrativeClosure` | Cierre administrativo | facturación |
  | 10 | `followUp` | Seguimiento al paciente | paciente (encuesta) |

- `CaseStatus { active, insuranceRejected, cancelled, completed }`
- `RequestChannel { mobile, email, whatsapp, webPortal, phone }` → "Celular", "Correo", "WhatsApp", "Portal web", "Teléfono".
- `VideoPlatform { teams, zoom, meet }` → "MS Teams", "Zoom", "Google Meet".
- `ServiceGroup { clinical, careFollowUp, derived }` → los 3 grupos de la 2.ª infografía.
- `Specialty { generalMedicine, internalMedicine, pediatrics, gynecology, cardiology, psychology, nutrition }`
- `ClaimStatus { notApplicable, pending, approved, objected }` (`objected` = "Glosada").
- `PaymentMethod { cash, card, transfer }` → "Efectivo", "Tarjeta", "Transferencia". Solo se elige el método; nunca se capturan datos de tarjeta.
- `OrderType { lab, imaging }`

### Catálogo

- `Insurer { id, name, symbolAsset, planCoverage: Map<String, int> }` con 3 aseguradoras **ficticias**:
  - ARS Salud Plena: Básico 70, Plus 80, Premium 90.
  - ARS Vida Segura: Básico 65, Plus 80, Premium 90.
  - ARS Familia Sana: Básico 70, Plus 85, Premium 95.

  `coverageFor(plan, service)` = % del plan, menos 20 puntos si `service.reducedCoverage`.
- `InsuranceAffiliation { insurerId, plan, affiliateNumber, active }` (el `affiliateNumber` es el número de carnet).
- `Patient { id, fullName, cedula, birthDate, gender, phone, email, affiliation, avatarAsset? }`
- `Doctor { id, title, fullName, specialty, exequatur, avatarAsset, workDays: Set<int>, startHour, endHour }`. Los turnos son de 30 minutos y la pausa de 12:00 a 13:00 no se agenda.
- `StaffMember { id, fullName, actor, avatarAsset }`
- `MedicalService { id, name, group, description, iconKey, requestable, specialty?, fee?, reducedCoverage, relatedStep? }`

### Caso de telemedicina

```dart
class TelemedicineCase {
  final String id;                    // "TM-2026-0001"
  final String patientId;
  final String serviceId;
  final RequestChannel channel;
  final String reason;                // motivo de consulta
  final DateTime preferredDate;
  final DateTime createdAt;
  final ProcessStep currentStep;      // próximo paso PENDIENTE
  final CaseStatus status;
  final List<ProcessEvent> events;    // línea de tiempo
  final bool privatePay;              // continuó como privado tras rechazo
  final ReceptionData? reception;     // paso 2: registeredBy, notes
  final InsuranceValidation? insurance; // paso 3: approved, coveragePercent, authorizationNumber?, message, at
  final Appointment? appointment;     // paso 4: doctorId, dateTime, platform
  final Confirmation? confirmation;   // paso 5: link, sentVia, instructions, at
  final ConsentRecord? consent;       // paso 6: at, identityConfirmed, signature (trazos normalizados 0..1)
  final ConsultationRecord? consultation; // paso 7: startedAt, endedAt, ClinicalNotes
  final ConsultationResults? results; // paso 8: Prescription?, List<MedicalOrder>, Referral?, instructions, followUpInDays?
  final BillingRecord? billing;       // paso 9: Invoice, claimStatus, claimNumber?, Payment?, closedAt
  final FollowUpRecord? followUp;     // paso 10: List<FollowUpCall>, Survey?
}
```

- `ProcessEvent { step, actor, actorName, at, title, detail, completesStep }`. Las llamadas de seguimiento son eventos con `completesStep: false`.
- `ClinicalNotes { chiefComplaint, assessment, diagnosis, plan }`: motivo, evaluación, diagnóstico y plan.
- `Prescription { items: List<PrescriptionItem>, verificationCode }`, con `PrescriptionItem { medication, dose, frequency, duration }`.
- `MedicalOrder { type, description }`; `Referral { specialty, reason }` (siempre presencial).
- `Invoice { fee, coveragePercent, insurerAmount, copay }`; `Payment { method, amount, at }`.
- `Survey { rating (1–5), nps (0–10), comment, at }`; `FollowUpCall { at, byName, note }`.

**Semántica de `currentStep`:** es el próximo paso pendiente. Al crear la solicitud se registra el evento del paso 1 y el caso queda con `currentStep = reception`. Al completar el paso 10, `status = completed` y `currentStep` se queda en `followUp`. Los pasos completados se derivan de los eventos con `completesStep: true`.

### Reglas del proceso (`domain/process/process_rules.dart`)

- `ensureCanPerform(case, step, role)` lanza `ProcessException` con un mensaje en español si:
  - `case.status` no es `active`;
  - `case.currentStep != step`;
  - `role` no está en `step.owners`.
- Rechazo del seguro: la validación devuelve `approved: false`, el caso queda en `insuranceRejected` y sigue en el paso 3. Admisión resuelve con una de dos acciones:
  - **Continuar como privado:** `privatePay = true`, `status = active`, completa el paso 3 con la nota "Paciente privado (100%)" y pasa a `scheduling`.
  - **Cancelar:** `status = cancelled`.
- El paciente puede cancelar mientras `status ∈ {active, insuranceRejected}` y `currentStep.number ≤ 6`.
- El paso 7 lo completa el médico al finalizar la consulta. Requiere `chiefComplaint` y `diagnosis` no vacíos. La vista del paciente en la videollamada es solo visual y no cambia estado.
- El paso 8 requiere `instructions` no vacío. Al emitir se genera el `verificationCode` de la receta (si hay medicamentos).
- El paso 9 requiere:
  - la auditoría completa (todas las casillas en ✓);
  - la reclamación en `approved` o `notApplicable` (privado o cobertura 0);
  - el pago registrado, o copago = 0.
- El paso 10 se completa cuando el paciente envía la encuesta; el caso queda en `completed`.
- **Acciones auxiliares** (no completan un paso; se validan con `ensureCanAssist(case, step, role)`, que exige `status = active` y `currentStep = step`):
  - `startConsultation`: médico, paso 7.
  - `submitClaim` y `registerPayment`: facturación, paso 9.
  - `logFollowUpCall`: admisión, paso 10.
- Modo demo: el médico puede iniciar la consulta en cuanto el paso 6 está hecho, sin esperar la hora agendada.

### Servicios de dominio (Dart puro, probados con pruebas unitarias)

- **`BillingCalculator`:**
  - `fee` = tarifa del servicio;
  - `coverage` = 0 si `privatePay`, si no `insurance.coveragePercent`;
  - `insurerAmount` = `round(fee × coverage / 100)`;
  - `copay` = `fee − insurerAmount`;
  - `auditChecklist(case)`: consentimiento firmado; autorización presente o privado; notas clínicas completas; resultados emitidos; reclamación aprobada o N/A.
- **`ScheduleService.availableSlots(doctor, day, cases, now)`:** turnos de 30 minutos dentro del horario del médico, sin la pausa de 12:00–13:00, sin turnos ocupados por casos activos y solo turnos ≥ `now + 1h`. Horizonte de 14 días.
- **`StatsCalculator`:** funciones puras sobre `List<TelemedicineCase>` que alimentan las gráficas (ver §7).
- **`NotificationBuilder.forPatient(cases)`:** convierte eventos en mensajes para el paciente. Ejemplos:
  - "Tu seguro aprobó 80% de cobertura (AUT-…)";
  - "Cita agendada: jueves 12 de noviembre, 10:30 a. m. con Dr. Carlos Méndez";
  - "Te enviamos el enlace por WhatsApp. Firma tu consentimiento";
  - "Tus resultados están listos".

  El contador de no leídas se calcula contra `SessionProvider.notificationsSeenAt`.

### Gateways simulados (`data/gateways/`)

- **`InsuranceGateway.validate(patient, service, caseId)`:** espera 1.5 s.
  - Afiliación inactiva: rechazado con el mensaje "Afiliación inactiva".
  - Si no: aprobado con la cobertura de `coverageFor`. La autorización es `AUT-yyyyMMdd-NNNN`, con `NNNN` derivado del ID del caso.
- **Envío de confirmación:** espera 1 s y devuelve el enlace según la plataforma, con el formato de cada una y el ID del caso (p. ej., `https://meet.google.com/tmc-2026-0012`). Los enlaces son de demostración y no se abren; existe "Copiar enlace".
- **Reclamación al seguro:** espera 1.5 s; en vivo siempre se aprueba, con número `REC-NNNNN`. Las glosadas solo existen en los datos históricos.

## 5. Estado (Provider)

- **`SessionProvider`:** `role`, `currentPatient` o `currentStaff` (incluye el médico actual), `notificationsSeenAt`, `login(...)`, `switchTo(...)`, `logout()`. Es el `refreshListenable` del router.
- **`CaseProvider`:**
  - **Datos:** recibe `CaseRepository`, `CatalogRepository` e `InsuranceGateway`, y expone `cases`, `caseById` y los filtros por rol (`inboxFor(role, staffOrDoctor)`).
  - **Acciones:** una por transición (`requestAppointment`, `registerReception`, `validateInsurance`, `continueAsPrivate`, `cancelCase`, `scheduleAppointment`, `sendConfirmation`, `signConsent`, `startConsultation`, `finishConsultation`, `issueResults`, `submitClaim`, `registerPayment`, `closeAdministratively`, `logFollowUpCall`, `submitSurvey`). Cada acción:
    1. valida con `ProcessRules`;
    2. construye el caso actualizado con `copyWith` y agrega su `ProcessEvent`;
    3. lo guarda en el repositorio;
    4. llama a `notifyListeners()`.
  - **Operaciones lentas:** las que esperan exponen `isBusy(caseId)` para que la UI muestre carga y deshabilite botones.
- Los providers se registran en `main.dart` con `MultiProvider`. Las pantallas usan `context.watch`, `context.select` y `context.read`.

## 6. Navegación y pantallas

### Rutas (`go_router`)

| Ruta | Pantalla | Acceso |
|---|---|---|
| `/bienvenida` | Bienvenida (ruta inicial) | público |
| `/ingreso` | Selección de rol | público |
| `/ingreso/paciente` | Ingreso con carnet de seguro | público |
| `/ingreso/personal/:rol` | Elegir usuario demo (`admision`, `medico`, `facturacion`) | público |
| `/paciente`, `/paciente/citas`, `/paciente/servicios`, `/paciente/perfil` | Shell del paciente | paciente |
| `/paciente/solicitar?servicio=` | Asistente de solicitud | paciente |
| `/admision`, `/admision/agenda`, `/admision/seguimiento`, `/admision/indicadores` | Shell de Admisión | admisión |
| `/medico`, `/medico/indicadores` | Shell del Médico | médico |
| `/facturacion`, `/facturacion/reclamaciones`, `/facturacion/indicadores` | Shell de Facturación | facturación |
| `/caso/:id` | Detalle del caso | cualquier rol con sesión |
| `/caso/:id/diagrama` | Diagrama del proceso resaltando el caso | cualquier rol |
| `/caso/:id/consentimiento`, `/sala-espera`, `/videollamada`, `/resultados`, `/encuesta` | Acciones del paciente | paciente |
| `/caso/:id/procesar` | Stepper de Admisión (pasos 2–5) | admisión |
| `/caso/:id/consulta`, `/caso/:id/emitir-resultados` | Consulta y resultados | médico |
| `/caso/:id/cierre` | Cierre administrativo | facturación |
| `/proceso` | Diagramas del proceso (flujo + carriles) | cualquier rol |
| `/acerca` | Acerca de | cualquier rol |

**`redirect`:**

- Sin sesión, cualquier ruta fuera de `/bienvenida` e `/ingreso*` redirige a `/ingreso`.
- Con sesión, `/ingreso*` redirige al inicio del rol.
- Las rutas de otro rol redirigen al inicio del rol actual.
- Las acciones `/caso/:id/<acción>` de otro rol redirigen a `/caso/:id`.
- Un caso inexistente muestra "Caso no encontrado" con un botón para volver.

**Shells:** `StatefulShellRoute.indexedStack`. Usan `NavigationBar` en anchos < 800 px y `NavigationRail` en anchos ≥ 800 px. El contenido de las pantallas de lectura tiene un ancho máximo de 1100 px.

**Barra superior de todos los roles:**

- **"Cambiar de rol":** hoja inferior con los 4 roles y sus usuarios demo, que cambia de rol al instante.
- **"Diagrama del proceso"** (`/proceso`).
- **"Acerca de".**

### Pantallas comunes

- **Bienvenida:** `PageView` de 3 páginas con ilustración, indicador de puntos y botones "Omitir" y "Comenzar". Las páginas son:
  1. "Solicita tu cita por el canal que prefieras".
  2. "Consulta con tu médico desde casa".
  3. "Recibe tu receta y seguimiento".
- **Selección de rol:** 4 tarjetas con la ilustración del rol y una descripción breve. Muestra el aviso "Modo demostración: sin contraseñas".
- **Ingreso de paciente:** campo "Número de carnet de seguro" y chips con los 6 pacientes demo, que autocompletan el campo. Si el carnet no existe, se muestra un error en el campo.
- **Ingreso de personal:** lista de usuarios del rol. Para Médico, los 7 médicos con su especialidad.
- **Detalle del caso:**
  - encabezado: avatar, paciente, servicio, ID, ícono del canal y estado;
  - tarjeta **"Próxima acción"** según rol y paso, con un botón a la pantalla de esa acción, o el texto "Esperando a {actor}";
  - `CaseTimeline` con los 10 pasos;
  - secciones con los datos disponibles (seguro, cita, resultados, facturación);
  - botón "Ver en el diagrama";
  - "Cancelar cita", visible solo cuando las reglas lo permiten.
- **Videollamada** (`VideoCallView(perspective)`):
  - el otro participante a pantalla completa, con la ilustración de fondo y su avatar;
  - un anillo animado de "hablando" y el propio avatar en un recuadro;
  - arriba: nombre, especialidad, chip de la plataforma, cronómetro e indicador de conexión;
  - abajo: micrófono, cámara (al apagarla se muestran las iniciales), chat (hoja con mensajes simulados en la que se puede escribir) y colgar.
  - Variante médico: botón "Notas clínicas" (formulario en hoja inferior; panel lateral en pantallas anchas). Al colgar se confirma con "¿Finalizar consulta?" y se piden las notas obligatorias.
- **Diagramas del proceso** (`/proceso`): pestañas "Flujo" y "Por actor" (ver §10).
- **Acerca de:** pestañas:
  - "Proceso": infografía 1 con zoom;
  - "Servicios": infografía 2 con zoom;
  - "Arquitectura": diagrama de §10.4;
  - "Equipo": curso, integrantes desde `app_info.dart` y nombre y lema de la app.

### Paciente (Inicio · Mis citas · Servicios · Perfil)

- **Inicio:**
  - saludo con avatar y campana de notificaciones con contador; las notificaciones se abren en una hoja;
  - tarjeta del caso activo con barra "Paso X de 10: {título}" y botón de acción si el paso le toca;
  - accesos rápidos: Solicitar cita, Mis resultados (abre los resultados del caso más reciente que los tenga, o un estado vacío), Servicios, Acerca del proceso;
  - carrusel "Educación en salud" con 5 consejos.
- **Solicitar cita:** asistente de 3 pasos con `Form` y validaciones, en un `Stepper` horizontal (pasos "Servicio", "Canal y motivo" y "Fecha"):
  1. elegir servicio solicitable;
  2. canal (los 5 canales de la infografía 1) y motivo (mínimo 10 caracteres);
  3. fecha preferida (`showDatePicker` en español) y resumen.

  Al enviar, crea el caso y navega al detalle.
- **Mis citas:** pestañas "Activas" e "Historial", con tarjetas de caso y chip de estado. Si no hay citas, se muestra un estado vacío ilustrado.
- **Consentimiento:**
  - texto del consentimiento informado de telemedicina (redactado para la demo);
  - casilla "He leído y acepto el consentimiento informado";
  - casilla "Autorizo el uso de mis datos de salud para esta atención";
  - casilla "Confirmo mi identidad: {nombre}, cédula {x}";
  - **firma con el dedo** (`SignaturePad` con `GestureDetector` + `CustomPainter`, botón "Borrar"). La firma es obligatoria.

  "Firmar y continuar" completa el paso 6 y lleva a la sala de espera.
- **Sala de espera:**
  - prueba de conexión animada: Internet (latencia simulada), cámara, micrófono (barras de nivel animadas) y plataforma operativa;
  - tarjeta de Soporte TI (Luis Castillo) con "Llamar a soporte" (`url_launcher` con `tel:`);
  - "Unirse a la consulta" lleva a la videollamada del paciente.
- **Resultados:**
  - **receta con aspecto de documento**: logo, médico, exequátur, paciente, fecha, medicamentos, **QR** (`qr_flutter`) con el código de verificación;
  - órdenes de laboratorio e imágenes, referimiento e indicaciones;
  - "Solicitar cita de seguimiento" si `followUpInDays`: abre el asistente con "Seguimiento postconsulta" y la fecha preferida ya puesta.
- **Encuesta:** 5 estrellas, escala 0–10 ("¿Qué tan probable es que nos recomiendes?") y comentario opcional. Al enviar, el caso queda completado.
- **Servicios:**
  - los 24 servicios de la infografía 2, en 3 secciones con ícono y descripción;
  - un chip por servicio: "Solicitar" (abre el asistente con ese servicio), "Se genera en tu consulta" o "Incluido en el proceso";
  - una franja "Canales disponibles" con Celular, Correo, WhatsApp, Portal web y Videoconferencia.
- **Perfil:**
  - **carnet de seguro** dibujado con widgets (degradado, símbolo de la aseguradora, plan, número y estado);
  - datos personales;
  - "Mi resumen": dona "Cubierto por el seguro vs. pagado por mí" y barras "Mis consultas por especialidad";
  - enlaces a Acerca de y Cambiar de rol, y "Cerrar sesión".

### Admisión (Bandeja · Agenda · Seguimiento · Indicadores)

- **Bandeja:** filtros con contador:
  - Nuevas (pendiente paso 2);
  - Por validar (3, incluye rechazadas);
  - Por agendar (4);
  - Por confirmar (5).

  Las tarjetas de caso muestran cuánto tiempo lleva esperando.
- **Procesar solicitud:** `Stepper` vertical de 4 pasos. Abre en el paso pendiente y cada "Continuar" confirma la transición.
  1. **Registrar:** datos de la solicitud y notas.
  2. **Validar seguro:** carnet; "Consultar al seguro" muestra carga y luego el resultado. Si es rechazado, se ofrecen "Continuar como privado" y "Cancelar solicitud".
  3. **Agendar:**
     - médico, filtrado por la especialidad del servicio;
     - chips de días con disponibilidad (14 días);
     - cuadrícula de horarios (`ChoiceChip`);
     - plataforma (`SegmentedButton`).
  4. **Confirmar:** vista previa del mensaje (fecha, médico, plataforma, enlace, "Ingresa 10 minutos antes", "Firma tu consentimiento en la app") y canal de envío (WhatsApp o Correo). "Enviar" muestra carga y vuelve a la bandeja con un aviso.
- **Agenda:** selector de los próximos 7 días y citas del día agrupadas por médico, con hora y chip de estado.
- **Seguimiento:** casos en el paso 10, con "Registrar llamada" (nota) y el estado de la encuesta.

### Médico (Agenda · Indicadores)

- **Agenda:** citas del médico en sesión: hoy y próximas. Cada una con un chip de estado:
  - "Esperando consentimiento" (paso 6 pendiente);
  - **"Paciente en sala de espera"** (paso 7 pendiente), que habilita el botón "Iniciar consulta";
  - "Resultados pendientes" (paso 8 pendiente).
- **Consulta:** `VideoCallView(perspective: doctor)` con las notas clínicas. "Finalizar" completa el paso 7 y abre la pantalla de emitir resultados.
- **Emitir resultados:** formulario por secciones:
  - **receta:** medicamentos con dosis, frecuencia y duración, más chips de sugerencias como "Acetaminofén 500 mg" u "Omeprazol 20 mg";
  - **órdenes:** casillas de laboratorio (Hemograma, Glicemia, Perfil lipídico, Creatinina, Examen de orina, TSH) e imágenes (Radiografía de tórax, Sonografía abdominal, Electrocardiograma, Mamografía);
  - **referimiento:** interruptor, especialidad y motivo;
  - **indicaciones:** obligatorias, con sugerencias;
  - **próxima cita:** 7, 15 o 30 días, o "No requiere".

  "Emitir" completa el paso 8.

### Facturación (Pendientes · Reclamaciones · Indicadores)

- **Pendientes:** casos con el paso 9 pendiente.
- **Cierre administrativo:**
  - **Factura:** concepto, tarifa, cobertura % o "Privado", monto a cargo del seguro y copago.
  - **Reclamación:** "Enviar reclamación a {aseguradora}" muestra carga y luego "Aprobada REC-…". Es N/A si el paciente es privado.
  - **Auditoría:** lista automática de §4 con ✓ o ✗.
  - **Pago:** método (chips) y "Registrar pago de copago RD$X".

  "Cerrar caso" solo se habilita cuando todo está completo, y completa el paso 9.
- **Reclamaciones:** todas las reclamaciones (históricas y en vivo), con filtro por estado: Aprobada, Pendiente, Glosada.

## 7. Gráficas (`fl_chart`)

Todas se calculan con `StatsCalculator` a partir de los mismos casos (históricos + en vivo), así que se actualizan en vivo. Cada gráfica va en un `ChartCard` con título, subtítulo y leyenda. La ventana es de 12 meses hasta el mes actual.

La pantalla **Indicadores** es compartida por el personal y tiene 4 pestañas; la pestaña inicial depende del rol (Admisión → Operación, Médico → Clínico, Facturación → Financiero).

| Pestaña | Visualización | Tipo |
|---|---|---|
| Operación | KPIs: solicitudes del mes, casos en proceso, días promedio solicitud→consulta, % de rechazo del seguro | `KpiTile` |
| Operación | Solicitudes por canal | dona (`PieChart`) |
| Operación | Solicitudes vs. consultas realizadas por mes | líneas (`LineChart`, 2 series) |
| Operación | Embudo del proceso: casos que completaron cada paso | barras horizontales |
| Operación | Tiempo promedio por etapa (horas, pasos 2–10) | barras (`BarChart`) |
| Clínico | Consultas por especialidad | barras |
| Clínico | Plataforma usada (Teams / Zoom / Meet) | dona |
| Clínico | Resultados emitidos: recetas, órdenes de laboratorio, órdenes de imágenes, referimientos | barras |
| Financiero | Facturación mensual: monto del seguro vs. copago | barras apiladas |
| Financiero | Reclamaciones por estado | dona |
| Financiero | Facturación por aseguradora | barras |
| Satisfacción | KPIs: calificación promedio (★) y NPS | `KpiTile` |
| Satisfacción | Distribución de calificaciones 1–5 | barras |
| Satisfacción | Satisfacción promedio por mes | líneas |
| Perfil del paciente | Cubierto por el seguro vs. pagado | dona |
| Perfil del paciente | Mis consultas por especialidad | barras |

**Definiciones:**

- **NPS:** % de puntajes 9–10 menos % de puntajes 0–6.
- **Embudo:** cuenta, por cada paso, los casos que tienen un evento que lo completa.
- **Tiempo por etapa:** promedio de horas entre la finalización del paso anterior y la del paso actual.

## 8. Widgets reutilizables (`core/widgets/`)

| Widget | Uso |
|---|---|
| `AppIllustration` | Muestra un SVG del catálogo de ilustraciones |
| `AvatarImage` | Avatar SVG, o iniciales si no hay avatar |
| `SectionCard` | Tarjeta con título |
| `ChartCard` | Tarjeta para una gráfica |
| `KpiTile` | Indicador clave |
| `StepBadge` | Número de paso en círculo, con el color del actor |
| `ActorChip` | Chip del actor con su color |
| `StatusChip` | Estado del caso |
| `CaseCard` | Tarjeta de caso para las listas |
| `EmptyState` | Ilustración + texto para estados vacíos |
| `LoadingButton` | Botón con carga durante operaciones lentas |
| `RoleSwitcherSheet` | Hoja de "Cambiar de rol" |
| `InsuranceCard` | Carnet de seguro dibujado |

## 9. Imágenes

**Ilustraciones SVG propias** (`assets/illustrations/`):

- **Estilo:** plano, colores de la paleta (§11), formas redondeadas, parecido a los íconos de la infografía.
- **Restricciones de `flutter_svg`:** sin filtros, máscaras, `<style>` ni `<text>`; solo atributos en línea, degradados lineales o radiales y `clipPath`.

| Archivo(s) | Contenido |
|---|---|
| `logo.svg` | Tableta con cruz médica (como el ícono de la infografía) |
| `onboarding_request.svg`, `onboarding_consult.svg`, `onboarding_followup.svg` | Bienvenida |
| `role_patient.svg`, `role_admission.svg`, `role_doctor.svg`, `role_billing.svg` | Selección de rol |
| `doctor_1.svg` … `doctor_7.svg` | Un avatar por médico |
| `patient_1.svg` … `patient_6.svg` | Un avatar por paciente demo |
| `room_clinic.svg`, `room_home.svg` | Fondos de la videollamada |
| `empty_cases.svg`, `empty_results.svg` | Estados vacíos |
| `insurer_salud_plena.svg`, `insurer_vida_segura.svg`, `insurer_familia_sana.svg` | Símbolos de las aseguradoras ficticias (sin texto; el nombre se escribe con `Text`) |
| `support.svg` | Soporte técnico (sala de espera) |

Los avatares se generan con un script auxiliar que vive fuera del proyecto; solo se versionan los SVG resultantes.

**Infografías del equipo:** se copian a `assets/images/` como `infografia_proceso.webp` e `infografia_servicios.webp` y se muestran con `InteractiveViewer`.

**Imágenes generadas en la app:** el QR de la receta (`qr_flutter`) y el carnet de seguro.

**Marcas de terceros:** Teams, Zoom y Meet se muestran por nombre con íconos genéricos de Material, sin sus logos.

## 10. Diagramas

1. **Diagrama de flujo del proceso** (`FlowDiagramPainter`, `CustomPainter`):
   - **Recorrido:** óvalo de inicio "Paciente con carnet de seguro", los 10 pasos en columna, el rombo "¿El seguro aprueba?" tras el paso 3 y el óvalo de fin "Paciente atendido".
     - Rama "No" del rombo: nodo punteado "¿Privado o cancelar?". "Privado" lleva al paso 4 y "Cancelar" al óvalo "Solicitud cancelada".
   - **Nodos:** color del actor dueño, número de paso y título dibujados con `TextPainter`; flechas con punta.
   - **Interacción:**
     - `InteractiveViewer` para zoom y desplazamiento;
     - `GestureDetector.onTapUp` con hit-testing contra los rectángulos de los nodos, que abre una hoja con actor, descripción y servicios relacionados;
     - leyenda de actores.
   - **Modo caso** (`/caso/:id/diagrama`): pasos completados en verde con ✓, paso actual con pulso animado (`AnimationController`) y pendientes en gris.
2. **Diagrama de carriles** (`SwimlanePainter`):
   - 5 carriles horizontales, uno por actor, incluido Soporte TI, y 10 columnas, una por paso.
   - Cada paso va en el carril de su dueño, con flechas ortogonales entre pasos consecutivos.
   - Los pasos compartidos (7: médico + paciente; 10: paciente + admisión) llevan un nodo secundario punteado en el otro carril.
   - Soporte TI tiene nodos punteados en los pasos 5–7: "Enlace y plataforma", "Prueba de conexión" y "Soporte en consulta".
   - Desplazamiento horizontal con `InteractiveViewer` (`constrained: false`).
3. **Línea de tiempo del caso** (`CaseTimeline`, con widgets): vertical, con conector pintado, 10 pasos, y para cada uno la fecha y hora, el actor y el detalle del evento. El paso actual va resaltado.
4. **Diagrama de arquitectura** (`ArchitectureDiagram`, con widgets, en Acerca de):
   - **Arquitectura de Flutter:**
     - Framework (Dart): Material/Cupertino → Widgets → Rendering → Animation/Painting/Gestures → Foundation.
     - Engine (C++): Skia/Impeller, Dart runtime, texto, *platform channels*.
     - Embedder: Android / Web.
   - **Arquitectura de SaludConecta:** las 4 capas de §3, con ejemplos de archivos reales.

## 11. Tema visual

- **Material 3:** `ColorScheme.fromSeed` con primario azul `#1565C0`, secundario verde azulado `#00897B` y fondo `#F4F8FB`. Los encabezados usan azul marino `#0D3B66`.
- **Colores por actor:**
  - Paciente `#43A047`;
  - Admisión `#1E88E5`;
  - Médico `#00897B`;
  - Soporte TI `#7B1FA2`;
  - Facturación `#283593`.
- **Colores de estado:**
  - completado `#2E7D32`;
  - actual `#F9A825`;
  - pendiente `#9E9E9E`;
  - rechazado o cancelado `#C62828`.
- **Tipografía:** la predeterminada (Roboto), con títulos en negrita. Sin modo oscuro.
- **Formatos:**
  - fechas con `intl` en `es` (p. ej., "jueves, 12 de noviembre · 10:30 a. m.");
  - montos en formato dominicano "RD$1,500.00" (`NumberFormat.currency(locale: 'en_US', symbol: 'RD\$')`).

## 12. Manejo de errores y pruebas

**Errores:**

- `ProcessException`: la UI la captura y muestra un `SnackBar` con el mensaje; además, la UI solo ofrece acciones válidas.
- Validación de formularios con `Form` y `validator`s.
- Operaciones lentas: carga visible y botones deshabilitados (`isBusy`).
- Rutas: `redirect` y "Caso no encontrado".
- Listas sin datos: `EmptyState` ilustrado.

**Pruebas** (`flutter test`):

- **Unitarias** (`test/domain/`, `test/state/`):
  - `process_rules_test`: recorrido 1→10 completo; paso fuera de orden; rol incorrecto; operación sobre un caso cancelado; rechazo del seguro → privado y → cancelar; cancelación del paciente solo hasta el paso 6.
  - `billing_calculator_test`: copago con cobertura normal y reducida, privado y redondeo; auditoría completa e incompleta.
  - `schedule_service_test`: excluye la pausa de 12:00–13:00, los turnos ocupados, el pasado y los días no laborables.
  - `stats_calculator_test`: con un conjunto pequeño fijo, prueba canales, embudo, tiempos, NPS y facturación mensual.
  - `seed_cases_test`: determinismo (dos ejecuciones con el mismo `now` dan lo mismo), unos 200 históricos y 10 casos en vivo que cubren los pasos pendientes del 2 al 10, uno de ellos con afiliación inactiva.
  - `case_provider_test`: las acciones notifican, agregan eventos y respetan las reglas.
- **De widgets** (`test/features/`):
  - el ingreso como paciente lleva al Inicio;
  - una solicitud creada por el paciente aparece en "Nuevas" de Admisión;
  - el diagrama de flujo se pinta y responde al toque;
  - Indicadores renderiza las 4 pestañas sin excepciones.
- `flutter analyze` sin advertencias (lints por defecto de `flutter_lints`).

**Verificación manual:**

- recorrer el guion de demo completo en Chrome desde el panel del navegador, con capturas;
- compilar e instalar en el emulador Android.

## 13. Datos semilla

- **Personal:**
  - Admisión: Ana Peña.
  - Facturación: Roberto Díaz.
  - Soporte TI: Luis Castillo (solo contacto).
- **Médicos:**
  - Dr. Carlos Méndez (Medicina general);
  - Dra. Laura Jiménez (Medicina interna);
  - Dr. Andrés Rosario (Pediatría);
  - Dra. Patricia Núñez (Ginecología);
  - Dr. Miguel Santana (Cardiología);
  - Lic. Sofía Herrera (Psicología);
  - Lic. Daniela Cruz (Nutrición).

  Trabajan de lunes a viernes de 8:00 a 17:00; Méndez además el sábado de 8:00 a 12:00.
- **Pacientes demo:**
  - **María Fernández** (paciente principal, ARS Salud Plena Plus, activa);
  - José Martínez;
  - Carmen Reyes;
  - **Pedro Almonte** (afiliación **inactiva**);
  - Luisa Gómez;
  - Ramón Ortiz.

  Los teléfonos usan el prefijo ficticio 809-555 y las cédulas y carnets son ficticios.
- **Servicios:** los 24 de la infografía 2.
  - **Solicitables:**

    | Servicio | Especialidad | Tarifa |
    |---|---|---|
    | Consulta médica general | Medicina general | RD$1,500 |
    | Medicina interna | Medicina interna | RD$2,500 |
    | Pediatría de orientación | Pediatría | RD$2,000 |
    | Ginecología de seguimiento | Ginecología | RD$2,500 |
    | Cardiología de seguimiento | Cardiología | RD$2,800 |
    | Psicología *(cobertura reducida)* | Psicología | RD$2,200 |
    | Nutrición *(cobertura reducida)* | Nutrición | RD$1,800 |
    | Segunda opinión médica *(cobertura reducida)* | Medicina interna | RD$3,000 |
    | Control de pacientes crónicos | Medicina interna | RD$1,200 |
    | Seguimiento postconsulta | Medicina general | RD$1,000 |
    | Seguimiento postoperatorio no crítico | Medicina general | RD$1,200 |
    | Revisión de resultados de estudios | Medicina general | RD$1,000 |
    | Orientación médica | Medicina general | RD$800 |

  - **Incluidos en el proceso o en la app:** Educación en salud (consejos del Inicio), Recordatorios y seguimiento (paso 10) y Encuesta de satisfacción (paso 10).
  - **Derivados:** los 8 del grupo 3, con `relatedStep` 3 u 8 según corresponda.
- **Históricos** (`SeedCases.generate(now:)` con `Random(2026)`, deterministas para un mismo `now`): unos 200 casos repartidos en los 12 meses hasta `now` (el mes actual parcial), con volumen mensual creciente de unos 10 a unos 24. Las fechas son relativas a `now`, así las gráficas siempre tienen datos; en la app `now = DateTime.now()` y en las pruebas una fecha fija. Se reparten entre los 6 pacientes demo y unos 40 pacientes de fondo con nombres generados. María tiene 4 consultas completadas para sus gráficas personales.
  - **Distribuciones:**
    - Canal: WhatsApp 32%, Portal web 25%, Celular 18%, Teléfono 15%, Correo 10%.
    - Plataforma: Teams 40%, Zoom 30%, Meet 30%.
    - Calificación: 5★ 55%, 4★ 30%, 3★ 10%, 2★ 3%, 1★ 2%.
    - Reclamaciones: aprobadas 90%, pendientes 6%, glosadas 4%.
    - Resultados: receta 85%, laboratorio 40%, imágenes 20%, referimiento 12%, próxima cita 30%.
  - **Desenlaces:** 6% rechazados por el seguro (la mitad sigue como privado y la mitad cancela), 5% cancelados por el paciente y el resto completados con encuesta.
  - **Duraciones por etapa:**
    - recepción: 0.5–4 h;
    - validación: 0.2–2 h;
    - agendamiento: 1–24 h;
    - confirmación: 0.1–2 h;
    - consulta: 1–5 días después de la solicitud;
    - consentimiento: antes de la consulta;
    - resultados: 0.2–2 h después de la consulta;
    - cierre: 1–72 h;
    - encuesta: 1–5 días.
- **Casos en vivo** (fechas relativas a `DateTime.now()`), uno por paso pendiente:

  | Caso | Paciente | Paso pendiente | Para demostrar |
  |---|---|---|---|
  | L1 | José Martínez | 2 Recepción | Bandeja "Nuevas" |
  | L2 | Carmen Reyes | 3 Validación | Validación aprobada |
  | L3 | Pedro Almonte | 3 Validación | **Rechazo** del seguro |
  | L4 | Luisa Gómez | 4 Agendamiento | Agendar |
  | L5 | Ramón Ortiz | 5 Confirmación (Dra. Jiménez) | Enviar enlace |
  | L6 | José Martínez | 6 Consentimiento (Dr. Méndez) | Firma del paciente |
  | L7 | Carmen Reyes | 7 Consulta (Dr. Méndez) | "Paciente en sala de espera" |
  | L8 | Luisa Gómez | 8 Resultado (Dr. Méndez) | Emitir resultados |
  | L9 | Ramón Ortiz | 9 Cierre | Cierre administrativo |
  | L10 | José Martínez | 10 Seguimiento | Encuesta / llamada |

  María no tiene caso activo: se crea en vivo durante la demo.

## 14. Guion de demo (va en el README)

1. Bienvenida → Paciente → María Fernández → Inicio.
2. Solicitar cita: Consulta médica general, WhatsApp, motivo y fecha.
3. Cambiar a Admisión (Ana Peña) → "Nuevas" → Procesar: registrar → validar (80%) → agendar (Dr. Méndez, Teams) → confirmar por WhatsApp.
4. Cambiar a Paciente: notificación → firmar consentimiento → sala de espera → videollamada.
5. Cambiar a Médico (Dr. Méndez) → "Paciente en sala de espera" → iniciar → notas → finalizar → emitir receta, órdenes y seguimiento a 15 días.
6. Cambiar a Facturación (Roberto Díaz) → cierre: reclamación → auditoría → pago → cerrar.
7. Cambiar a Paciente → resultados (receta con QR) → encuesta 5★.
8. Cambiar a Admisión → Indicadores (el nuevo caso se refleja) → Diagrama del proceso.
9. Camino alterno: Admisión → Pedro Almonte → validar → rechazo → continuar como privado.

## 15. Compilación Android

El JDK detectado es el de Android Studio (Java 21). La plantilla de Flutter 3.19 usa Gradle 7.x, que no compila con Java 21. Ajustes dentro del proyecto, sin tocar la instalación:

- Gradle wrapper 8.x.
- Android Gradle Plugin 8.x y Kotlin compatibles.

Las versiones exactas y la verificación (`flutter build apk --debug` e instalación en el emulador) van en el plan. Si Android pide aceptar licencias, el usuario ejecuta `flutter doctor --android-licenses`.

## 16. Fuera de alcance

- Backend, persistencia y autenticación real.
- Cámara o videollamada real.
- Envío real de WhatsApp o correo (solo se simula; `url_launcher` se usa únicamente para `tel:` de soporte).
- Exportar a PDF y notificaciones push.
- iOS y Windows.
- Modo oscuro e ícono de lanzador personalizado (posible mejora final si sobra tiempo).
- Nombres o logos reales de aseguradoras y logos de Teams, Zoom y Meet.

## 17. Etapas de implementación (cada una termina con commit)

1. **Andamiaje:** `flutter create`, ajuste de Gradle, paquetes, tema, router mínimo y git. Compila en Chrome y Android.
2. **Dominio y datos:** modelos, reglas, calculadoras, gateways, semilla y pruebas unitarias.
3. **Ilustraciones SVG**, infografías y catálogo de assets.
4. **Estado + autenticación + shells:** providers, bienvenida, ingreso, cambio de rol, shells por rol y detalle del caso con línea de tiempo.
5. **Flujo del paciente.**
6. **Flujo de Admisión.**
7. **Flujo del Médico:** videollamada, notas y resultados.
8. **Flujo de Facturación.**
9. **Indicadores:** gráficas del personal y del paciente.
10. **Diagramas:** flujo, carriles y arquitectura, más Acerca de.
11. **Cierre:** pruebas de widgets, `flutter analyze`, verificación en Chrome y Android, README y guion de demo.
