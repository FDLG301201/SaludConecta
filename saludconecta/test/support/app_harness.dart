import 'package:flutter/widgets.dart';
import 'package:saludconecta/app.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/models/telemedicine_case.dart';
import 'package:saludconecta/domain/process/process_step.dart';

/// Hora fija de las pruebas de widgets: lunes 9 de noviembre de 2026, 10:00.
final testNow = DateTime(2026, 11, 9, 10);

/// Dependencias de la app con la hora fija y sin pausas en los gateways.
AppDependencies testDependencies({String initialLocation = AppRoutes.welcome}) => AppDependencies.create(
      clock: () => testNow,
      insuranceDelay: Duration.zero,
      confirmationDelay: Duration.zero,
      initialLocation: initialLocation,
    );

/// La app completa, lista para `tester.pumpWidget`.
Widget appWith(AppDependencies dependencies) => dependencies.provide(SaludConectaApp(router: dependencies.router));

/// Atajo: la app desde la bienvenida (u otra ruta inicial).
Widget buildTestApp({String initialLocation = AppRoutes.welcome}) =>
    appWith(testDependencies(initialLocation: initialLocation));

/// Dependencias con el paciente [patientId] en sesión; la app abre en su Inicio.
AppDependencies patientDependencies(String patientId) {
  final deps = testDependencies(initialLocation: AppRoutes.patientHome);
  deps.session.loginPatient(deps.catalog.patientById(patientId));
  return deps;
}

/// Dependencias con el personal de [role] en sesión (para el médico, el de [doctorId]); la app abre en su inicio.
AppDependencies staffDependencies(UserRole role, {String? doctorId}) {
  final deps = testDependencies(initialLocation: AppRoutes.home(role));
  switch (role) {
    case UserRole.admission:
      deps.session.loginStaff(deps.catalog.staffFor(Actor.admission));
    case UserRole.billing:
      deps.session.loginStaff(deps.catalog.staffFor(Actor.billing));
    case UserRole.doctor:
      deps.session.loginDoctor(deps.catalog.doctorById(doctorId!));
    case UserRole.patient:
      throw ArgumentError('Para el paciente se usa patientDependencies.');
  }
  return deps;
}

/// El caso abierto de [patientId] con [step] pendiente (los casos en vivo L1–L10 de la semilla).
TelemedicineCase openCaseOf(AppDependencies deps, String patientId, ProcessStep step) =>
    deps.cases.casesOfPatient(patientId).firstWhere((c) => c.isOpen && c.currentStep == step);
