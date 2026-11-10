import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/constants/app_info.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_illustration.dart';

/// Bienvenida (§6): 3 páginas con ilustración, indicador de puntos y los botones "Omitir" y "Comenzar".
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _pages = [
    (
      AppIllustrations.onboardingRequest,
      'Solicita tu cita por el canal que prefieras',
      'Celular, correo, WhatsApp, portal web o teléfono: tú eliges cómo pedir tu consulta.',
    ),
    (
      AppIllustrations.onboardingConsult,
      'Consulta con tu médico desde casa',
      'Te atiende un médico general o especialista por MS Teams, Zoom o Google Meet.',
    ),
    (
      AppIllustrations.onboardingFollowUp,
      'Recibe tu receta y seguimiento',
      'Tu receta con código QR, tus órdenes y el seguimiento de tu atención, en la app.',
    ),
  ];

  final _controller = PageController();
  var _page = 0;

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => context.go(AppRoutes.login);

  void _next() => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      const AppIllustration(AppIllustrations.logo, width: 40, height: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppInfo.appName, style: theme.textTheme.titleLarge),
                            Text(
                              AppInfo.slogan,
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ),
                      if (!_isLast) TextButton(onPressed: _finish, child: const Text('Omitir')),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (page) => setState(() => _page = page),
                    children: [
                      for (final (asset, title, body) in _pages)
                        _OnboardingPage(asset: asset, title: title, body: body),
                    ],
                  ),
                ),
                _Dots(count: _pages.length, current: _page),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLast ? _finish : _next,
                      child: Text(_isLast ? 'Comenzar' : 'Siguiente'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.asset, required this.title, required this.body});

  final String asset;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(child: AppIllustration(asset, semanticLabel: title)),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Indicador de puntos: el de la página actual es más ancho.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? AppColors.primary : AppColors.pending.withOpacity(0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
