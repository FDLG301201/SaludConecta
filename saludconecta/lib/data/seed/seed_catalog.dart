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
      id: SeedIds.generalConsult,
      name: 'Consulta médica general',
      group: ServiceGroup.clinical,
      description: 'Evaluación de síntomas comunes, diagnóstico y tratamiento inicial.',
      iconKey: 'stethoscope',
      requestable: true,
      specialty: Specialty.generalMedicine,
      fee: 1500,
    ),
    MedicalService(
      id: SeedIds.internalMedicine,
      name: 'Medicina interna',
      group: ServiceGroup.clinical,
      description: 'Atención de adultos con enfermedades crónicas o que afectan varios órganos.',
      iconKey: 'monitor_heart',
      requestable: true,
      specialty: Specialty.internalMedicine,
      fee: 2500,
    ),
    MedicalService(
      id: SeedIds.pediatrics,
      name: 'Pediatría de orientación',
      group: ServiceGroup.clinical,
      description: 'Orientación sobre la salud y los síntomas de niños y adolescentes.',
      iconKey: 'child_care',
      requestable: true,
      specialty: Specialty.pediatrics,
      fee: 2000,
    ),
    MedicalService(
      id: SeedIds.gynecology,
      name: 'Ginecología de seguimiento',
      group: ServiceGroup.clinical,
      description: 'Controles y seguimiento de la salud de la mujer.',
      iconKey: 'female',
      requestable: true,
      specialty: Specialty.gynecology,
      fee: 2500,
    ),
    MedicalService(
      id: SeedIds.cardiology,
      name: 'Cardiología de seguimiento',
      group: ServiceGroup.clinical,
      description: 'Control de la presión arterial, las palpitaciones y las enfermedades del corazón.',
      iconKey: 'favorite',
      requestable: true,
      specialty: Specialty.cardiology,
      fee: 2800,
    ),
    MedicalService(
      id: SeedIds.psychology,
      name: 'Psicología',
      group: ServiceGroup.clinical,
      description: 'Apoyo emocional y terapia breve por videollamada.',
      iconKey: 'psychology',
      requestable: true,
      specialty: Specialty.psychology,
      fee: 2200,
      reducedCoverage: true,
    ),
    MedicalService(
      id: SeedIds.nutrition,
      name: 'Nutrición',
      group: ServiceGroup.clinical,
      description: 'Planes de alimentación y control de peso.',
      iconKey: 'restaurant',
      requestable: true,
      specialty: Specialty.nutrition,
      fee: 1800,
      reducedCoverage: true,
    ),
    MedicalService(
      id: SeedIds.secondOpinion,
      name: 'Segunda opinión médica',
      group: ServiceGroup.clinical,
      description: 'Revisión de un diagnóstico o tratamiento por otro especialista.',
      iconKey: 'groups',
      requestable: true,
      specialty: Specialty.internalMedicine,
      fee: 3000,
      reducedCoverage: true,
    ),
    // ----- 2. Servicios asistenciales y de seguimiento -----
    MedicalService(
      id: SeedIds.chronicCare,
      name: 'Control de pacientes crónicos',
      group: ServiceGroup.careFollowUp,
      description: 'Seguimiento periódico de diabetes, hipertensión y otras condiciones.',
      iconKey: 'medication',
      requestable: true,
      specialty: Specialty.internalMedicine,
      fee: 1200,
    ),
    MedicalService(
      id: SeedIds.postConsultFollowUp,
      name: 'Seguimiento postconsulta',
      group: ServiceGroup.careFollowUp,
      description: 'Revisión de tu evolución después de una consulta.',
      iconKey: 'event_available',
      requestable: true,
      specialty: Specialty.generalMedicine,
      fee: 1000,
    ),
    MedicalService(
      id: SeedIds.postOpFollowUp,
      name: 'Seguimiento postoperatorio no crítico',
      group: ServiceGroup.careFollowUp,
      description: 'Control de la recuperación tras una cirugía sin complicaciones.',
      iconKey: 'healing',
      requestable: true,
      specialty: Specialty.generalMedicine,
      fee: 1200,
    ),
    MedicalService(
      id: SeedIds.resultsReview,
      name: 'Revisión de resultados de estudios',
      group: ServiceGroup.careFollowUp,
      description: 'Interpretación de análisis de laboratorio y de imágenes.',
      iconKey: 'fact_check',
      requestable: true,
      specialty: Specialty.generalMedicine,
      fee: 1000,
    ),
    MedicalService(
      id: SeedIds.medicalGuidance,
      name: 'Orientación médica',
      group: ServiceGroup.careFollowUp,
      description: 'Respuestas rápidas sobre síntomas, medicamentos y cuidados.',
      iconKey: 'support_agent',
      requestable: true,
      specialty: Specialty.generalMedicine,
      fee: 800,
    ),
    MedicalService(
      id: 'educacion-salud',
      name: 'Educación en salud',
      group: ServiceGroup.careFollowUp,
      description: 'Consejos de prevención y hábitos saludables en el Inicio de la app.',
      iconKey: 'school',
    ),
    MedicalService(
      id: 'recordatorios',
      name: 'Recordatorios y seguimiento al paciente',
      group: ServiceGroup.careFollowUp,
      description: 'Avisos de citas y llamadas de seguimiento del equipo de Admisión.',
      iconKey: 'notifications_active',
      relatedStep: ProcessStep.followUp,
    ),
    MedicalService(
      id: 'encuesta-satisfaccion',
      name: 'Encuesta de satisfacción',
      group: ServiceGroup.careFollowUp,
      description: 'Tu opinión sobre la atención, al final del proceso.',
      iconKey: 'thumb_up',
      relatedStep: ProcessStep.followUp,
    ),
    // ----- 3. Servicios derivados de la consulta -----
    MedicalService(
      id: 'receta-medica',
      name: 'Receta médica',
      group: ServiceGroup.derived,
      description: 'Receta digital con código QR de verificación.',
      iconKey: 'receipt_long',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'ordenes-laboratorio',
      name: 'Órdenes de laboratorio',
      group: ServiceGroup.derived,
      description: 'Análisis clínicos indicados por el médico.',
      iconKey: 'science',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'ordenes-imagenes',
      name: 'Órdenes de imágenes',
      group: ServiceGroup.derived,
      description: 'Radiografías, sonografías y otros estudios de imagen.',
      iconKey: 'image_search',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'referimientos',
      name: 'Referimientos',
      group: ServiceGroup.derived,
      description: 'Referencia presencial a un especialista cuando hace falta.',
      iconKey: 'alt_route',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'indicaciones-medicas',
      name: 'Indicaciones médicas',
      group: ServiceGroup.derived,
      description: 'Instrucciones de cuidado y tratamiento después de la consulta.',
      iconKey: 'assignment',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'proxima-cita',
      name: 'Programación de próxima cita',
      group: ServiceGroup.derived,
      description: 'Fecha sugerida para tu próxima consulta de seguimiento.',
      iconKey: 'calendar_month',
      relatedStep: ProcessStep.consultationResult,
    ),
    MedicalService(
      id: 'validacion-afiliacion',
      name: 'Validación de afiliación y cobertura',
      group: ServiceGroup.derived,
      description: 'Verificación de tu seguro antes de la cita.',
      iconKey: 'verified_user',
      relatedStep: ProcessStep.insuranceValidation,
    ),
    MedicalService(
      id: 'autorizacion-servicios',
      name: 'Autorización de servicios',
      group: ServiceGroup.derived,
      description: 'Número de autorización del seguro para tu atención.',
      iconKey: 'verified',
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
      id: SeedIds.jimenez,
      title: 'Dra.',
      fullName: 'Laura Jiménez',
      specialty: Specialty.internalMedicine,
      exequatur: '0613-09',
      avatarAsset: 'assets/illustrations/doctor_2.svg',
      schedule: _weekdays,
    ),
    Doctor(
      id: SeedIds.rosario,
      title: 'Dr.',
      fullName: 'Andrés Rosario',
      specialty: Specialty.pediatrics,
      exequatur: '0722-15',
      avatarAsset: 'assets/illustrations/doctor_3.svg',
      schedule: _weekdays,
    ),
    Doctor(
      id: SeedIds.nunez,
      title: 'Dra.',
      fullName: 'Patricia Núñez',
      specialty: Specialty.gynecology,
      exequatur: '0839-11',
      avatarAsset: 'assets/illustrations/doctor_4.svg',
      schedule: _weekdays,
    ),
    Doctor(
      id: SeedIds.santana,
      title: 'Dr.',
      fullName: 'Miguel Santana',
      specialty: Specialty.cardiology,
      exequatur: '0915-08',
      avatarAsset: 'assets/illustrations/doctor_5.svg',
      schedule: _weekdays,
    ),
    Doctor(
      id: SeedIds.herrera,
      title: 'Lic.',
      fullName: 'Sofía Herrera',
      specialty: Specialty.psychology,
      exequatur: '1024-17',
      avatarAsset: 'assets/illustrations/doctor_6.svg',
      schedule: _weekdays,
    ),
    Doctor(
      id: SeedIds.cruz,
      title: 'Lic.',
      fullName: 'Daniela Cruz',
      specialty: Specialty.nutrition,
      exequatur: '1136-19',
      avatarAsset: 'assets/illustrations/doctor_7.svg',
      schedule: _weekdays,
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
      id: SeedIds.maria,
      fullName: 'María Fernández',
      cedula: '001-1234567-1',
      birthDate: DateTime(1990, 3, 14),
      gender: Gender.female,
      phone: '809-555-0101',
      email: 'maria.fernandez@example.com',
      affiliation: const InsuranceAffiliation(
        insurerId: 'salud-plena',
        plan: 'Plus',
        affiliateNumber: 'SP-100245',
        active: true,
      ),
      avatarAsset: 'assets/illustrations/patient_1.svg',
    ),
    Patient(
      id: SeedIds.jose,
      fullName: 'José Martínez',
      cedula: '001-2345678-2',
      birthDate: DateTime(1978, 7, 22),
      gender: Gender.male,
      phone: '809-555-0102',
      email: 'jose.martinez@example.com',
      affiliation: const InsuranceAffiliation(
        insurerId: 'vida-segura',
        plan: 'Básico',
        affiliateNumber: 'VS-200318',
        active: true,
      ),
      avatarAsset: 'assets/illustrations/patient_2.svg',
    ),
    Patient(
      id: SeedIds.carmen,
      fullName: 'Carmen Reyes',
      cedula: '001-3456789-3',
      birthDate: DateTime(1965, 11, 2),
      gender: Gender.female,
      phone: '809-555-0103',
      email: 'carmen.reyes@example.com',
      affiliation: const InsuranceAffiliation(
        insurerId: 'familia-sana',
        plan: 'Premium',
        affiliateNumber: 'FS-300472',
        active: true,
      ),
      avatarAsset: 'assets/illustrations/patient_3.svg',
    ),
    Patient(
      id: SeedIds.pedro, fullName: 'Pedro Almonte', cedula: '001-4567890-4', birthDate: DateTime(1983, 5, 30),
      gender: Gender.male, phone: '809-555-0104', email: 'pedro.almonte@example.com',
      // Afiliación INACTIVA: el seguro rechaza su solicitud (camino alterno de la demo).
      affiliation: const InsuranceAffiliation(
        insurerId: 'salud-plena',
        plan: 'Básico',
        affiliateNumber: 'SP-100519',
        active: false,
      ),
      avatarAsset: 'assets/illustrations/patient_4.svg',
    ),
    Patient(
      id: SeedIds.luisa,
      fullName: 'Luisa Gómez',
      cedula: '001-5678901-5',
      birthDate: DateTime(1995, 9, 18),
      gender: Gender.female,
      phone: '809-555-0105',
      email: 'luisa.gomez@example.com',
      affiliation: const InsuranceAffiliation(
        insurerId: 'familia-sana',
        plan: 'Plus',
        affiliateNumber: 'FS-300651',
        active: true,
      ),
      avatarAsset: 'assets/illustrations/patient_5.svg',
    ),
    Patient(
      id: SeedIds.ramon,
      fullName: 'Ramón Ortiz',
      cedula: '001-6789012-6',
      birthDate: DateTime(1958, 1, 25),
      gender: Gender.male,
      phone: '809-555-0106',
      email: 'ramon.ortiz@example.com',
      affiliation: const InsuranceAffiliation(
        insurerId: 'vida-segura',
        plan: 'Premium',
        affiliateNumber: 'VS-200733',
        active: true,
      ),
      avatarAsset: 'assets/illustrations/patient_6.svg',
    ),
  ];

  /// 40 pacientes de fondo con nombres generados; solo aparecen en los datos históricos.
  static List<Patient> backgroundPatients() {
    const femaleNames = [
      'Rosa',
      'Yolanda',
      'Gabriela',
      'Altagracia',
      'Mercedes',
      'Paola',
      'Esther',
      'Juana',
      'Teresa',
      'Milagros',
    ];
    const maleNames = [
      'Juan',
      'Rafael',
      'Francisco',
      'Héctor',
      'Manuel',
      'Julio',
      'Félix',
      'Domingo',
      'Ernesto',
      'Wilson',
    ];
    const lastNames = [
      'Rodríguez',
      'Pérez',
      'Santos',
      'Guzmán',
      'Vásquez',
      'Batista',
      'Peralta',
      'Medina',
      'Cabrera',
      'Mejía',
      'Sánchez',
      'Encarnación',
      'Polanco',
      'Familia',
      'Tavárez',
      'Ureña',
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
