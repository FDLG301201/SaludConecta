# SaludConecta · Etapa 1: Andamiaje — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crear el proyecto Flutter `saludconecta/`, con sus paquetes, el tema, los formatos y una ruta inicial, que compile en web y en Android con Java 21.

**Architecture:**

- `main.dart` carga los formatos de fecha en español y arranca `SaludConectaApp`, que es un `MaterialApp.router`.
- `AppRouter.create()` define por ahora solo `/bienvenida`.
- El tema, los colores, los datos de la app y los formatos viven en `core/`.

**Tech Stack:** Flutter 3.19.0, Dart 3.3.0 y go_router 14.6.2. También intl 0.18.1 con `flutter_localizations`. Aquí se instalan todos los paquetes, aunque la mayoría se usa desde la etapa 2.

**Hoja de ruta:** [00-hoja-de-ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md) · **Spec:** §2, §3, §11, §15

## Global Constraints

Las de la [hoja de ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md#global-constraints). Las más relevantes para esta etapa:

- **Flutter:** `C:\Users\Helen\dev\flutter\bin\flutter.bat`, que no está en el PATH. Los comandos se ejecutan dentro de `saludconecta/`.
- **Android:** Gradle 8.11.1 (`-bin`), AGP 8.6.1, Kotlin 2.1.21 y Java 17 en `compileOptions` y `jvmTarget`.
- **Paquetes:**
  - `fl_chart: ^0.69.0`, no la 0.70+;
  - `intl: ^0.18.1`;
  - el resto, según la tabla de la hoja de ruta.
- **Etiqueta de la app:** "SaludConecta" en Android y web.
- **Calidad:** `flutter analyze` sin ningún aviso.
- **Git:** un solo commit al final de la etapa, con la identidad local del repo, ya configurada.

## Archivos de la etapa

| Archivo | Responsabilidad |
|---|---|
| `.gitignore` (raíz) | Ignora `.claude/` (configuración local de Claude Code) |
| `saludconecta/` | Proyecto creado con `flutter create` |
| `saludconecta/android/settings.gradle`, `android/build.gradle`… | Gradle 8 / AGP 8 / Kotlin 2 para compilar con Java 21 |
| `saludconecta/android/app/src/main/AndroidManifest.xml` | Etiqueta "SaludConecta" y consulta `tel:` para `url_launcher` |
| `saludconecta/web/index.html`, `web/manifest.json` | Nombre, descripción y colores en la web |
| `saludconecta/pubspec.yaml` | Descripción y dependencias |
| `lib/core/constants/app_info.dart` | Nombre, lema, curso e integrantes |
| `lib/core/theme/app_colors.dart` | Paleta del §11 |
| `lib/core/theme/app_theme.dart` | `ThemeData` Material 3 |
| `lib/core/utils/formatters.dart` | Montos RD$, fechas y horas en español, duraciones |
| `lib/features/auth/welcome_screen.dart` | Pantalla inicial provisional (la etapa 4 la reemplaza) |
| `lib/core/router/app_router.dart` | `GoRouter` con `/bienvenida` |
| `lib/app.dart` | `SaludConectaApp` (`MaterialApp.router` en español) |
| `lib/main.dart` | Arranque |
| `test/core/formatters_test.dart` | Pruebas de los formatos |
| `test/app_test.dart` | Prueba de arranque (reemplaza `test/widget_test.dart`) |
| `.claude/launch.json` | Servidor web para la vista previa en el panel del navegador. No se versiona |

---

### Task 1: Proyecto que compila en Android con Java 21

**Files:**
- Create: `saludconecta/` (con `flutter create`), `.gitignore`
- Modify: `saludconecta/android/settings.gradle`, `saludconecta/android/gradle/wrapper/gradle-wrapper.properties`, `saludconecta/android/app/build.gradle`, `saludconecta/android/app/src/main/AndroidManifest.xml`, `saludconecta/web/index.html`, `saludconecta/web/manifest.json`

**Interfaces:**
- Consumes: nada.
- Produces: el proyecto `saludconecta` (paquete Dart `saludconecta`, `applicationId` `edu.unapec.iso910.saludconecta`).

- [ ] **Step 1: Crear el proyecto** (desde la raíz del repositorio)

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
& $flutter create --org edu.unapec.iso910 --project-name saludconecta --platforms android,web saludconecta
```

Expected:
- termina con `All done!`;
- avisa que Java 21 no es compatible con Gradle 7.6.3, lo que se corrige en los pasos siguientes.

- [ ] **Step 2: Crear `.gitignore` en la raíz del repositorio**

```gitignore
# Configuración local de Claude Code (vista previa web, permisos). No forma parte de las fuentes.
.claude/
```

- [ ] **Step 3: Subir Gradle, AGP y Kotlin**

En `saludconecta/android/settings.gradle`, reemplazar:

```groovy
    id "com.android.application" version "7.3.0" apply false
    id "org.jetbrains.kotlin.android" version "1.7.10" apply false
```

por:

```groovy
    // Versiones compatibles con Java 21 (el JDK de Android Studio).
    id "com.android.application" version "8.6.1" apply false
    id "org.jetbrains.kotlin.android" version "2.1.21" apply false
```

En `saludconecta/android/gradle/wrapper/gradle-wrapper.properties`, reemplazar:

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-7.6.3-all.zip
```

por:

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.11.1-bin.zip
```

En `saludconecta/android/app/build.gradle`, reemplazar:

```groovy
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }
```

por:

```groovy
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
    }
```

- [ ] **Step 4: Nombre de la app y consulta `tel:` en Android**

En `saludconecta/android/app/src/main/AndroidManifest.xml`, reemplazar `android:label="saludconecta"` por `android:label="SaludConecta"`. Luego, reemplazar el cierre de `<queries>`:

```xml
    </queries>
```

por:

```xml
        <!-- url_launcher: permite abrir el marcador con "tel:" (Llamar a soporte TI). -->
        <intent>
            <action android:name="android.intent.action.DIAL"/>
            <data android:scheme="tel"/>
        </intent>
    </queries>
```

- [ ] **Step 5: Nombre, descripción y colores en la web**

En `saludconecta/web/index.html`:

| Reemplazar | Por |
|---|---|
| `<meta name="description" content="A new Flutter project.">` | `<meta name="description" content="SaludConecta: telemedicina. Más acceso, mejor salud.">` |
| `<meta name="apple-mobile-web-app-title" content="saludconecta">` | `<meta name="apple-mobile-web-app-title" content="SaludConecta">` |
| `<title>saludconecta</title>` | `<title>SaludConecta</title>` |

En `saludconecta/web/manifest.json`:

| Reemplazar | Por |
|---|---|
| `"name": "saludconecta",` | `"name": "SaludConecta",` |
| `"short_name": "saludconecta",` | `"short_name": "SaludConecta",` |
| `"background_color": "#0175C2",` | `"background_color": "#F4F8FB",` |
| `"theme_color": "#0175C2",` | `"theme_color": "#1565C0",` |
| `"description": "A new Flutter project.",` | `"description": "SaludConecta: telemedicina. Más acceso, mejor salud.",` |

- [ ] **Step 6: Compilar para Android**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter build apk --debug --target-platform android-x64
```

Expected:
- termina con `√ Built build\app\outputs\flutter-apk\app-debug.apk`;
- los avisos `source value 8 is obsolete`, que vienen de plugins, son normales;
- la primera vez tarda unos 3 minutos.

Si Gradle pide aceptar licencias, el usuario ejecuta `flutter doctor --android-licenses` y se repite el paso.

---

### Task 2: Paquetes, tema y formatos

**Files:**
- Modify: `saludconecta/pubspec.yaml`
- Create: `saludconecta/lib/core/constants/app_info.dart`, `saludconecta/lib/core/theme/app_colors.dart`, `saludconecta/lib/core/theme/app_theme.dart`, `saludconecta/lib/core/utils/formatters.dart`
- Test: `saludconecta/test/core/formatters_test.dart`

**Interfaces:**
- Consumes: el proyecto de la tarea 1.
- Produces (los usan todas las etapas siguientes):
  - `AppInfo.appName`, `AppInfo.slogan`, `AppInfo.course`, `AppInfo.project`, `AppInfo.term` (todas `String`) y `AppInfo.teamMembers` (`List<String>`).
  - `AppColors`:
    - base: `primary`, `secondary`, `background`, `navy`;
    - actores: `patient`, `admission`, `doctor`, `support`, `billing`;
    - estados: `done`, `current`, `pending`, `danger` (todas `Color`).
  - `AppTheme.light() → ThemeData`.
  - `Formatters`:
    - `money(num) → String`;
    - `date`, `shortDate`, `time`, `dateTime` y `monthLabel`, todas `(DateTime) → String`;
    - `duration(Duration) → String`.

- [ ] **Step 1: Descripción y dependencias en `pubspec.yaml`**

Reemplazar la línea de descripción:

```yaml
description: "A new Flutter project."
```

por:

```yaml
description: "SaludConecta: app de telemedicina multi-rol (ISO910, UNAPEC)."
```

Reemplazar el bloque `dependencies:` completo (desde `dependencies:` hasta la línea `cupertino_icons: ^1.0.6`, incluidos los comentarios que trae la plantilla) por:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cupertino_icons: ^1.0.6
  # Estado (ChangeNotifier).
  provider: ^6.1.5+1
  # Navegación con rutas y redirect por rol.
  go_router: ^14.6.2
  # Gráficas. La 0.70+ usa APIs de Flutter 3.27 y no compila con 3.19.
  fl_chart: ^0.69.0
  # Ilustraciones SVG.
  flutter_svg: ^2.0.10+1
  # Fechas y montos en español (versión fijada por flutter_localizations).
  intl: ^0.18.1
  # QR de la receta.
  qr_flutter: ^4.1.0
  # "Llamar a soporte" (tel:).
  url_launcher: ^6.3.1
```

Luego:

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter pub get
Select-String -Path pubspec.lock -Pattern '^  (fl_chart|go_router|intl|provider):' -Context 0,5 | ForEach-Object { $_.Line.Trim() + ' ' + ($_.Context.PostContext | Select-String 'version').Line.Trim() }
```

Expected:
- `Got dependencies!`;
- en el lock: `fl_chart: version: "0.69.2"`, `go_router: version: "14.6.2"`, `intl: version: "0.18.1"` y `provider: version: "6.1.5+1"`.

- [ ] **Step 2: Escribir la prueba de los formatos**

Create `saludconecta/test/core/formatters_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/utils/formatters.dart';

void main() {
  setUpAll(() async {
    // En la app esto se hace en main(); las pruebas lo hacen aquí.
    await initializeDateFormatting('es');
  });

  test('montos en pesos dominicanos', () {
    expect(Formatters.money(1500), r'RD$1,500.00');
    expect(Formatters.money(812.5), r'RD$812.50');
  });

  test('fecha y hora en español', () {
    final value = DateTime(2026, 11, 12, 10, 30);
    expect(Formatters.dateTime(value), 'jueves, 12 de noviembre · 10:30 a. m.');
    expect(Formatters.time(DateTime(2026, 11, 12, 15)), '3:00 p. m.');
    expect(Formatters.shortDate(value), '12 nov 2026');
    expect(Formatters.monthLabel(value), 'Nov');
  });

  test('duraciones cortas', () {
    expect(Formatters.duration(const Duration(minutes: 45)), '45 min');
    expect(Formatters.duration(const Duration(hours: 3)), '3 h');
    expect(Formatters.duration(const Duration(hours: 3, minutes: 20)), '3 h 20 min');
    expect(Formatters.duration(const Duration(days: 2, hours: 4)), '2 d 4 h');
  });
}
```

- [ ] **Step 3: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/core/formatters_test.dart
```

Expected: FAIL. No compila porque `lib/core/utils/formatters.dart` no existe.

- [ ] **Step 4: Crear los archivos de `core/`**

Create `saludconecta/lib/core/constants/app_info.dart`:

```dart
/// Datos generales de la app y del equipo. Se muestran en "Acerca de".
class AppInfo {
  const AppInfo._();

  static const appName = 'SaludConecta';
  static const slogan = 'Más acceso, mejor salud';
  static const course = 'ISO910 · UNAPEC';
  static const project = 'Proyecto del 2do parcial';
  static const term = 'Cuatrimestre C11';

  /// Integrantes del equipo. Pendiente: poner los nombres reales antes de entregar.
  static const teamMembers = <String>['Integrante 1', 'Integrante 2', 'Integrante 3'];
}
```

Create `saludconecta/lib/core/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

/// Paleta de SaludConecta (§11 del spec).
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF1565C0);
  static const secondary = Color(0xFF00897B);
  static const background = Color(0xFFF4F8FB);

  /// Azul marino de los encabezados.
  static const navy = Color(0xFF0D3B66);

  // Un color por actor del proceso (infografía 1).
  static const patient = Color(0xFF43A047);
  static const admission = Color(0xFF1E88E5);
  static const doctor = Color(0xFF00897B);
  static const support = Color(0xFF7B1FA2);
  static const billing = Color(0xFF283593);

  // Estados de los pasos.
  static const done = Color(0xFF2E7D32);
  static const current = Color(0xFFF9A825);
  static const pending = Color(0xFF9E9E9E);
  static const danger = Color(0xFFC62828);
}
```

Create `saludconecta/lib/core/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema Material 3 de la app (sin modo oscuro).
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      background: AppColors.background,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );
    final text = base.textTheme;
    return base.copyWith(
      // Títulos en azul marino y negrita.
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(color: AppColors.navy, fontWeight: FontWeight.bold),
        headlineSmall: text.headlineSmall?.copyWith(color: AppColors.navy, fontWeight: FontWeight.bold),
        titleLarge: text.titleLarge?.copyWith(color: AppColors.navy, fontWeight: FontWeight.bold),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
```

Create `saludconecta/lib/core/utils/formatters.dart`:

```dart
import 'package:intl/intl.dart';

/// Formatos en español. Requieren `initializeDateFormatting('es')`, que se hace en `main`.
class Formatters {
  const Formatters._();

  static final _money = NumberFormat.currency(locale: 'en_US', symbol: r'RD$', decimalDigits: 2);

  /// 1500 → "RD$1,500.00" (formato usado en República Dominicana).
  static String money(num amount) => _money.format(amount);

  /// "jueves, 12 de noviembre".
  static String date(DateTime value) => _clean(DateFormat("EEEE, d 'de' MMMM", 'es').format(value));

  /// "12 nov 2026".
  static String shortDate(DateTime value) => _clean(DateFormat('d MMM y', 'es').format(value));

  /// "10:30 a. m.".
  static String time(DateTime value) => _clean(DateFormat('h:mm a', 'es').format(value));

  /// "jueves, 12 de noviembre · 10:30 a. m.".
  static String dateTime(DateTime value) => '${date(value)} · ${time(value)}';

  /// "Nov": etiqueta corta para los ejes de las gráficas.
  static String monthLabel(DateTime value) {
    final text = _clean(DateFormat('MMM', 'es').format(value));
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  /// "45 min", "3 h 20 min" o "2 d 4 h".
  static String duration(Duration value) {
    if (value.inMinutes < 60) return '${value.inMinutes} min';
    if (value.inHours < 24) {
      final minutes = value.inMinutes % 60;
      return minutes == 0 ? '${value.inHours} h' : '${value.inHours} h $minutes min';
    }
    final hours = value.inHours % 24;
    return hours == 0 ? '${value.inDays} d' : '${value.inDays} d $hours h';
  }

  /// `intl` pone espacios no separables en "a. m."; se cambian por espacios normales.
  static String _clean(String text) => text.replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ');
}
```

- [ ] **Step 5: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/core/formatters_test.dart
```

Expected: `All tests passed!` (3 pruebas).

---

### Task 3: App mínima con router

**Files:**
- Create: `saludconecta/lib/features/auth/welcome_screen.dart`, `saludconecta/lib/core/router/app_router.dart`, `saludconecta/lib/app.dart`
- Modify (reemplazo completo): `saludconecta/lib/main.dart`
- Delete: `saludconecta/test/widget_test.dart`
- Test: `saludconecta/test/app_test.dart`

**Interfaces:**
- Consumes: `AppInfo`, `AppColors`, `AppTheme.light()`.
- Produces:
  - `SaludConectaApp({required GoRouter router})`, el widget raíz.
  - `AppRouter.welcome` (`'/bienvenida'`) y `AppRouter.create() → GoRouter`. En la etapa 4, `create` pasa a recibir los providers para el `redirect`.
  - `WelcomeScreen()`, la pantalla provisional.

- [ ] **Step 1: Escribir la prueba de arranque y borrar la de la plantilla**

```powershell
Remove-Item saludconecta\test\widget_test.dart
```

Create `saludconecta/test/app_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/app.dart';
import 'package:saludconecta/core/router/app_router.dart';

void main() {
  testWidgets('la app arranca en la bienvenida con el nombre y el lema', (tester) async {
    await tester.pumpWidget(SaludConectaApp(router: AppRouter.create()));
    await tester.pumpAndSettle();

    expect(find.text('SaludConecta'), findsOneWidget);
    expect(find.text('Más acceso, mejor salud'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test test/app_test.dart
```

Expected: FAIL. No compila porque `lib/app.dart` y `lib/core/router/app_router.dart` no existen.

- [ ] **Step 3: Crear la pantalla, el router, la app y el arranque**

Create `saludconecta/lib/features/auth/welcome_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/constants/app_info.dart';
import '../../core/theme/app_colors.dart';

/// Pantalla inicial provisional. En la etapa 4 se reemplaza por la bienvenida con `PageView`.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.medical_services_outlined, size: 72, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(AppInfo.appName, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(AppInfo.slogan, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.secondary)),
              const SizedBox(height: 24),
              const Text('Etapa 1: andamiaje listo', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
```

Create `saludconecta/lib/core/router/app_router.dart`:

```dart
import 'package:go_router/go_router.dart';

import '../../features/auth/welcome_screen.dart';

/// Rutas de la app. En la etapa 4 se agregan los shells por rol y el `redirect`.
class AppRouter {
  const AppRouter._();

  static const welcome = '/bienvenida';

  static GoRouter create() {
    return GoRouter(
      initialLocation: welcome,
      routes: [
        GoRoute(path: welcome, builder: (context, state) => const WelcomeScreen()),
      ],
    );
  }
}
```

Create `saludconecta/lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_info.dart';
import 'core/theme/app_theme.dart';

/// Widget raíz: tema, idioma español y rutas.
class SaludConectaApp extends StatelessWidget {
  const SaludConectaApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppInfo.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      // Textos de Material (DatePicker, botones…) en español.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
```

Replace the whole content of `saludconecta/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carga los nombres de días y meses en español para `intl`.
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';
  runApp(SaludConectaApp(router: AppRouter.create()));
}
```

- [ ] **Step 4: Ejecutar todas las pruebas y el análisis**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location saludconecta
& $flutter test
& $flutter analyze
```

Expected:
- `All tests passed!` (4 pruebas);
- `No issues found!`.

---

### Task 4: Verificación en web y Android, y commit de la etapa

**Files:**
- Create: `.claude/launch.json` (ignorado por git)
- Modify: `docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md` (estado de la etapa 1)

**Interfaces:**
- Consumes: la app de la tarea 3.
- Produces:
  - la configuración `saludconecta-web` para `preview_start`, que se usa en todas las etapas para ver la app en el panel del navegador;
  - el commit de la etapa 1.

- [ ] **Step 1: Formato y compilación web**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
$dart = 'C:\Users\Helen\dev\flutter\bin\dart.bat'
Set-Location saludconecta
& $dart format -l 120 lib test
& $flutter build web --release
```

Expected: `√ Built build\web`.

- [ ] **Step 2: Configurar la vista previa web**

Create `.claude/launch.json` (en la raíz del repositorio):

```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "saludconecta-web",
      "runtimeExecutable": "cmd",
      "runtimeArgs": [
        "/c",
        "cd /d saludconecta && C:\\Users\\Helen\\dev\\flutter\\bin\\flutter.bat run -d web-server --web-hostname localhost --web-port 8090"
      ],
      "port": 8090
    }
  ]
}
```

Iniciar la vista previa con `preview_start` (`name: "saludconecta-web"`). La primera compilación tarda cerca de un minuto. Luego tomar una captura del panel del navegador.

Expected:
- en el centro se ve el ícono médico azul;
- debajo, "SaludConecta", "Más acceso, mejor salud" y "Etapa 1: andamiaje listo".

Al terminar, detener el servidor con `preview_stop`.

- [ ] **Step 3: Instalar y abrir en el emulador Android**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
$adb = 'C:\Users\Helen\AppData\Local\Android\Sdk\platform-tools\adb.exe'
Set-Location saludconecta
& $flutter build apk --debug --target-platform android-x64
& $flutter emulators --launch Pixel_3a_API_34_extension_level_7_x86_64
& $adb wait-for-device
$deadline = (Get-Date).AddMinutes(4)
do { Start-Sleep -Seconds 5; $booted = (& $adb shell getprop sys.boot_completed) } until ($booted -match '1' -or (Get-Date) -gt $deadline)
& $adb install -r build\app\outputs\flutter-apk\app-debug.apk
& $adb shell am start -n edu.unapec.iso910.saludconecta/.MainActivity
Start-Sleep -Seconds 10
& $adb shell screencap -p /sdcard/saludconecta.png
& $adb pull /sdcard/saludconecta.png "$env:TEMP\saludconecta-etapa1.png"
```

Expected:
- `Success` al instalar;
- la captura `%TEMP%\saludconecta-etapa1.png` muestra la misma pantalla que en la web.

Ver la captura con la herramienta `Read`.

- [ ] **Step 4: Marcar la etapa en la hoja de ruta**

En `docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md`, en la fila de la etapa 1, cambiar el estado `pendiente` por `hecha`.

- [ ] **Step 5: Commit de la etapa 1**

```powershell
git add .gitignore saludconecta docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md
git status --short
git commit -m "feat: andamiaje de SaludConecta (etapa 1)" -m "Proyecto Flutter con Gradle 8/AGP 8.6/Kotlin 2.1 para Java 21, paquetes, tema, formatos en español y ruta inicial. Compila en web y Android."
git log --oneline -3
```

Expected:
- `git status` solo lista archivos bajo `saludconecta/`, `.gitignore` y la hoja de ruta. No aparece `.claude/` ni `build/`.
- El commit tiene como autor `FDLG301201`.
