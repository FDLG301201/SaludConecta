import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Diagrama de arquitectura (§10.4) hecho con widgets: las capas de Flutter y las de SaludConecta.
class ArchitectureDiagram extends StatelessWidget {
  const ArchitectureDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        const flutter = _Section(
          title: 'Arquitectura de Flutter',
          subtitle: 'Cómo dibuja Flutter cada pantalla de la app',
          children: [
            _Group(
              title: 'Framework (Dart)',
              color: AppColors.primary,
              layers: [
                _Layer('Material · Cupertino', 'Componentes visuales: AppBar, Card, NavigationBar…'),
                _Layer('Widgets', 'Composición de la interfaz: todo es un widget'),
                _Layer('Rendering', 'Medición y posición de cada elemento (layout)'),
                _Layer('Animation · Painting · Gestures', 'Animaciones, CustomPainter y toques'),
                _Layer('Foundation', 'Utilidades base del framework'),
              ],
            ),
            _Group(
              title: 'Engine (C++)',
              color: AppColors.support,
              chips: ['Skia / Impeller', 'Dart runtime', 'Texto', 'Platform channels'],
            ),
            _Group(title: 'Embedder', color: AppColors.secondary, chips: ['Android', 'Web']),
          ],
        );
        const app = _Section(
          title: 'Arquitectura de SaludConecta',
          subtitle: 'Capas del código (lib/) y quién depende de quién',
          children: [
            _Group(
              title: 'Presentación · features/ y core/',
              color: AppColors.patient,
              layers: [
                _Layer(
                    'Pantallas por rol',
                    'patient_home_screen.dart · admission_inbox_screen.dart · '
                        'consultation_screen.dart · closure_screen.dart'),
                _Layer('Gráficas y diagramas', 'indicators_screen.dart · flow_diagram_painter.dart'),
                _Layer('Rutas y tema', 'app_router.dart · app_theme.dart'),
              ],
            ),
            _Arrow('lee y escucha (Provider)'),
            _Group(
              title: 'Estado · state/',
              color: AppColors.admission,
              layers: [
                _Layer('ChangeNotifier', 'case_provider.dart · session_provider.dart'),
              ],
            ),
            _Arrow('usa'),
            _Group(
              title: 'Dominio · domain/ (Dart puro)',
              color: AppColors.doctor,
              layers: [
                _Layer('Proceso de 10 pasos', 'process_step.dart · process_rules.dart · case_workflow.dart'),
                _Layer('Servicios', 'billing_calculator.dart · stats_calculator.dart · schedule_service.dart'),
              ],
            ),
            _Arrow('implementa las interfaces del dominio', up: true),
            _Group(
              title: 'Datos · data/',
              color: AppColors.billing,
              layers: [
                _Layer('Repositorios en memoria', 'catalog_repository.dart · case_repository.dart'),
                _Layer('Gateways simulados', 'insurance_gateway.dart · confirmation_gateway.dart'),
                _Layer('Datos semilla', 'seed_catalog.dart · seed_cases.dart'),
              ],
            ),
          ],
        );
        final note = Text(
          'La raíz de composición (app_dependencies.dart) crea los datos, los gateways, el estado y las rutas.',
          style: theme.textTheme.bodySmall,
        );
        if (wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: flutter), SizedBox(width: 12), Expanded(child: app)],
              ),
              note,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [flutter, const SizedBox(height: 12), app, const SizedBox(height: 8), note],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleLarge?.copyWith(color: AppColors.navy)),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Un bloque de color con su título y sus capas (de arriba abajo) o sus piezas (chips).
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.color, this.layers = const [], this.chips = const []});

  final String title;
  final Color color;
  final List<_Layer> layers;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final layer in layers)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(layer.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text(layer.detail, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          if (chips.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                    child: Text(chip, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Layer {
  const _Layer(this.name, this.detail);

  final String name;
  final String detail;
}

/// Flecha entre capas con su explicación.
class _Arrow extends StatelessWidget {
  const _Arrow(this.label, {this.up = false});

  final String label;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward, color: AppColors.navy),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
