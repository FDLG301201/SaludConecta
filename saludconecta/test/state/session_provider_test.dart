import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/state/session_provider.dart';

import '../support/fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 9, 10);
  late SessionProvider session;
  late int notifications;

  setUp(() {
    session = SessionProvider(clock: () => now);
    notifications = 0;
    session.addListener(() => notifications++);
  });

  test('empieza sin sesión', () {
    expect(session.isLoggedIn, isFalse);
    expect(session.role, isNull);
    expect(session.displayName, '');
  });

  test('la paciente ingresa y sus avisos anteriores cuentan como leídos', () {
    session.loginPatient(maria);
    expect(session.role, UserRole.patient);
    expect(session.currentPatient, same(maria));
    expect(session.displayName, 'María Fernández');
    expect(session.notificationsSeenAt(maria.id), now);
    expect(notifications, 1);
  });

  test('cambiar de rol reemplaza la sesión anterior', () {
    session.loginPatient(maria);
    session.loginDoctor(mendez);
    expect(session.role, UserRole.doctor);
    expect(session.currentPatient, isNull);
    expect(session.currentDoctor, same(mendez));
    expect(session.displayName, 'Dr. Carlos Méndez');
    session.loginStaff(catalog.staffFor(Actor.billing));
    expect(session.role, UserRole.billing);
    expect(session.displayName, 'Roberto Díaz');
  });

  test('Soporte TI no inicia sesión en la app', () {
    expect(() => session.loginStaff(catalog.staffFor(Actor.support)), throwsArgumentError);
  });

  test('los avisos leídos se conservan al cambiar de rol; cerrar sesión limpia el rol', () {
    var clock = now;
    session = SessionProvider(clock: () => clock);
    session.loginPatient(maria);
    clock = now.add(const Duration(hours: 2));
    session.markNotificationsSeen();
    session.loginDoctor(mendez);
    session.loginPatient(maria);
    expect(session.notificationsSeenAt(maria.id), now.add(const Duration(hours: 2)));
    session.logout();
    expect(session.isLoggedIn, isFalse);
  });
}
