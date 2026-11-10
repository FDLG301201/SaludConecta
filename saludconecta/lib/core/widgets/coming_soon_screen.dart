import 'package:flutter/material.dart';

import '../constants/app_illustrations.dart';
import 'empty_state.dart';

/// Pantalla provisional de lo que se construye en una etapa posterior del plan.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.stage, this.inShell = false});

  final String title;
  final int stage;

  /// Dentro de un shell no lleva barra propia (el shell ya tiene una).
  final bool inShell;

  @override
  Widget build(BuildContext context) {
    final body = EmptyState(
      illustration: AppIllustrations.emptyCases,
      title: title,
      message: 'Esta pantalla se construye en la etapa $stage del plan.',
    );
    if (inShell) return body;
    return Scaffold(appBar: AppBar(title: Text(title)), body: body);
  }
}
