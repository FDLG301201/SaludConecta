import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/models/people.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';
import '../shared/not_found_screen.dart';

/// Busca un caso del paciente en sesión y construye la pantalla con él.
/// Si el caso no existe o es de otro paciente, muestra "Caso no encontrado".
class PatientCaseBuilder extends StatelessWidget {
  const PatientCaseBuilder({super.key, required this.caseId, required this.builder});

  final String caseId;
  final Widget Function(BuildContext context, TelemedicineCase c, Patient patient) builder;

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<SessionProvider>().currentPatient;
    final c = context.watch<CaseProvider>().caseById(caseId);
    if (patient == null || c == null || c.patientId != patient.id) {
      return const NotFoundScreen(title: 'Caso no encontrado', message: 'El caso que buscas no existe.');
    }
    return builder(context, c, patient);
  }
}

/// Aviso cuando la acción no corresponde al paso del caso (p. ej., la encuesta ya se respondió).
class CaseNotice extends StatelessWidget {
  const CaseNotice({
    super.key,
    required this.screenTitle,
    required this.title,
    required this.message,
    this.illustration = AppIllustrations.emptyCases,
    this.action,
  });

  final String screenTitle;
  final String title;
  final String message;
  final String illustration;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),
      body: EmptyState(illustration: illustration, title: title, message: message, action: action),
    );
  }
}
