import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/utils/formatters.dart';

void main() {
  setUpAll(() async {
    // En la app esto se hace en main(); las pruebas lo hacen aquí.
    await initializeDateFormatting('es');
  });

  test('montos en pesos dominicanos', () {
    expect(Formatters.money(1500), r'RD$1,500.00');
    expect(Formatters.money(812.5), r'RD$812.50');
  });

  test('fecha y hora en español', () {
    final value = DateTime(2026, 11, 12, 10, 30);
    expect(Formatters.dateTime(value), 'jueves, 12 de noviembre · 10:30 a. m.');
    expect(Formatters.time(DateTime(2026, 11, 12, 15)), '3:00 p. m.');
    expect(Formatters.shortDate(value), '12 nov 2026');
    expect(Formatters.monthLabel(value), 'Nov');
  });

  test('duraciones cortas', () {
    expect(Formatters.duration(const Duration(minutes: 45)), '45 min');
    expect(Formatters.duration(const Duration(hours: 3)), '3 h');
    expect(Formatters.duration(const Duration(hours: 3, minutes: 20)), '3 h 20 min');
    expect(Formatters.duration(const Duration(days: 2, hours: 4)), '2 d 4 h');
  });
}
