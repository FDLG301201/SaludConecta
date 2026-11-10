import '../../domain/models/enums.dart';
import '../../domain/services/case_codes.dart';

/// Envío de la confirmación al paciente (paso 5). Es simulado: no se envía nada real.
abstract class ConfirmationGateway {
  /// "Envía" el enlace por [via] (WhatsApp o correo) y devuelve el enlace generado.
  Future<String> send({required String caseId, required VideoPlatform platform, required RequestChannel via});
}

class SimulatedConfirmationGateway implements ConfirmationGateway {
  SimulatedConfirmationGateway({this.delay = const Duration(seconds: 1)});

  final Duration delay;

  @override
  Future<String> send({required String caseId, required VideoPlatform platform, required RequestChannel via}) async {
    await Future<void>.delayed(delay);
    return CaseCodes.meetingLink(caseId, platform);
  }
}
