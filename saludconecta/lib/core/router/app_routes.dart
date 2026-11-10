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
