import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Un consejo de "Educación en salud" (servicio incluido en la app).
class HealthTip {
  const HealthTip(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

/// Los 5 consejos del carrusel del Inicio.
const healthTips = [
  HealthTip(
    Icons.water_drop_outlined,
    'Toma agua durante el día',
    'Unos 8 vasos al día ayudan a tu energía, a tu piel y a tus riñones.',
  ),
  HealthTip(
    Icons.directions_walk,
    'Muévete 30 minutos al día',
    'Caminar a paso rápido cinco días a la semana cuida tu corazón.',
  ),
  HealthTip(
    Icons.bedtime_outlined,
    'Duerme de 7 a 8 horas',
    'El buen descanso mejora tu ánimo, tu memoria y tus defensas.',
  ),
  HealthTip(
    Icons.restaurant_outlined,
    'Llena medio plato de vegetales',
    'Las frutas y los vegetales de colores aportan fibra y vitaminas.',
  ),
  HealthTip(
    Icons.medication_outlined,
    'Toma tus medicamentos a tiempo',
    'Usa alarmas y no suspendas un tratamiento sin consultar a tu médico.',
  ),
];

/// Carrusel "Educación en salud": los consejos en un `PageView` con indicador de puntos.
class HealthTipsCarousel extends StatefulWidget {
  const HealthTipsCarousel({super.key});

  @override
  State<HealthTipsCarousel> createState() => _HealthTipsCarouselState();
}

class _HealthTipsCarouselState extends State<HealthTipsCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _controller,
            itemCount: healthTips.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final tip = healthTips[index];
              return Card(
                color: AppColors.secondary.withOpacity(0.08),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.secondary,
                        child: Icon(tip.icon, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tip.title,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tip.body,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < healthTips.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.secondary : theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
