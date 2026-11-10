import 'package:flutter/material.dart';

import 'diagram_views.dart';

/// "Diagramas del proceso" (`/proceso`): pestañas "Flujo" (diagrama de flujo) y "Por actor" (carriles).
class ProcessDiagramsScreen extends StatelessWidget {
  const ProcessDiagramsScreen({super.key});

  static const _hint = 'Toca un paso para ver su detalle. Pellizca para acercar o alejar.';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diagramas del proceso'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.account_tree_outlined), text: 'Flujo'),
              Tab(icon: Icon(Icons.view_stream_outlined), text: 'Por actor'),
            ],
          ),
        ),
        body: TabBarView(
          // Sin deslizar entre pestañas: el gesto se usa para mover el diagrama.
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Column(
              children: [
                DiagramLegend(entries: actorLegend, hint: _hint),
                const Divider(height: 1),
                const Expanded(child: ClipRect(child: FlowDiagramView())),
              ],
            ),
            Column(
              children: [
                DiagramLegend(entries: actorLegend, hint: 'Desliza a los lados para recorrer los 10 pasos.'),
                const Divider(height: 1),
                const Expanded(child: ClipRect(child: SwimlaneView())),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
