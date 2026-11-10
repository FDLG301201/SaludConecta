# SaludConecta

> **Más acceso, mejor salud.** App de telemedicina multi-rol en Flutter. Proyecto del 2do parcial de ISO910 (UNAPEC, cuatrimestre C11).

La app implementa las dos infografías del equipo:

1. **Proceso Integral de Telemedicina:** 10 pasos y 5 actores.
2. **Servicios de telemedicina:** 24 servicios en 3 grupos, más los canales.

Un caso recorre los 10 pasos, y cada paso lo completa el rol que le toca:

| Rol | Pasos | Pestañas |
|---|---|---|
| Paciente | 1 Solicitud · 6 Consentimiento · 10 Encuesta | Inicio · Mis citas · Servicios · Perfil |
| Admisión | 2 Recepción · 3 Validación del seguro · 4 Agendamiento · 5 Confirmación | Bandeja · Agenda · Seguimiento · Indicadores |
| Médico | 7 Consulta · 8 Resultados | Agenda · Indicadores |
| Facturación | 9 Cierre administrativo | Pendientes · Reclamaciones · Indicadores |

El 5.º actor, **Soporte TI**, no es un rol: aparece en los diagramas, en la prueba de conexión de la sala de espera y como contacto de soporte.

## Cómo ejecutarla

Requisitos: **Flutter 3.19.0 / Dart 3.3.0**. En el equipo de desarrollo, Flutter está en `C:\Users\Helen\dev\flutter\bin` y no está en el PATH.

Desde `saludconecta/`:

```bash
flutter pub get
flutter run -d emulator-5554     # Android (emulador Pixel 3a, API 34)
flutter run -d chrome            # Web, como respaldo
flutter test                     # 200 pruebas
flutter analyze                  # sin problemas
flutter build apk --debug        # APK en build/app/outputs/flutter-apk/
```

Notas:

- Android usa **Gradle 8 + AGP 8**, porque el JDK de Android Studio es Java 21.
- Si Android pide aceptar licencias, ejecuta `flutter doctor --android-licenses`.
- Todo vive en memoria, con datos semilla deterministas: al reiniciar, la app vuelve al estado inicial.
- No hay backend ni cámara real. La videollamada, el seguro y los envíos por WhatsApp o correo son simulados.

## Guion de demo (unos 8 minutos)

Para cambiar de rol en cualquier momento, usa el ícono de **Cambiar de rol** en la barra superior.

1. **Bienvenida → Paciente → María Fernández → Ingresar.** Se abre el Inicio, con su campana de notificaciones y los consejos de salud.
2. **Solicitar cita:**
   - servicio *Consulta médica general*;
   - canal *WhatsApp*;
   - un motivo de al menos 10 caracteres;
   - una fecha.

   Al enviar se abre el detalle del caso, con su línea de tiempo.
3. **Cambiar a Admisión (Ana Peña)** → Bandeja → filtro **Nuevas** → la solicitud de María → **Procesar**:
   1. registrar;
   2. validar el seguro (ARS Salud Plena Plus, **80%**);
   3. agendar con el Dr. Méndez, en un horario libre, por **MS Teams**;
   4. confirmar por WhatsApp.
4. **Cambiar a Paciente (María):**
   1. la notificación nueva;
   2. **firmar el consentimiento** con el dedo;
   3. sala de espera (prueba de conexión y Soporte TI);
   4. **videollamada**.
5. **Cambiar a Médico (Dr. Méndez)** → Agenda: "Paciente en sala de espera" → **Iniciar consulta** → **Notas clínicas** → colgar → "¿Finalizar consulta?" → **Emitir resultados**:
   - receta (sugerencias de medicamentos);
   - órdenes de laboratorio e imágenes;
   - seguimiento a 15 días;
   - **Emitir y notificar**.
6. **Cambiar a Facturación (Roberto Díaz)** → Pendientes → **Cerrar caso**:
   - factura (tarifa RD$1,500, copago RD$300);
   - **Enviar reclamación** (Aprobada · REC-…);
   - auditoría ✓;
   - **registrar el pago** del copago;
   - **Cerrar caso**.
7. **Cambiar a Paciente** → Mis resultados: **receta con QR**, órdenes y "Solicitar cita de seguimiento" → **Encuesta 5★**. El caso queda completado.
8. **Cambiar a Admisión → Indicadores.** El nuevo caso ya cuenta en el embudo y en las gráficas. Desde el ícono del diagrama, abre **Diagramas del proceso** y prueba "Flujo" y "Por actor" (toca un paso para ver su detalle).
9. **Camino alterno:** Admisión → Bandeja → **Pedro Almonte** (afiliación inactiva) → validar → **rechazado** → **Continuar como privado**.

Extras para la exposición:

- **Ver en el diagrama**, en el detalle de cualquier caso: el diagrama de flujo en *modo caso*, con los pasos completados, el actual con pulso y los pendientes.
- **Acerca de:**
  - las dos infografías con zoom;
  - el **diagrama de arquitectura** de Flutter y de la app;
  - el equipo.
- En el **Perfil del paciente**, "Mi resumen" muestra la dona de lo cubierto frente a lo pagado y las barras por especialidad.

### Casos en vivo de la semilla

Hay un caso por cada paso pendiente, para mostrar cualquier pantalla sin recorrer todo el proceso:

| Paciente | Paso pendiente | Dónde verlo |
|---|---|---|
| José Martínez | 2 Recepción | Admisión → Nuevas |
| Carmen Reyes | 3 Validación | Admisión → Por validar |
| Pedro Almonte | 3 Validación (rechazo) | Admisión → Por validar |
| Luisa Gómez | 4 Agendamiento | Admisión → Por agendar |
| Ramón Ortiz | 5 Confirmación (Dra. Jiménez) | Admisión → Por confirmar |
| José Martínez | 6 Consentimiento | Paciente José → Inicio |
| Carmen Reyes | 7 Consulta | Médico Méndez → "Paciente en sala de espera" |
| Luisa Gómez | 8 Resultados | Médico Méndez → Resultados pendientes |
| Ramón Ortiz | 9 Cierre | Facturación → Pendientes |
| José Martínez | 10 Seguimiento | Admisión → Seguimiento; Paciente José → Encuesta |

## Arquitectura

```
Presentación (features/, core/)   pantallas por rol, gráficas, diagramas, rutas y tema
        │  lee y escucha con Provider
Estado (state/)                   CaseProvider, SessionProvider (ChangeNotifier)
        │  usa
Dominio (domain/)                 Dart puro: ProcessStep, ProcessRules, CaseWorkflow,
        ▲                         BillingCalculator, StatsCalculator, ScheduleService
        │  implementa interfaces
Datos (data/)                     repositorios en memoria, gateways simulados, semilla
```

- `app_dependencies.dart` es la **raíz de composición**: crea los datos, los gateways, el estado y las rutas.
- **Navegación:** `go_router`, con `redirect` por rol y un `StatefulShellRoute` por rol que conserva cada pestaña.
- **Reglas del proceso:** cada transición valida el paso, el rol y el estado del caso. Si algo no cuadra, lanza `ProcessException` y la UI muestra un aviso.

### Gráficas, imágenes y diagramas

- **Gráficas (`fl_chart`):** se calculan en vivo con `StatsCalculator`. La pantalla Indicadores tiene 4 pestañas:
  - **Operación:** KPIs, dona por canal, líneas de solicitudes vs. consultas, embudo de los 10 pasos y horas por etapa.
  - **Clínico:** consultas por especialidad, dona por plataforma y resultados emitidos.
  - **Financiero:** barras apiladas seguro + copago, dona de reclamaciones y facturación por aseguradora.
  - **Satisfacción:** promedio ★, NPS, distribución 1–5★ y promedio por mes.

  Además, "Mi resumen" en el perfil del paciente.
- **Diagramas (`CustomPainter`):**
  - diagrama de flujo con el rombo del seguro y la rama privado o cancelar, toque por paso, zoom y *modo caso* con animación;
  - diagrama de carriles por actor;
  - línea de tiempo del caso;
  - diagrama de arquitectura.
- **Imágenes:**
  - 29 ilustraciones SVG propias: logo, roles, avatares, escenas y aseguradoras;
  - las 2 infografías del equipo;
  - el QR de la receta (`qr_flutter`);
  - el carnet de seguro dibujado con widgets;
  - la firma con el dedo.

### Paquetes

`provider`, `go_router`, `fl_chart`, `flutter_svg`, `intl` (español), `qr_flutter`, `url_launcher` (`tel:` de soporte).

## Estructura

```
saludconecta/
├── lib/
│   ├── main.dart, app.dart, app_dependencies.dart
│   ├── core/        constantes, tema, rutas, formatos y widgets reutilizables
│   ├── domain/      modelos, proceso de 10 pasos y servicios de cálculo
│   ├── data/        repositorios, gateways simulados y semilla
│   ├── state/       CaseProvider y SessionProvider
│   └── features/    auth, patient, admission, doctor, billing, indicators, diagrams, about, shared
├── assets/          illustrations/ (SVG) e images/ (infografías)
└── test/            200 pruebas: dominio, datos, estado y widgets (incluido el guion de demo)
```

El diseño completo está en `../docs/superpowers/specs/`. El plan, por etapas, está en `../docs/superpowers/plans/`.

## Equipo

Los integrantes se configuran en `lib/core/constants/app_info.dart` (`teamMembers`) y se muestran en **Acerca de → Equipo**.
