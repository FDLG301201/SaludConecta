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
