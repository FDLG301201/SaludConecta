import 'package:flutter/material.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/constants/app_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/page_body.dart';
import 'architecture_diagram.dart';

/// "Acerca de" (§6): las dos infografías del equipo con zoom, la arquitectura y el equipo.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Acerca de SaludConecta'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: 'Proceso'),
              Tab(text: 'Servicios'),
              Tab(text: 'Arquitectura'),
              Tab(text: 'Equipo'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const _Infographic(
              asset: AppIllustrations.processInfographic,
              caption: 'Proceso de telemedicina en 10 pasos y sus 5 actores',
            ),
            const _Infographic(
              asset: AppIllustrations.servicesInfographic,
              caption: 'Los 24 servicios de telemedicina en 3 grupos y los canales',
            ),
            PageBody(child: ListView(children: const [ArchitectureDiagram(), SizedBox(height: 24)])),
            const _TeamTab(),
          ],
        ),
      ),
    );
  }
}

/// Una infografía con zoom (`InteractiveViewer`).
class _Infographic extends StatelessWidget {
  const _Infographic({required this.asset, required this.caption});

  final String asset;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(caption, style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
        ),
        Text('Pellizca o usa dos dedos para hacer zoom', style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRect(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Align(
                alignment: Alignment.topCenter,
                child: Image.asset(asset, fit: BoxFit.contain, semanticLabel: caption),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TeamTab extends StatelessWidget {
  const _TeamTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          const SizedBox(height: 8),
          const Center(child: AppIllustration(AppIllustrations.logo, width: 96, height: 96)),
          const SizedBox(height: 12),
          Text(AppInfo.appName, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
          Text(
            AppInfo.slogan,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: AppColors.secondary, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          const Card(
            child: Column(
              children: [
                ListTile(leading: Icon(Icons.school_outlined), title: Text(AppInfo.course)),
                Divider(height: 1),
                ListTile(leading: Icon(Icons.assignment_outlined), title: Text(AppInfo.project)),
                Divider(height: 1),
                ListTile(leading: Icon(Icons.calendar_today_outlined), title: Text(AppInfo.term)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Integrantes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Card(
            child: Column(
              children: [
                for (final member in AppInfo.teamMembers)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: Text(member.characters.first, style: const TextStyle(color: AppColors.primary)),
                    ),
                    title: Text(member),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'App de demostración: los pacientes, aseguradoras y casos son ficticios.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
