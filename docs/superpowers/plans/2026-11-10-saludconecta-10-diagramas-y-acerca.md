# SaludConecta · Etapa 10: Diagramas y Acerca de

> Hoja de ruta: [00-hoja-de-ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md) · Spec: §10 (Diagramas) y §6 (Acerca de).

**Objetivo:** reemplazar las últimas 3 pantallas provisionales (`/proceso`, `/caso/:id/diagrama` y `/acerca`) por:

- los diagramas dibujados con `CustomPainter`;
- el diagrama de arquitectura;
- Acerca de, con las infografías del equipo.

Con esta etapa desaparece `ComingSoonScreen`.

## Archivos

| Archivo | Qué hace |
|---|---|
| `lib/features/diagrams/flow_layout.dart` | `FlowLayout` (Dart puro): posiciones de cada nodo y de cada flecha (`FlowNode`, `FlowEdge`) y `stepAt(punto)` para el toque. Contiene el inicio, los 10 pasos, el rombo "¿El seguro aprueba?" tras el paso 3, la rama "No" con "Privado" (vuelve al paso 4) y "Cancelar" ("Solicitud cancelada"), y el fin |
| `lib/features/diagrams/diagram_paint.dart` | Texto con `TextPainter`, flechas con punta, trazos y rectángulos punteados |
| `lib/features/diagrams/flow_diagram_painter.dart` | `FlowDiagramPainter`: color del actor por paso. En modo caso (`CaseProgress`, `StepProgress`): completados en verde con ✓, el actual en ámbar con halo pulsante y los pendientes en gris. Si el caso terminó, se resalta "Paciente atendido" o "Solicitud cancelada" |
| `lib/features/diagrams/swimlane_painter.dart` | `SwimlaneLayout` y `SwimlanePainter`: 5 carriles (incluido Soporte TI) × 10 columnas, flechas ortogonales y nodos punteados del paciente (pasos 7 y 10) y de Soporte TI (5–7) |
| `lib/features/diagrams/diagram_views.dart` | `FlowDiagramView` (zoom; arranca ajustado al ancho; toque → hoja del paso; `AnimationController` del pulso), `SwimlaneView` (ajustado al alto, se recorre a lo ancho), `showStepSheet` (actor, quién lo completa, descripción y servicios relacionados) y `DiagramLegend` |
| `lib/features/diagrams/process_diagrams_screen.dart` | `/proceso`: pestañas "Flujo" y "Por actor" |
| `lib/features/diagrams/case_diagram_screen.dart` | `/caso/:id/diagrama`: modo caso. `progressOf(caso)` calcula el estado de cada paso |
| `lib/features/about/architecture_diagram.dart` | Arquitectura de Flutter (Framework, Engine y Embedder) y de SaludConecta (Presentación → Estado → Dominio ← Datos, con archivos reales) |
| `lib/features/about/about_screen.dart` | Pestañas Proceso y Servicios (infografías con `InteractiveViewer`), Arquitectura y Equipo (logo, lema, curso e integrantes de `AppInfo`) |
| `lib/core/router/app_router.dart` | Las 3 rutas apuntan a las pantallas nuevas |
| `lib/core/widgets/coming_soon_screen.dart` | Se elimina, junto con su prueba |

## Pruebas

**`test/features/diagrams/flow_layout_test.dart`:**

1. Nodos del flujo y etiquetas Sí, No, Privado y Cancelar.
2. El rombo va entre los pasos 3 y 4, los pasos bajan en orden y todo cabe en el lienzo.
3. El toque encuentra el paso, y fuera de los pasos no encuentra ninguno.
4. Cada paso va en el carril de su actor.

**`test/features/diagrams/diagrams_screens_test.dart`:**

5. Tocar el paso 2 abre su hoja ("Lo completa: Admisión"), y "Por actor" muestra los carriles. Las coordenadas se pasan del lienzo a la pantalla con `localToGlobal`, que ya incluye el zoom.
6. Modo caso con el caso de Carmen: los pasos 1–2 aparecen completados, el 3 como actual y el 4 como pendiente. El pulso no termina nunca, así que la prueba usa `pump(Duration)`.
7. Acerca de: la pestaña Arquitectura muestra "Rendering" y la pestaña Equipo muestra el lema y los integrantes.

## Verificación

- `dart format`: sin cambios.
- `flutter analyze`: sin problemas.
- `flutter test`: 199 pruebas en verde.
- Android: en las capturas se revisaron:
  - el diagrama de flujo;
  - los carriles;
  - el diagrama del caso de Luisa (paso 4 actual);
  - Acerca de (infografía y arquitectura).

## Notas

- `StepState` choca con el `StepState` del `Stepper` de Material, por eso el enum se llama `StepProgress`.
- En `TabBarView` se desactiva el deslizamiento entre pestañas, para que ese gesto mueva el diagrama.
