import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/gateways/confirmation_gateway.dart';
import 'package:saludconecta/data/gateways/insurance_gateway.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/services/case_codes.dart';

void main() {
  final catalog = SeedCatalog.repository();
  final maria = catalog.patientById(SeedIds.maria);
  final pedro = catalog.patientById(SeedIds.pedro);
  final generalConsult = catalog.serviceById(SeedIds.generalConsult);
  final nutrition = catalog.serviceById(SeedIds.nutrition);

  test('códigos que se derivan del ID del caso', () {
    expect(CaseCodes.sequenceOf('TM-2026-0012'), '0012');
    expect(CaseCodes.authorization('TM-2026-0012', DateTime(2026, 11, 9)), 'AUT-20261109-0012');
    expect(CaseCodes.claim('TM-2026-0012'), 'REC-10012');
    expect(CaseCodes.prescription('TM-2026-0012'), matches(RegExp(r'^RX-2026-0012-[0-9A-F]{4}$')));
    expect(CaseCodes.prescription('TM-2026-0012'), CaseCodes.prescription('TM-2026-0012'));
  });

  test('enlace de demostración con el formato de cada plataforma', () {
    expect(CaseCodes.meetingLink('TM-2026-0012', VideoPlatform.meet), 'https://meet.google.com/tmc-2026-0012');
    expect(CaseCodes.meetingLink('TM-2026-0012', VideoPlatform.zoom), 'https://zoom.us/j/20260012');
    expect(
      CaseCodes.meetingLink('TM-2026-0012', VideoPlatform.teams),
      'https://teams.microsoft.com/l/meetup-join/tm-2026-0012',
    );
  });

  group('seguro simulado', () {
    final gateway = SimulatedInsuranceGateway(
      catalog: catalog,
      clock: () => DateTime(2026, 11, 9, 10),
      delay: Duration.zero,
    );

    test('aprueba con la cobertura del plan y genera la autorización', () async {
      final result = await gateway.validate(patient: maria, service: generalConsult, caseId: 'TM-2026-0100');
      expect(result.approved, isTrue);
      expect(result.coveragePercent, 80);
      expect(result.authorizationNumber, 'AUT-20261109-0100');
      expect(result.at, DateTime(2026, 11, 9, 10));
    });

    test('resta 20 puntos a los servicios de cobertura reducida', () async {
      final result = await gateway.validate(patient: maria, service: nutrition, caseId: 'TM-2026-0100');
      expect(result.coveragePercent, 60);
    });

    test('rechaza una afiliación inactiva', () async {
      final result = await gateway.validate(patient: pedro, service: generalConsult, caseId: 'TM-2026-0101');
      expect(result.approved, isFalse);
      expect(result.message, 'Afiliación inactiva');
      expect(result.authorizationNumber, isNull);
    });

    test('la reclamación devuelve su número', () async {
      expect(await gateway.submitClaim(caseId: 'TM-2026-0100'), 'REC-10100');
    });
  });

  test('la confirmación devuelve el enlace de la plataforma', () async {
    final gateway = SimulatedConfirmationGateway(delay: Duration.zero);
    final link = await gateway.send(caseId: 'TM-2026-0100', platform: VideoPlatform.meet, via: RequestChannel.whatsapp);
    expect(link, 'https://meet.google.com/tmc-2026-0100');
  });
}
