# SaludConecta · Etapa 9: Indicadores

> Hoja de ruta: [00-hoja-de-ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md) · Spec: §7 (Gráficas) y §8 (`ChartCard`, `KpiTile`).

**Objetivo:** reemplazar las 3 pestañas "Indicadores" provisionales del personal por una pantalla compartida con 4 pestañas de gráficas (`fl_chart` 0.69). Agregar "Mi resumen" al perfil del paciente. Todo se calcula con `StatsCalculator` (etapa 2) sobre los casos del `CaseProvider`, así que las gráficas cambian en cuanto avanza un caso.

## Archivos

| Archivo | Qué hace |
|---|---|
| `lib/core/widgets/chart_card.dart` | `ChartCard`: título, subtítulo, gráfica de alto fijo (o libre) y leyenda (`LegendEntry`) |
| `lib/core/widgets/kpi_tile.dart` | `KpiTile` (ícono, valor y etiqueta) y `KpiGrid` (2 columnas en teléfono, 4 en pantallas anchas) |
| `lib/features/indicators/charts.dart` | Gráficas reutilizables: `DonutChart`, `SimpleBarChart`, `StackedBarChart`, `MultiLineChart`, `HorizontalBars` (embudo y aseguradoras), `ChartPalette`, `compactNumber`, `specialtyBars` |
| `lib/features/indicators/indicators_screen.dart` | `IndicatorsScreen` con `TabBar`: Operación, Clínico, Financiero y Satisfacción. `IndicatorsTab.initialFor(role)` elige la pestaña inicial |
| `lib/features/patient/profile/my_summary.dart` | "Mi resumen": dona "Cubierto por el seguro vs. pagado por mí" y barras "Mis consultas por especialidad" |
| `lib/features/patient/profile/profile_screen.dart` | Agrega "Mi resumen" entre los datos personales y los enlaces |
| `lib/core/router/app_router.dart` | Las 3 pestañas Indicadores apuntan a `IndicatorsScreen` |

## Contenido de las pestañas

- **Operación:**
  - KPIs: solicitudes del mes, casos en proceso, días de la solicitud a la consulta y % de rechazo del seguro;
  - dona por canal;
  - líneas de solicitudes vs. consultas por mes;
  - embudo de los 10 pasos (barras horizontales con el color del actor);
  - horas promedio por etapa (barras P2–P10).
- **Clínico:**
  - KPIs: consultas y recetas;
  - barras por especialidad;
  - dona por plataforma;
  - barras de resultados emitidos.
- **Financiero:**
  - KPIs: a cargo de los seguros y copagos;
  - barras apiladas por mes (seguro + copago);
  - dona de reclamaciones por estado;
  - barras por aseguradora.
- **Satisfacción:**
  - KPIs: calificación promedio, NPS y encuestas;
  - distribución 1–5★;
  - promedio por mes (línea, con huecos en los meses sin encuestas).

Las porciones y barras en cero no se dibujan. Si una gráfica no tiene datos, muestra "Sin datos todavía".

En pantallas de 900 px o más, las gráficas van en 2 columnas.

## Pruebas (`test/features/indicators/indicators_test.dart`)

1. `IndicatorsTab.initialFor`: Admisión → Operación, Médico → Clínico, Facturación → Financiero.
2. Admisión ve los KPIs de Operación, la dona y las líneas.
3. El médico abre en Clínico y pasa a Satisfacción (NPS y distribución).
4. Facturación abre en Financiero con las barras apiladas y la dona de reclamaciones.
5. El perfil de María muestra "Mi resumen" con lo cubierto y lo pagado.

## Verificación

- `dart format -l 120 lib test`: sin cambios.
- `flutter analyze`: sin problemas.
- `flutter test`: 193 pruebas en verde.
- Android (Pixel 3a): Admisión → Indicadores, las 4 pestañas revisadas en capturas.

## Nota de diseño

`fl_chart` 0.69 no tiene barras horizontales. El embudo y la facturación por aseguradora se dibujan con widgets (`HorizontalBars`), que además leen bien los nombres largos en teléfono.
