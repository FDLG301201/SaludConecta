import 'package:flutter/material.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/constants/app_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_illustration.dart';
import '../shared/illustrations_gallery.dart';

/// Pantalla inicial provisional: muestra la galería de imágenes de la etapa 3.
/// En la etapa 4 se reemplaza por la bienvenida con `PageView`.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  const AppIllustration(AppIllustrations.logo, width: 96, height: 96),
                  const SizedBox(height: 12),
                  Text(AppInfo.appName, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(AppInfo.slogan, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.secondary)),
                  const SizedBox(height: 8),
                  const Text('Etapa 3: ilustraciones e infografías', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  const IllustrationsGallery(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
