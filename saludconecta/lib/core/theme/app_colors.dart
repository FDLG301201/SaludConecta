import 'package:flutter/material.dart';

/// Paleta de SaludConecta (§11 del spec).
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF1565C0);
  static const secondary = Color(0xFF00897B);
  static const background = Color(0xFFF4F8FB);

  /// Azul marino de los encabezados.
  static const navy = Color(0xFF0D3B66);

  // Un color por actor del proceso (infografía 1).
  static const patient = Color(0xFF43A047);
  static const admission = Color(0xFF1E88E5);
  static const doctor = Color(0xFF00897B);
  static const support = Color(0xFF7B1FA2);
  static const billing = Color(0xFF283593);

  // Estados de los pasos.
  static const done = Color(0xFF2E7D32);
  static const current = Color(0xFFF9A825);
  static const pending = Color(0xFF9E9E9E);
  static const danger = Color(0xFFC62828);
}
