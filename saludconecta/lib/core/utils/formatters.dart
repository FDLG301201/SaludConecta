import 'package:intl/intl.dart';

/// Formatos en español. Requieren `initializeDateFormatting('es')`, que se hace en `main`.
class Formatters {
  const Formatters._();

  static final _money = NumberFormat.currency(locale: 'en_US', symbol: r'RD$', decimalDigits: 2);

  /// 1500 → "RD$1,500.00" (formato usado en República Dominicana).
  static String money(num amount) => _money.format(amount);

  /// "jueves, 12 de noviembre".
  static String date(DateTime value) => _clean(DateFormat("EEEE, d 'de' MMMM", 'es').format(value));

  /// "12 nov 2026".
  static String shortDate(DateTime value) => _clean(DateFormat('d MMM y', 'es').format(value));

  /// "10:30 a. m.".
  static String time(DateTime value) => _clean(DateFormat('h:mm a', 'es').format(value));

  /// "jueves, 12 de noviembre · 10:30 a. m.".
  static String dateTime(DateTime value) => '${date(value)} · ${time(value)}';

  /// "Nov": etiqueta corta para los ejes de las gráficas.
  static String monthLabel(DateTime value) {
    final text = _clean(DateFormat('MMM', 'es').format(value));
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  /// "45 min", "3 h 20 min" o "2 d 4 h".
  static String duration(Duration value) {
    if (value.inMinutes < 60) return '${value.inMinutes} min';
    if (value.inHours < 24) {
      final minutes = value.inMinutes % 60;
      return minutes == 0 ? '${value.inHours} h' : '${value.inHours} h $minutes min';
    }
    final hours = value.inHours % 24;
    return hours == 0 ? '${value.inDays} d' : '${value.inDays} d $hours h';
  }

  /// `intl` pone espacios no separables en "a. m."; se cambian por espacios normales.
  static String _clean(String text) => text.replaceAll(' ', ' ').replaceAll(' ', ' ');
}
