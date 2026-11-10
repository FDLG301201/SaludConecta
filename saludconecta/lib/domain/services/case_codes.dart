import '../models/enums.dart';

/// Códigos y enlaces deterministas que se derivan del ID del caso ("TM-2026-0012").
class CaseCodes {
  const CaseCodes._();

  /// Los últimos 4 dígitos del ID: "TM-2026-0012" → "0012".
  static String sequenceOf(String caseId) {
    final digits = caseId.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.substring(digits.length - 4);
  }

  /// Autorización del seguro: AUT-yyyyMMdd-NNNN.
  static String authorization(String caseId, DateTime at) => 'AUT-${_compactDate(at)}-${sequenceOf(caseId)}';

  /// Número de reclamación al seguro: REC-NNNNN.
  static String claim(String caseId) => 'REC-${10000 + int.parse(sequenceOf(caseId))}';

  /// Código de verificación de la receta (va en el QR): RX-2026-0012-XXXX.
  static String prescription(String caseId) {
    var hash = 7;
    for (final unit in caseId.codeUnits) {
      hash = (hash * 31 + unit) & 0xFFFF;
    }
    final check = hash.toRadixString(16).toUpperCase().padLeft(4, '0');
    return 'RX-${caseId.substring(3)}-$check';
  }

  /// Enlace de demostración de la videollamada, con el formato de cada plataforma.
  static String meetingLink(String caseId, VideoPlatform platform) {
    final slug = caseId.toLowerCase();
    return switch (platform) {
      VideoPlatform.teams => 'https://teams.microsoft.com/l/meetup-join/$slug',
      VideoPlatform.zoom => 'https://zoom.us/j/${caseId.replaceAll(RegExp(r'[^0-9]'), '')}',
      VideoPlatform.meet => 'https://meet.google.com/${slug.replaceFirst('tm-', 'tmc-')}',
    };
  }

  static String _compactDate(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}
