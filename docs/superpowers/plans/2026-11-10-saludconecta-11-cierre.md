# SaludConecta · Etapa 11: Cierre

> Hoja de ruta: [00-hoja-de-ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md) · Spec: §12 (errores y pruebas), §14 (guion de demo), §15 (Android).

**Objetivo:** completar las pruebas que pide el §12, verificar el proyecto completo y documentarlo con el README y el guion de demo.

## Cambios

| Archivo | Qué hace |
|---|---|
| `saludconecta/test/features/demo_script_test.dart` | Prueba de widgets entre roles (§12: "una solicitud creada por el paciente aparece en Nuevas de Admisión"). María solicita la cita y Admisión la ve en "Nuevas". El caso recorre los pasos 2–10 y, en Indicadores, el embudo cuenta un caso más en el paso 10 |
| `saludconecta/README.md` | Cómo ejecutarla, guion de demo (§14) adaptado a los textos reales de la UI, casos en vivo de la semilla, arquitectura, gráficas, diagramas e imágenes, y estructura |
| `README.md` (raíz) | Índice de los entregables del repositorio |

## Cobertura del §12

- **Unitarias:**
  - `process_rules_test`, `billing_calculator_test`, `schedule_service_test`, `stats_calculator_test`;
  - `seed_cases_test`, `case_provider_test` (recorrido completo y rechazo → privado).
- **De widgets:**
  - el ingreso del paciente lleva al Inicio (`login_flow_test`);
  - la solicitud llega a "Nuevas" (`demo_script_test`);
  - el diagrama de flujo se pinta y responde al toque (`diagrams_screens_test`);
  - Indicadores con sus 4 pestañas (`indicators_test`);
  - las pantallas de cada rol, en las etapas 5–10.

## Verificación

- `dart format -l 120 lib test`: 154 archivos, sin cambios.
- `flutter analyze`: sin problemas.
- `flutter test`: **200 pruebas en verde**.
- `flutter build web`: compila (Chrome de respaldo).
- `flutter build apk --debug`: compila e instala. El emulador Pixel 3a (API 34) se revisó en cada etapa con capturas, y las de esta sesión cubren las etapas 8–10.
