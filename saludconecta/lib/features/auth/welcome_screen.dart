import 'package:flutter/material.dart';

import '../../core/constants/app_info.dart';
import '../../core/theme/app_colors.dart';

/// Pantalla inicial provisional. En la etapa 4 se reemplaza por la bienvenida con `PageView`.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.medical_services_outlined, size: 72, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(AppInfo.appName, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(AppInfo.slogan, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.secondary)),
              const SizedBox(height: 24),
              const Text('Etapa 1: andamiaje listo', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
