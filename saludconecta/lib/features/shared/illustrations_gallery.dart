import 'package:flutter/material.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/widgets/app_illustration.dart';

/// Galería con todas las imágenes de la app: las ilustraciones SVG propias y las infografías del equipo.
class IllustrationsGallery extends StatelessWidget {
  const IllustrationsGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ilustraciones propias (${AppIllustrations.all.length})', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final asset in AppIllustrations.all) _IllustrationTile(asset: asset),
          ],
        ),
        const SizedBox(height: 24),
        Text('Infografías del equipo', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final image in const [AppIllustrations.processInfographic, AppIllustrations.servicesInfographic])
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(image, height: 180, fit: BoxFit.contain),
              ),
          ],
        ),
      ],
    );
  }
}

class _IllustrationTile extends StatelessWidget {
  const _IllustrationTile({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final name = asset.split('/').last.replaceAll('.svg', '');
    return SizedBox(
      width: 132,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              AppIllustration(asset, width: 112, height: 84, semanticLabel: name),
              const SizedBox(height: 6),
              Text(
                name,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
