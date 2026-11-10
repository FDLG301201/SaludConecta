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
