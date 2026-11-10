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
          PrescriptionItem(
              medication: 'Losartán 50 mg', dose: '1 tableta', frequency: 'Cada 24 horas', duration: '30 días'),
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
const _receptionNotes = [
  'Datos del paciente verificados.',
  'Se confirmó el teléfono de contacto.',
  'Solicitud completa.',
  ''
];
const _rejectionMessages = [
  'Afiliación inactiva',
  'Servicio no cubierto por el plan',
  'Límite anual de consultas alcanzado'
];
const _callNotes = [
  'El paciente refiere mejoría.',
  'Se recordó la próxima cita de seguimiento.',
  'El paciente no tiene dudas sobre el tratamiento.',
];
const _comments = {
  5: [
    'Excelente atención, muy puntual.',
    'El médico fue muy amable y claro.',
    'Muy práctico no tener que salir de casa.',
    ''
  ],
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
      [
        PrescriptionItem(
            medication: 'Acetaminofén 500 mg', dose: '1 tableta', frequency: 'Cada 8 horas', duration: '5 días')
      ],
    ),
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Dolor de cabeza frecuente en las tardes',
        assessment: 'Sin signos neurológicos de alarma.',
        diagnosis: 'Cefalea tensional',
        plan: 'Pausas activas, higiene del sueño y analgésico si hace falta.',
      ),
      [
        PrescriptionItem(
            medication: 'Ibuprofeno 400 mg', dose: '1 tableta', frequency: 'Cada 8 horas', duration: '3 días')
      ],
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
      [
        PrescriptionItem(
            medication: 'Losartán 50 mg', dose: '1 tableta', frequency: 'Cada 24 horas', duration: '30 días')
      ],
    ),
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Cansancio y sed frecuente',
        assessment: 'Refiere glicemias elevadas en las últimas semanas.',
        diagnosis: 'Diabetes mellitus tipo 2 en control',
        plan: 'Ajuste de la dieta y control de la glicemia.',
      ),
      [
        PrescriptionItem(
            medication: 'Metformina 850 mg', dose: '1 tableta', frequency: 'Cada 12 horas', duration: '30 días')
      ],
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
      [
        PrescriptionItem(
            medication: 'Loratadina jarabe 5 mg/5 ml', dose: '5 ml', frequency: 'Cada 24 horas', duration: '5 días')
      ],
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
      [
        PrescriptionItem(
            medication: 'Ácido fólico 1 mg', dose: '1 tableta', frequency: 'Cada 24 horas', duration: '30 días')
      ],
    ),
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Dolor menstrual intenso',
        assessment: 'Ciclos regulares y dolor moderado.',
        diagnosis: 'Dismenorrea primaria',
        plan: 'Analgésico y calor local.',
      ),
      [
        PrescriptionItem(
            medication: 'Ibuprofeno 400 mg', dose: '1 tableta', frequency: 'Cada 8 horas', duration: '3 días')
      ],
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
      [
        PrescriptionItem(
            medication: 'Magnesio 400 mg', dose: '1 tableta', frequency: 'Cada 24 horas', duration: '30 días')
      ],
    ),
    _Template(
      ClinicalNotes(
        chiefComplaint: 'Seguimiento de la hipertensión',
        assessment: 'Buena adherencia al tratamiento.',
        diagnosis: 'Hipertensión arterial estadio 1',
        plan: 'Continuar el tratamiento y caminar 30 minutos al día.',
      ),
      [
        PrescriptionItem(
            medication: 'Amlodipino 5 mg', dose: '1 tableta', frequency: 'Cada 24 horas', duration: '30 días')
      ],
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
