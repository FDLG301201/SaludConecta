import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/router/app_routes.dart';

void main() {
  test('el asistente recibe el servicio y la fecha preferida por la URL', () {
    expect(AppRoutes.requestAppointment(), '/paciente/solicitar');
    expect(AppRoutes.requestAppointment(serviceId: 'nutricion'), '/paciente/solicitar?servicio=nutricion');
    expect(
      AppRoutes.requestAppointment(serviceId: 'seguimiento-postconsulta', preferredDate: DateTime(2026, 12, 9)),
      '/paciente/solicitar?servicio=seguimiento-postconsulta&fecha=2026-12-09',
    );
    expect(AppRoutes.isoDate(DateTime(2027, 1, 5)), '2027-01-05');
    expect(DateTime.tryParse(AppRoutes.isoDate(DateTime(2027, 1, 5))), DateTime(2027, 1, 5));
  });
}
