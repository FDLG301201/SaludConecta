import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/core/router/route_guard.dart';
import 'package:saludconecta/domain/models/enums.dart';

void main() {
  test('sin sesión solo se ven la bienvenida y el ingreso', () {
    expect(RouteGuard.redirect('/bienvenida', null), isNull);
    expect(RouteGuard.redirect('/ingreso', null), isNull);
    expect(RouteGuard.redirect('/ingreso/personal/medico', null), isNull);
    expect(RouteGuard.redirect('/paciente', null), '/ingreso');
    expect(RouteGuard.redirect('/caso/TM-2026-0001', null), '/ingreso');
    expect(RouteGuard.redirect('/proceso', null), '/ingreso');
  });

  test('con sesión, el ingreso lleva al inicio del rol', () {
    expect(RouteGuard.redirect('/ingreso', UserRole.billing), '/facturacion');
    expect(RouteGuard.redirect('/ingreso/paciente', UserRole.patient), '/paciente');
  });

  test('las secciones de otro rol llevan al inicio del rol actual', () {
    expect(RouteGuard.redirect('/admision', UserRole.patient), '/paciente');
    expect(RouteGuard.redirect('/facturacion/reclamaciones', UserRole.patient), '/paciente');
    expect(RouteGuard.redirect('/paciente', UserRole.doctor), '/medico');
    expect(RouteGuard.redirect('/paciente/citas', UserRole.patient), isNull);
    expect(RouteGuard.redirect('/paciente/solicitar', UserRole.patient), isNull);
    expect(RouteGuard.redirect('/medico/indicadores', UserRole.doctor), isNull);
  });

  test('las acciones de otro rol sobre un caso llevan al detalle del caso', () {
    expect(RouteGuard.redirect('/caso/TM-2026-0001/procesar', UserRole.patient), '/caso/TM-2026-0001');
    expect(RouteGuard.redirect('/caso/TM-2026-0001/cierre', UserRole.doctor), '/caso/TM-2026-0001');
    expect(RouteGuard.redirect('/caso/TM-2026-0001/consentimiento', UserRole.patient), isNull);
    expect(RouteGuard.redirect('/caso/TM-2026-0001/consulta', UserRole.doctor), isNull);
    expect(RouteGuard.redirect('/caso/TM-2026-0001/diagrama', UserRole.billing), isNull);
    expect(RouteGuard.redirect('/caso/TM-2026-0001', UserRole.admission), isNull);
    expect(RouteGuard.redirect('/proceso', UserRole.admission), isNull);
  });

  test('rutas armadas con datos', () {
    expect(CaseAction.fromSegment('emitir-resultados'), CaseAction.issueResults);
    expect(CaseAction.fromSegment('otra'), isNull);
    expect(AppRoutes.caseAction('TM-1', CaseAction.waitingRoom), '/caso/TM-1/sala-espera');
    expect(AppRoutes.staffLogin(UserRole.billing), '/ingreso/personal/facturacion');
    expect(AppRoutes.requestAppointment(serviceId: 'nutricion'), '/paciente/solicitar?servicio=nutricion');
    expect(AppRoutes.home(UserRole.admission), '/admision');
  });
}
