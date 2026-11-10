# SaludConecta — Hoja de ruta de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir la app Flutter SaludConecta descrita en el spec, en 11 etapas y con un commit por etapa.

**Architecture:** 4 capas: Presentación → Estado (Provider) → Dominio (Dart puro) ← Datos (en memoria). Las transiciones del proceso viven en el dominio (`CaseWorkflow`). Las usan tanto el `CaseProvider` (en vivo) como el generador de datos semilla (históricos).

**Tech Stack:** Flutter 3.19.0 / Dart 3.3.0, provider, go_router, fl_chart, flutter_svg, intl, qr_flutter, url_launcher.

**Spec:** [2026-11-08-saludconecta-design.md](../specs/2026-11-08-saludconecta-design.md)

## Global Constraints

Estas reglas valen para **todas** las etapas.

### Entorno y herramientas

- **Flutter:** está en `C:\Users\Helen\dev\flutter\bin\flutter.bat` y **no** está en el PATH. No se actualiza la instalación.
  - En PowerShell: `$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'` y luego `& $flutter <comando>`.
  - Dart: `C:\Users\Helen\dev\flutter\bin\dart.bat`.
  - Los comandos de Flutter se ejecutan dentro de `saludconecta/`.
- **APIs prohibidas:** no usar APIs posteriores a Flutter 3.19.

  | Prohibido | Usar en su lugar |
  |---|---|
  | `Color.withValues`, `.a`, `.r`, `.g`, `.b` | `withOpacity` |
  | `WidgetState*` | `MaterialState*` |
  | `ColorScheme.surfaceContainer*` | `surface` / `surfaceVariant` |
  | `CardThemeData` | `CardTheme` |
  | `CarouselView` | `PageView` |
  | `PopScope.onPopInvokedWithResult` | `onPopInvoked` |
  | `Card.filled` / `Card.outlined` | — |

- **Paquetes:** versiones verificadas. No agregar otros.

  | Paquete | Versión |
  |---|---|
  | `provider` | ^6.1.5+1 |
  | `go_router` | ^14.6.2 |
  | `fl_chart` | **^0.69.0** (la 0.70+ no compila con Flutter 3.19) |
  | `flutter_svg` | ^2.0.10+1 |
  | `intl` | ^0.18.1 (fijada por `flutter_localizations`) |
  | `qr_flutter` | ^4.1.0 |
  | `url_launcher` | ^6.3.1 |
  | `flutter_lints` | ^3.0.0 |

- **fl_chart 0.69:**
  - títulos de eje con `SideTitleWidget(axisSide: meta.axisSide, child: …)`;
  - color de tooltips con `getTooltipColor: (_) => …`.
- **Android:** Gradle 8.11.1 (`-bin`), AGP 8.6.1, Kotlin 2.1.21 y Java 17 en `compileOptions` y `jvmTarget`.

### Código

- **Idioma:** UI en español, identificadores en inglés y comentarios en español. La cabecera de un archivo va con `//`, no con `///`, para evitar el lint `dangling_library_doc_comments`.
- **Capas:**
  - `domain/` y `data/` son Dart puro: no importan `package:flutter`.
  - La UI no toca repositorios: solo lee y llama al estado.
- **Modelos:**
  - inmutables (`final` + `copyWith`);
  - IDs `String`;
  - montos en pesos enteros (`int`), que se formatean como "RD$1,500.00".
- **Calidad:**
  - `flutter analyze` sin **ningún** aviso; los `info` también cuentan. Usar `const` siempre que se pueda.
  - Un `if` sin llaves solo si cabe en una línea de 120 caracteres.
  - Formato con `dart format -l 120 lib test`.
- **Pruebas:** van en `test/` e importan con `package:saludconecta/...`.

### Git y datos

- **Git:**
  - un commit al terminar **cada etapa**, no cada tarea;
  - mensaje en español con prefijo convencional (`feat:`, `test:`, `docs:`);
  - sin push;
  - el repo ya tiene la identidad local `FDLG301201 <fdlg301201@gmail.com>`. Nunca se usa ni se cambia la identidad global, que es la cuenta laboral.
- **Datos ficticios:**
  - aseguradoras "ARS Salud Plena", "ARS Vida Segura" y "ARS Familia Sana";
  - teléfonos 809-555-xxxx y correos `@example.com`;
  - Teams, Zoom y Meet solo por nombre, sin logos.

## Cómo está organizado el plan

- **Un plan por etapa:** cada etapa del spec (§17) tiene su propio plan y termina con un commit.
- **Etapas 1 y 2:** sus planes están escritos completos. Traen cada archivo, cada prueba y cada comando.
- **Etapas 3 a 11:** cada plan se escribe **justo antes de ejecutar esa etapa**, con el mismo formato. Se basa en el spec y en el código real de las etapas anteriores. Así los nombres, firmas y APIs coinciden con lo que de verdad existe.
- **Al terminar cada etapa:** se marca como hecha en la tabla de abajo, en el mismo commit.

## Etapas

| # | Etapa | Plan | Spec | Resultado verificable | Estado |
|---|---|---|---|---|---|
| 1 | Andamiaje | [01-andamiaje](2026-11-09-saludconecta-01-andamiaje.md) | §2, §3, §11, §15 | App mínima con tema y ruta `/bienvenida`. Compila en web y Android. Pruebas de formatos y de arranque | hecha |
| 2 | Dominio y datos | [02-dominio-y-datos](2026-11-09-saludconecta-02-dominio-y-datos.md) | §4, §13 | Modelos, reglas, flujo, calculadoras, gateways y semilla, con pruebas unitarias en verde | hecha |
| 3 | Ilustraciones e infografías | [03-ilustraciones](2026-11-09-saludconecta-03-ilustraciones.md) | §9 | 29 SVG y 2 infografías en `assets/`. Catálogo `AppIllustrations` y prueba que carga cada SVG | hecha |
| 4 | Estado, ingreso y shells | [04-estado-y-shells](2026-11-09-saludconecta-04-estado-y-shells.md) | §5, §6 (rutas, redirect, comunes), §8 | Providers, bienvenida, ingreso, cambio de rol, shells por rol, detalle del caso con línea de tiempo y `case_provider_test` | hecha |
| 5 | Flujo del paciente | [05-flujo-paciente](2026-11-09-saludconecta-05-flujo-paciente.md) | §6 Paciente | Solicitar cita, mis citas, servicios, perfil, consentimiento con firma, sala de espera, videollamada, resultados con QR y encuesta | hecha |
| 6 | Flujo de Admisión | al cerrar la 5 | §6 Admisión | Bandeja con filtros, *stepper* de los pasos 2–5 (con rechazo → privado), agenda y seguimiento | pendiente |
| 7 | Flujo del Médico | al cerrar la 6 | §6 Médico | Agenda, videollamada con notas clínicas y emisión de resultados | pendiente |
| 8 | Flujo de Facturación | al cerrar la 7 | §6 Facturación | Pendientes, cierre (factura, reclamación, auditoría y pago) y reclamaciones | pendiente |
| 9 | Indicadores | al cerrar la 8 | §7 | Las 4 pestañas con sus gráficas y KPIs, y las gráficas del perfil del paciente | pendiente |
| 10 | Diagramas y Acerca de | al cerrar la 9 | §10, §6 Acerca de | Diagramas de flujo y de carriles con `CustomPainter`, modo caso, diagrama de arquitectura y Acerca de | pendiente |
| 11 | Cierre | al cerrar la 10 | §12, §14 | Pruebas de widgets, `analyze`, verificación en Chrome y Android, y README con el guion de demo | pendiente |

## Entorno verificado (2026-11-09)

| Componente | Valor |
|---|---|
| Flutter / Dart | 3.19.0 / 3.3.0 en `C:\Users\Helen\dev\flutter` |
| Java que usa Gradle | OpenJDK 21.0.8 (JBR de Android Studio) |
| Android SDK | `C:\Users\Helen\AppData\Local\Android\Sdk`: plataformas android-34 y 36, build-tools 34.0.0 a 36.1.0 |
| Gradle / AGP / Kotlin | 8.11.1 / 8.6.1 / 2.1.21, ya en la caché local de Gradle |
| Emulador | `Pixel_3a_API_34_extension_level_7_x86_64` (imagen android-34 google_apis) |
| Web | Chrome 156 |

**Licencias de Android:** `flutter doctor` muestra "Some Android licenses not accepted", pero eso no impidió compilar, porque los componentes necesarios ya están instalados. Si en algún momento Gradle pide descargar un componente nuevo, el usuario ejecuta `flutter doctor --android-licenses`.

**Cómo se verificó:** con un proyecto de prueba desechable en el scratchpad, que usa las mismas APIs que el plan.

- **Con las versiones de arriba:**
  - `flutter analyze` no dio ningún aviso;
  - `flutter build web` funcionó;
  - `flutter build apk --debug` funcionó, y con Gradle 8 tardó unos 3 minutos.
- **Con fl_chart 0.71:** no compiló, porque usa `Color.withValues` y `Color.a`, que son de Flutter 3.27.
- **Formatos de `intl` 0.18.1 en `es`:**
  - "a. m." y "p. m." llevan un espacio no separable (U+00A0), que se reemplaza por un espacio normal;
  - los meses cortos son "ene", "feb"… "sept", "oct", "nov", "dic";
  - los días van en minúscula ("jueves").

### Notas para verificar en cada etapa

Aprendidas al cerrar las etapas 1, 4 y 5:

- **Web:**
  - con `preview_start` (`saludconecta-web`), la primera carga puede quedar en blanco mientras el servidor de desarrollo compila: se recarga la página unos 20 s después;
  - si el panel del navegador está oculto, la página corre en segundo plano y las animaciones se frenan. Una hoja o una transición puede tardar en verse: se espera 1 o 2 s y se vuelve a capturar, sin repetir el clic;
  - el panel mide unos 800 px de ancho, así que la web muestra el diseño ancho (riel lateral). El diseño angosto (barra inferior) se revisa en Android;
  - `navigate` a la misma dirección con otro `#` no recarga la app. Para recargarla se abre la raíz, `http://localhost:8090/`;
  - `.claude/launch.json` usa la ruta absoluta del proyecto, así funciona desde cualquier carpeta.
- **Android:**
  - recompilar el APK (`flutter build apk --debug --target-platform android-x64`) **antes** de instalarlo;
  - después de arrancar, el emulador deja la pantalla apagada y `screencap` sale negro: antes de capturar, enviar `adb shell input keyevent KEYCODE_WAKEUP`.
  - `adb` está en `C:\Users\Helen\AppData\Local\Android\Sdk\platform-tools\adb.exe`.
- **Pruebas de widgets:**
  - la fuente de las pruebas dibuja cada letra como un cuadro, así que los textos ocupan más que en un teléfono y parte del contenido queda fuera de la vista. Lo que no se ve no se encuentra: se usa `scrollUntilVisible` (o `ensureVisible`) y después `pump()` antes de `tap`, porque sin ese cuadro `tap` usa la posición vieja;
  - con animaciones que no terminan (la videollamada) no sirve `pumpAndSettle`: se avanza con `pump(duración)`.
- **Hojas inferiores:** las que se abren desde una pestaña del shell llevan `useRootNavigator: true`. Cada pestaña tiene su propio Navigator y, sin eso, la hoja no cubre la barra superior.

## Infografías

Las 2 infografías del equipo estaban en una carpeta temporal. Ya están copiadas en `docs/infografias/`:

- `infografia_proceso.webp`;
- `infografia_servicios.webp`.

La etapa 3 las copia a `saludconecta/assets/images/`.

## Refinamientos respecto al spec

Son decisiones que se tomaron al escribir el plan y que no cambian lo que se ve en la app.

1. **`CaseWorkflow`** (`domain/process/case_workflow.dart`): cada transición del proceso es una función pura del dominio. Valida con `ProcessRules`, aplica `copyWith` y agrega el evento.
   - El `CaseProvider` la llama, guarda el caso y notifica. Lo mismo describe el §5, pero así la lógica queda en el dominio, probada sin interfaz.
   - La semilla genera los casos históricos con esas mismas funciones, así que todos son válidos.
2. **`AssistAction`:** `ensureCanAssist(case, action, role)` recibe la acción auxiliar (`startConsultation`, `submitClaim`, `registerPayment`, `logFollowUpCall`) en lugar del paso. La acción ya sabe su paso y su rol. Hace falta porque la llamada de seguimiento la hace Admisión en el paso 10, cuyo dueño es el paciente.
3. **`EventKind`:** `ProcessEvent` tiene un `kind`: `completed`, `rejected`, `cancelled`, `started`, `claim`, `payment` o `call`. `completesStep` pasa a ser un getter, que es `true` solo si el tipo es `completed`. Así los avisos y la línea de tiempo distinguen cada evento sin comparar textos.
4. **Horario del médico:** `Doctor.schedule` es un `Map<int, WorkHours>` por día de la semana, en lugar de `workDays`/`startHour`/`endHour`, porque el Dr. Méndez trabaja el sábado con otro horario (8–12). `workDays` sigue existiendo como getter.
5. **`ConfirmationGateway`:** es aparte de `InsuranceGateway`, porque enviar el enlace no es tarea del seguro. El `CaseProvider` recibirá los dos.
6. **`Clock`:** es un `typedef` que se inyecta en gateways y providers. Así las pruebas usan una hora fija.
7. **Paso 10:** su `actor` es Admisión, porque el hospital hace el seguimiento; eso define el color y el carril principal. Su dueño (`owners`) es el Paciente, porque la encuesta lo completa.
8. **Reclamaciones históricas "Pendiente" y "Glosada":** la regla del paso 9 exige la reclamación aprobada para cerrar. Por eso la semilla cierra el caso con la reclamación aprobada y después le aplica la "respuesta posterior de la ARS". Esto solo ocurre en los datos históricos.
9. **Históricos que no alcanzan a terminar:** si un caso histórico no terminaría antes de "ahora", no se genera. Así ningún histórico queda abierto ni ensucia las bandejas; los únicos casos abiertos son los 10 en vivo.
10. **`StaffMember`:** tiene `phone` (para "Llamar a soporte") y `avatarAsset` opcional. Si no hay avatar se muestran las iniciales.
