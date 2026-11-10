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
