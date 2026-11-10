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
