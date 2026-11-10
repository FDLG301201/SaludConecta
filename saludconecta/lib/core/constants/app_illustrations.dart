import '../../domain/models/enums.dart';

/// Rutas de todas las imágenes de la app (§9 del spec). La UI usa estas constantes,
/// nunca rutas escritas a mano.
class AppIllustrations {
  const AppIllustrations._();

  static const _dir = 'assets/illustrations';

  static const logo = '$_dir/logo.svg';

  // Bienvenida.
  static const onboardingRequest = '$_dir/onboarding_request.svg';
  static const onboardingConsult = '$_dir/onboarding_consult.svg';
  static const onboardingFollowUp = '$_dir/onboarding_followup.svg';

  // Selección de rol.
  static const rolePatient = '$_dir/role_patient.svg';
  static const roleAdmission = '$_dir/role_admission.svg';
  static const roleDoctor = '$_dir/role_doctor.svg';
  static const roleBilling = '$_dir/role_billing.svg';

  // Fondos de la videollamada: consultorio (detrás del médico) y casa (detrás del paciente).
  static const roomClinic = '$_dir/room_clinic.svg';
  static const roomHome = '$_dir/room_home.svg';

  // Estados vacíos.
  static const emptyCases = '$_dir/empty_cases.svg';
  static const emptyResults = '$_dir/empty_results.svg';

  /// Soporte TI (sala de espera).
  static const support = '$_dir/support.svg';

  // Símbolos de las aseguradoras ficticias (sin texto; el nombre se escribe con Text).
  static const insurerSaludPlena = '$_dir/insurer_salud_plena.svg';
  static const insurerVidaSegura = '$_dir/insurer_vida_segura.svg';
  static const insurerFamiliaSana = '$_dir/insurer_familia_sana.svg';

  /// Avatares de los 7 médicos, en el orden de `SeedCatalog.doctors`.
  static const doctors = [
    '$_dir/doctor_1.svg',
    '$_dir/doctor_2.svg',
    '$_dir/doctor_3.svg',
    '$_dir/doctor_4.svg',
    '$_dir/doctor_5.svg',
    '$_dir/doctor_6.svg',
    '$_dir/doctor_7.svg',
  ];

  /// Avatares de los 6 pacientes de demostración, en el orden de `SeedCatalog.demoPatients`.
  static const patients = [
    '$_dir/patient_1.svg',
    '$_dir/patient_2.svg',
    '$_dir/patient_3.svg',
    '$_dir/patient_4.svg',
    '$_dir/patient_5.svg',
    '$_dir/patient_6.svg',
  ];

  /// Escenas e íconos dibujados a mano.
  static const scenes = [
    logo,
    onboardingRequest,
    onboardingConsult,
    onboardingFollowUp,
    rolePatient,
    roleAdmission,
    roleDoctor,
    roleBilling,
    roomClinic,
    roomHome,
    emptyCases,
    emptyResults,
    support,
  ];

  static const insurers = [insurerSaludPlena, insurerVidaSegura, insurerFamiliaSana];

  /// Las 29 ilustraciones.
  static const all = [...scenes, ...insurers, ...doctors, ...patients];

  /// Las 3 páginas de la bienvenida, en orden.
  static const onboarding = [onboardingRequest, onboardingConsult, onboardingFollowUp];

  // Infografías del equipo (WebP).
  static const processInfographic = 'assets/images/infografia_proceso.webp';
  static const servicesInfographic = 'assets/images/infografia_servicios.webp';

  /// Ilustración de la tarjeta de cada rol.
  static String forRole(UserRole role) => switch (role) {
        UserRole.patient => rolePatient,
        UserRole.admission => roleAdmission,
        UserRole.doctor => roleDoctor,
        UserRole.billing => roleBilling,
      };
}
