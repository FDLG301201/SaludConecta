# SaludConecta · Etapa 3: Ilustraciones e infografías — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar las 29 ilustraciones SVG propias y las 2 infografías del equipo. Las ilustraciones tienen su catálogo de rutas, los widgets para mostrarlas y una galería provisional para verlas en web y Android.

**Architecture:**

- **Assets:** las imágenes viven en `saludconecta/assets/illustrations/` (SVG) y en `saludconecta/assets/images/` (WebP).
- **`AppIllustrations`** (`core/constants/`): concentra todas las rutas. La UI nunca escribe una ruta a mano.
- **`AppIllustration` y `AvatarImage`** (`core/widgets/`): las muestran con `flutter_svg`. Si no hay avatar, `AvatarImage` muestra las iniciales.
- **Avatares:** un script de Dart fuera del proyecto genera los 13. Solo se versionan los SVG.
- **Galería:** `IllustrationsGallery` (`features/shared/`) muestra todas las imágenes. La pantalla provisional de bienvenida la usa hasta que la etapa 4 la reemplace; después se puede reutilizar en "Acerca de".

**Tech Stack:** `flutter_svg` 2.0.10+1 (`SvgPicture`, `SvgStringLoader`), `Image.asset` para WebP, `dart:io` en el generador y en las pruebas.

**Hoja de ruta:** [00-hoja-de-ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md) · **Spec:** §8 (`AppIllustration`, `AvatarImage`), §9, §11

## Global Constraints

Las de la [hoja de ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md#global-constraints). Las más relevantes para esta etapa:

- **Restricciones de `flutter_svg`:**
  - no se usan `<text>`, `<filter>`, `<mask>`, `<style>`, `<image>` ni `<script>`;
  - solo atributos en línea, formas, *paths*, degradados y `clipPath`;
  - todo SVG tiene `viewBox`.
- **Estilo:** plano, formas redondeadas y la paleta del §11. Los colores de cada actor, en particular:

  | Actor | Color |
  |---|---|
  | Paciente | `#43A047` |
  | Admisión | `#1E88E5` |
  | Médico | `#00897B` |
  | Soporte | `#7B1FA2` |
  | Facturación | `#283593` |

  Los encabezados van en `#0D3B66`.
- **Marcas:** sin logos ni nombres de marcas reales. Las aseguradoras son símbolos ficticios, sin texto.
- **Generador de avatares:** vive en el scratchpad de la sesión, fuera del repositorio. Solo se versionan los SVG que produce.
- **Calidad:** `flutter analyze` sin avisos. Los comandos de Flutter se ejecutan en `saludconecta/` con la ruta completa de `flutter.bat`.
- **Git:** un solo commit al final de la etapa (tarea 5).

## Archivos de la etapa

| Archivo | Responsabilidad |
|---|---|
| `saludconecta/pubspec.yaml` | Declara `assets/illustrations/` y `assets/images/` |
| `saludconecta/assets/images/infografia_proceso.webp`, `infografia_servicios.webp` | Copias de `docs/infografias/` |
| `saludconecta/lib/core/constants/app_illustrations.dart` | Rutas de las 29 ilustraciones y de las 2 infografías, por grupo y por rol |
| `saludconecta/assets/illustrations/doctor_1..7.svg`, `patient_1..6.svg` | Avatares generados |
| `saludconecta/assets/illustrations/*.svg` (16 más) | Logo, bienvenida, roles, fondos de videollamada, estados vacíos, soporte y aseguradoras |
| `saludconecta/lib/core/widgets/app_illustration.dart` | `AppIllustration` |
| `saludconecta/lib/core/widgets/avatar_image.dart` | `AvatarImage` + `initialsOf` |
| `saludconecta/lib/features/shared/illustrations_gallery.dart` | Galería de imágenes |
| `saludconecta/lib/features/auth/welcome_screen.dart` | Pantalla provisional con la galería |
| `saludconecta/test/support/svg_checks.dart` | `expectValidSvg(path)` |
| `saludconecta/test/core/app_illustrations_test.dart`, `test/assets/avatars_test.dart`, `test/assets/scenes_test.dart`, `test/core/widgets/illustration_widgets_test.dart` | Pruebas |

---

### Task 1: Catálogo de ilustraciones e infografías

**Files:**
- Modify: `saludconecta/pubspec.yaml`
- Create: `saludconecta/assets/images/infografia_proceso.webp`, `saludconecta/assets/images/infografia_servicios.webp` (copias), carpeta `saludconecta/assets/illustrations/`
- Create: `saludconecta/lib/core/constants/app_illustrations.dart`
- Test: `saludconecta/test/core/app_illustrations_test.dart`

**Interfaces:**
- Consumes:
  - `UserRole` (etapa 2);
  - de `SeedCatalog` (etapa 2): `doctors`, `demoPatients`, `insurers` y `staff`, para comprobar que sus rutas existen en el catálogo.
- Produces (todas `String`, constantes):
  - **Ilustraciones sueltas en `AppIllustrations`:**

    | Grupo | Constantes |
    |---|---|
    | Logo | `logo` |
    | Bienvenida | `onboardingRequest`, `onboardingConsult`, `onboardingFollowUp` |
    | Roles | `rolePatient`, `roleAdmission`, `roleDoctor`, `roleBilling` |
    | Fondos de videollamada | `roomClinic`, `roomHome` |
    | Estados vacíos | `emptyCases`, `emptyResults` |
    | Soporte | `support` |
    | Aseguradoras | `insurerSaludPlena`, `insurerVidaSegura`, `insurerFamiliaSana` |

  - **Listas (`List<String>`):** `doctors` (7), `patients` (6), `scenes` (13), `insurers` (3), `all` (29) y `onboarding` (3).
  - **Infografías:** `processInfographic` y `servicesInfographic`.
  - **`AppIllustrations.forRole(UserRole) → String`.**

- [ ] **Step 1: Escribir la prueba del catálogo**

Create `saludconecta/test/core/app_illustrations_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/constants/app_illustrations.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';

void main() {
  test('el catálogo tiene las 29 ilustraciones del spec, sin repetir', () {
    expect(AppIllustrations.all, hasLength(29));
    expect(AppIllustrations.all.toSet(), hasLength(29));
    expect(AppIllustrations.doctors, hasLength(7));
    expect(AppIllustrations.patients, hasLength(6));
    expect(AppIllustrations.scenes, hasLength(13));
    expect(AppIllustrations.insurers, hasLength(3));
    expect(AppIllustrations.onboarding, hasLength(3));
  });

  test('cada rol tiene su ilustración', () {
    for (final role in UserRole.values) {
      expect(AppIllustrations.all, contains(AppIllustrations.forRole(role)), reason: role.label);
    }
  });

  test('los datos semilla solo usan ilustraciones del catálogo', () {
    final referenced = <String>[
      for (final d in SeedCatalog.doctors) d.avatarAsset,
      for (final p in SeedCatalog.demoPatients) p.avatarAsset!,
      for (final i in SeedCatalog.insurers) i.symbolAsset,
      for (final s in SeedCatalog.staff)
        if (s.avatarAsset != null) s.avatarAsset!,
    ];
    expect(referenced, hasLength(7 + 6 + 3 + 1));
    for (final path in referenced) {
      expect(AppIllustrations.all, contains(path), reason: path);
    }
  });

  test('las 2 infografías del equipo están en los assets', () {
    expect(File(AppIllustrations.processInfographic).existsSync(), isTrue);
    expect(File(AppIllustrations.servicesInfographic).existsSync(), isTrue);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/core/app_illustrations_test.dart
```

Expected: FAIL. No compila porque `app_illustrations.dart` no existe.

- [ ] **Step 3: Copiar las infografías y declarar los assets**

```powershell
$repo = 'C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial'
New-Item -ItemType Directory -Force "$repo\saludconecta\assets\images", "$repo\saludconecta\assets\illustrations" | Out-Null
Copy-Item "$repo\docs\infografias\infografia_proceso.webp" "$repo\saludconecta\assets\images\"
Copy-Item "$repo\docs\infografias\infografia_servicios.webp" "$repo\saludconecta\assets\images\"
```

En `saludconecta/pubspec.yaml`, reemplazar la línea:

```yaml
  uses-material-design: true
```

por:

```yaml
  uses-material-design: true

  # Ilustraciones SVG propias e infografías del equipo.
  assets:
    - assets/illustrations/
    - assets/images/
```

- [ ] **Step 4: Crear el catálogo**

Create `saludconecta/lib/core/constants/app_illustrations.dart`:

```dart
import '../../domain/models/enums.dart';

/// Rutas de todas las imágenes de la app (§9 del spec). La UI usa estas constantes,
/// nunca rutas escritas a mano.
class AppIllustrations {
  const AppIllustrations._();

  static const _dir = 'assets/illustrations';

  static const logo = '$_dir/logo.svg';

  // Bienvenida.
  static const onboardingRequest = '$_dir/onboarding_request.svg';
  static const onboardingConsult = '$_dir/onboarding_consult.svg';
  static const onboardingFollowUp = '$_dir/onboarding_followup.svg';

  // Selección de rol.
  static const rolePatient = '$_dir/role_patient.svg';
  static const roleAdmission = '$_dir/role_admission.svg';
  static const roleDoctor = '$_dir/role_doctor.svg';
  static const roleBilling = '$_dir/role_billing.svg';

  // Fondos de la videollamada: consultorio (detrás del médico) y casa (detrás del paciente).
  static const roomClinic = '$_dir/room_clinic.svg';
  static const roomHome = '$_dir/room_home.svg';

  // Estados vacíos.
  static const emptyCases = '$_dir/empty_cases.svg';
  static const emptyResults = '$_dir/empty_results.svg';

  /// Soporte TI (sala de espera).
  static const support = '$_dir/support.svg';

  // Símbolos de las aseguradoras ficticias (sin texto; el nombre se escribe con Text).
  static const insurerSaludPlena = '$_dir/insurer_salud_plena.svg';
  static const insurerVidaSegura = '$_dir/insurer_vida_segura.svg';
  static const insurerFamiliaSana = '$_dir/insurer_familia_sana.svg';

  /// Avatares de los 7 médicos, en el orden de `SeedCatalog.doctors`.
  static const doctors = [
    '$_dir/doctor_1.svg',
    '$_dir/doctor_2.svg',
    '$_dir/doctor_3.svg',
    '$_dir/doctor_4.svg',
    '$_dir/doctor_5.svg',
    '$_dir/doctor_6.svg',
    '$_dir/doctor_7.svg',
  ];

  /// Avatares de los 6 pacientes de demostración, en el orden de `SeedCatalog.demoPatients`.
  static const patients = [
    '$_dir/patient_1.svg',
    '$_dir/patient_2.svg',
    '$_dir/patient_3.svg',
    '$_dir/patient_4.svg',
    '$_dir/patient_5.svg',
    '$_dir/patient_6.svg',
  ];

  /// Escenas e íconos dibujados a mano.
  static const scenes = [
    logo,
    onboardingRequest,
    onboardingConsult,
    onboardingFollowUp,
    rolePatient,
    roleAdmission,
    roleDoctor,
    roleBilling,
    roomClinic,
    roomHome,
    emptyCases,
    emptyResults,
    support,
  ];

  static const insurers = [insurerSaludPlena, insurerVidaSegura, insurerFamiliaSana];

  /// Las 29 ilustraciones.
  static const all = [...scenes, ...insurers, ...doctors, ...patients];

  /// Las 3 páginas de la bienvenida, en orden.
  static const onboarding = [onboardingRequest, onboardingConsult, onboardingFollowUp];

  // Infografías del equipo (WebP).
  static const processInfographic = 'assets/images/infografia_proceso.webp';
  static const servicesInfographic = 'assets/images/infografia_servicios.webp';

  /// Ilustración de la tarjeta de cada rol.
  static String forRole(UserRole role) => switch (role) {
        UserRole.patient => rolePatient,
        UserRole.admission => roleAdmission,
        UserRole.doctor => roleDoctor,
        UserRole.billing => roleBilling,
      };
}
```

- [ ] **Step 5: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/core/app_illustrations_test.dart
```

Expected: `All tests passed!` (4 pruebas).

---

### Task 2: Avatares de médicos y pacientes

**Files:**
- Create (fuera del repositorio): `generar_avatares.dart` en el scratchpad de la sesión
- Create: `saludconecta/test/support/svg_checks.dart`, `saludconecta/test/assets/avatars_test.dart`
- Create (generados): `saludconecta/assets/illustrations/doctor_1.svg` … `doctor_7.svg`, `patient_1.svg` … `patient_6.svg`

**Interfaces:**
- Consumes: `AppIllustrations.doctors` y `AppIllustrations.patients`.
- Produces:
  - `expectValidSvg(String path) → Future<void>`, en las pruebas;
  - los 13 avatares (`viewBox` de 128 × 128, recortados en círculo).

| Archivo | Persona | Rasgos |
|---|---|---|
| `doctor_1.svg` | Dr. Carlos Méndez | Bata, lentes, pelo corto oscuro, camisa azul |
| `doctor_2.svg` | Dra. Laura Jiménez | Bata, pelo largo castaño, camisa verde azulado |
| `doctor_3.svg` | Dr. Andrés Rosario | Bata, piel oscura, bigote, camisa verde |
| `doctor_4.svg` | Dra. Patricia Núñez | Bata, moño, camisa morada |
| `doctor_5.svg` | Dr. Miguel Santana | Bata, lentes, pelo gris, camisa roja |
| `doctor_6.svg` | Lic. Sofía Herrera | Pelo rizado, blusa violeta (sin bata) |
| `doctor_7.svg` | Lic. Daniela Cruz | Cola de caballo, blusa verde claro (sin bata) |
| `patient_1.svg` | María Fernández | Pelo largo oscuro, blusa verde |
| `patient_2.svg` | José Martínez | Pelo corto, bigote, camisa azul |
| `patient_3.svg` | Carmen Reyes | Melena gris, lentes, blusa fucsia |
| `patient_4.svg` | Pedro Almonte | Calvo, camisa índigo |
| `patient_5.svg` | Luisa Gómez | Moño, blusa verde azulado |
| `patient_6.svg` | Ramón Ortiz | Pelo gris, lentes, bigote, camisa gris azulado |

- [ ] **Step 1: Escribir el ayudante y la prueba de los avatares**

Create `saludconecta/test/support/svg_checks.dart`:

```dart
import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Elementos que las ilustraciones no deben usar (flutter_svg no los dibuja o el spec los prohíbe).
const unsupportedSvgElements = ['<text', '<filter', '<mask', '<style', '<image', '<script', '<foreignObject'];

/// Verifica que [path] exista, que respete las restricciones del spec y que flutter_svg lo interprete.
Future<void> expectValidSvg(String path) async {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'falta $path');
  final svg = file.readAsStringSync();
  expect(svg, contains('viewBox'), reason: '$path no tiene viewBox');
  for (final element in unsupportedSvgElements) {
    expect(svg.contains(element), isFalse, reason: '$path usa $element');
  }
  // Lo compila el mismo código que usa SvgPicture: si el SVG está mal escrito, aquí falla.
  final bytes = await SvgStringLoader(svg).loadBytes(null);
  expect(bytes.lengthInBytes, greaterThan(0), reason: path);
}
```

Create `saludconecta/test/assets/avatars_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/constants/app_illustrations.dart';

import '../support/svg_checks.dart';

void main() {
  for (final path in [...AppIllustrations.doctors, ...AppIllustrations.patients]) {
    test('avatar válido: $path', () => expectValidSvg(path));
  }
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/assets/avatars_test.dart
```

Expected: FAIL (13 pruebas fallan con `falta assets/illustrations/doctor_1.svg`, etc.).

- [ ] **Step 3: Crear el generador de avatares (fuera del repositorio)**

Create `generar_avatares.dart` en el scratchpad de la sesión (por ejemplo, `<scratchpad>\generar_avatares.dart`):

```dart
// Genera los 13 avatares SVG de SaludConecta: 7 médicos (doctor_1…7) y 6 pacientes (patient_1…6).
// Vive fuera del proyecto Flutter; solo se versionan los SVG que produce.
// Uso: dart run generar_avatares.dart <carpeta de salida>
import 'dart:io';

class Avatar {
  const Avatar(
    this.file, {
    required this.skin,
    required this.hair,
    required this.hairStyle,
    required this.shirt,
    required this.background,
    this.glasses = false,
    this.mustache = false,
    this.coat = false,
  });

  final String file;
  final String skin;
  final String hair;

  /// short, long, bun, curly, bob, bald o ponytail.
  final String hairStyle;
  final String shirt;
  final String background;
  final bool glasses;
  final bool mustache;

  /// Bata blanca con estetoscopio (médicos).
  final bool coat;
}

const avatars = <Avatar>[
  // Médicos.
  Avatar('doctor_1.svg', skin: '#E0A979', hair: '#2B2B2B', hairStyle: 'short', shirt: '#1565C0',
      background: '#E3F2FD', glasses: true, coat: true), // Dr. Carlos Méndez
  Avatar('doctor_2.svg', skin: '#F2C9A0', hair: '#4E342E', hairStyle: 'long', shirt: '#00897B',
      background: '#E0F2F1', coat: true), // Dra. Laura Jiménez
  Avatar('doctor_3.svg', skin: '#8D5524', hair: '#1B1B1B', hairStyle: 'short', shirt: '#43A047',
      background: '#E8F5E9', mustache: true, coat: true), // Dr. Andrés Rosario
  Avatar('doctor_4.svg', skin: '#C68642', hair: '#2B2B2B', hairStyle: 'bun', shirt: '#7B1FA2',
      background: '#F3E5F5', coat: true), // Dra. Patricia Núñez
  Avatar('doctor_5.svg', skin: '#F2C9A0', hair: '#9E9E9E', hairStyle: 'short', shirt: '#C62828',
      background: '#FFEBEE', glasses: true, coat: true), // Dr. Miguel Santana
  Avatar('doctor_6.svg', skin: '#E0A979', hair: '#6D4C41', hairStyle: 'curly', shirt: '#5E35B1',
      background: '#EDE7F6'), // Lic. Sofía Herrera
  Avatar('doctor_7.svg', skin: '#F2C9A0', hair: '#A0522D', hairStyle: 'ponytail', shirt: '#7CB342',
      background: '#F1F8E9'), // Lic. Daniela Cruz
  // Pacientes.
  Avatar('patient_1.svg', skin: '#E0A979', hair: '#3E2723', hairStyle: 'long', shirt: '#43A047',
      background: '#E8F5E9'), // María Fernández
  Avatar('patient_2.svg', skin: '#C68642', hair: '#2B2B2B', hairStyle: 'short', shirt: '#1E88E5',
      background: '#E3F2FD', mustache: true), // José Martínez
  Avatar('patient_3.svg', skin: '#F2C9A0', hair: '#BDBDBD', hairStyle: 'bob', shirt: '#AD1457',
      background: '#FCE4EC', glasses: true), // Carmen Reyes
  Avatar('patient_4.svg', skin: '#8D5524', hair: '#2B2B2B', hairStyle: 'bald', shirt: '#283593',
      background: '#E8EAF6'), // Pedro Almonte
  Avatar('patient_5.svg', skin: '#F2C9A0', hair: '#6D4C41', hairStyle: 'bun', shirt: '#00897B',
      background: '#E0F2F1'), // Luisa Gómez
  Avatar('patient_6.svg', skin: '#E0A979', hair: '#9E9E9E', hairStyle: 'short', shirt: '#546E7A',
      background: '#ECEFF1', glasses: true, mustache: true), // Ramón Ortiz
];

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Uso: dart run generar_avatares.dart <carpeta de salida>');
    exit(64);
  }
  final out = Directory(args.first)..createSync(recursive: true);
  for (final avatar in avatars) {
    File('${out.path}/${avatar.file}').writeAsStringSync(svgFor(avatar));
    stdout.writeln('generado ${avatar.file}');
  }
}

/// Orden de dibujo: pelo de atrás, cuello, cuerpo, orejas, cabeza, pelo de adelante y cara.
String svgFor(Avatar a) {
  final parts = <String>[
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">',
    '  <defs><clipPath id="marco"><circle cx="64" cy="64" r="64"/></clipPath></defs>',
    '  <circle cx="64" cy="64" r="64" fill="${a.background}"/>',
    '  <g clip-path="url(#marco)">',
    ...backHair(a),
    '    <rect x="55" y="70" width="18" height="24" rx="8" fill="${a.skin}"/>',
    ...body(a),
    '    <ellipse cx="42" cy="58" rx="4" ry="6" fill="${a.skin}"/>',
    '    <ellipse cx="86" cy="58" rx="4" ry="6" fill="${a.skin}"/>',
    '    <ellipse cx="64" cy="56" rx="22" ry="25" fill="${a.skin}"/>',
    ...frontHair(a),
    ...face(a),
    '  </g>',
    '</svg>',
  ];
  return '${parts.join('\n')}\n';
}

List<String> backHair(Avatar a) => switch (a.hairStyle) {
      'long' => [
          '    <path d="M38 58 C38 34 50 25 64 25 C78 25 90 34 90 58 L92 98 C80 104 48 104 36 98 Z" fill="${a.hair}"/>',
        ],
      'bob' => [
          '    <path d="M38 60 C38 34 50 26 64 26 C78 26 90 34 90 60 L90 78 C80 83 48 83 38 78 Z" fill="${a.hair}"/>',
        ],
      'bun' => ['    <circle cx="64" cy="25" r="12" fill="${a.hair}"/>'],
      'ponytail' => ['    <path d="M82 38 C100 42 104 70 94 90 C90 74 88 56 82 38 Z" fill="${a.hair}"/>'],
      'curly' => [
          for (final (x, y, r) in [(44, 42, 12), (56, 31, 13), (72, 31, 13), (84, 42, 12), (40, 58, 10), (88, 58, 10)])
            '    <circle cx="$x" cy="$y" r="$r" fill="${a.hair}"/>',
        ],
      _ => const <String>[],
    };

List<String> body(Avatar a) {
  const shoulders = 'M22 128 C22 100 40 88 64 88 C88 88 106 100 106 128 Z';
  if (!a.coat) {
    return [
      '    <path d="$shoulders" fill="${a.shirt}"/>',
      '    <path d="M53 89 Q64 102 75 89 Z" fill="${a.skin}"/>',
    ];
  }
  // Bata blanca, camisa en V, solapas, estetoscopio y bolsillo.
  return [
    '    <path d="$shoulders" fill="#FFFFFF" stroke="#CFD8DC" stroke-width="2"/>',
    '    <path d="M53 89 L64 110 L75 89 Z" fill="${a.shirt}"/>',
    '    <path d="M53 89 L59 128 M75 89 L69 128" fill="none" stroke="#B0BEC5" stroke-width="2"/>',
    '    <path d="M50 93 C45 105 51 115 60 117" fill="none" stroke="#546E7A" stroke-width="3" stroke-linecap="round"/>',
    '    <circle cx="61" cy="118" r="4" fill="#546E7A"/>',
    '    <path d="M78 93 C82 101 81 107 77 111" fill="none" stroke="#546E7A" stroke-width="3" stroke-linecap="round"/>',
    '    <rect x="80" y="108" width="13" height="10" rx="2" fill="none" stroke="#B0BEC5" stroke-width="2"/>',
  ];
}

List<String> frontHair(Avatar a) => switch (a.hairStyle) {
      'short' || 'bun' || 'ponytail' => [
          '    <path d="M41 54 C40 36 51 28 64 28 C78 28 88 36 87 54 C82 45 74 41 64 41 C54 41 46 45 41 54 Z" fill="${a.hair}"/>',
        ],
      'long' => [
          '    <path d="M41 53 C42 36 52 29 64 29 C77 29 87 36 87 53 C80 43 71 39 64 39 C57 45 49 50 41 53 Z" fill="${a.hair}"/>',
        ],
      'bob' => ['    <path d="M42 50 C42 36 52 29 64 29 C76 29 86 36 86 50 Z" fill="${a.hair}"/>'],
      'curly' => [
          for (final (x, y, r) in [(52, 36, 9), (64, 32, 10), (76, 36, 9)])
            '    <circle cx="$x" cy="$y" r="$r" fill="${a.hair}"/>',
        ],
      'bald' => [
          '    <path d="M42 62 C41 52 43 45 47 42 C46 50 46 56 47 63 Z" fill="${a.hair}"/>',
          '    <path d="M86 62 C87 52 85 45 81 42 C82 50 82 56 81 63 Z" fill="${a.hair}"/>',
        ],
      _ => const <String>[],
    };

List<String> face(Avatar a) => [
      '    <circle cx="56" cy="58" r="2.6" fill="#263238"/>',
      '    <circle cx="72" cy="58" r="2.6" fill="#263238"/>',
      '    <circle cx="50" cy="66" r="3.5" fill="#F48FB1" fill-opacity="0.35"/>',
      '    <circle cx="78" cy="66" r="3.5" fill="#F48FB1" fill-opacity="0.35"/>',
      if (a.mustache) '    <path d="M55 66 Q64 61 73 66 Q64 69 55 66 Z" fill="${a.hair}"/>',
      if (a.mustache)
        '    <path d="M58 71 Q64 75 70 71" fill="none" stroke="#263238" stroke-width="2.4" stroke-linecap="round"/>'
      else
        '    <path d="M57 67 Q64 73 71 67" fill="none" stroke="#263238" stroke-width="2.4" stroke-linecap="round"/>',
      if (a.glasses) ...[
        '    <circle cx="56" cy="58" r="7" fill="none" stroke="#37474F" stroke-width="2.4"/>',
        '    <circle cx="72" cy="58" r="7" fill="none" stroke="#37474F" stroke-width="2.4"/>',
        '    <path d="M63 58 H65" fill="none" stroke="#37474F" stroke-width="2.4"/>',
      ],
    ];
```

- [ ] **Step 4: Generar los avatares**

```powershell
$dart = 'C:\Users\Helen\dev\flutter\bin\dart.bat'
& $dart run <scratchpad>\generar_avatares.dart C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta\assets\illustrations
```

Expected: 13 líneas `generado …svg`.

- [ ] **Step 5: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/assets/avatars_test.dart
```

Expected: `All tests passed!` (13 pruebas).

---

### Task 3: Escenas, íconos y símbolos de las aseguradoras

**Files:**
- Create: `saludconecta/test/assets/scenes_test.dart`
- Create: los 16 SVG de abajo, en `saludconecta/assets/illustrations/`

**Interfaces:**
- Consumes: `AppIllustrations.scenes`, `AppIllustrations.insurers` y `expectValidSvg`.
- Produces: 16 SVG.

  | Grupo | `viewBox` | Archivos |
  |---|---|---|
  | Logo | 128 × 128 | `logo` |
  | Bienvenida | 400 × 300 | `onboarding_request`, `onboarding_consult`, `onboarding_followup` |
  | Roles y soporte | 200 × 160 | `role_patient`, `role_admission`, `role_doctor`, `role_billing`, `support` |
  | Fondos de videollamada (verticales) | 400 × 600 | `room_clinic`, `room_home` |
  | Estados vacíos | 240 × 180 | `empty_cases`, `empty_results` |
  | Aseguradoras | 64 × 64 | `insurer_salud_plena`, `insurer_vida_segura`, `insurer_familia_sana` |

- [ ] **Step 1: Escribir la prueba de las escenas**

Create `saludconecta/test/assets/scenes_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/constants/app_illustrations.dart';

import '../support/svg_checks.dart';

void main() {
  for (final path in [...AppIllustrations.scenes, ...AppIllustrations.insurers]) {
    test('ilustración válida: $path', () => expectValidSvg(path));
  }
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/assets/scenes_test.dart
```

Expected: FAIL (16 pruebas fallan con `falta assets/illustrations/…`).

- [ ] **Step 3: Crear el logo y la bienvenida**

Create `saludconecta/assets/illustrations/logo.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect x="10" y="22" width="88" height="96" rx="16" fill="#1565C0"/>
  <rect x="18" y="30" width="72" height="72" rx="9" fill="#E3F2FD"/>
  <circle cx="54" cy="110" r="3.5" fill="#90CAF9"/>
  <circle cx="54" cy="57" r="12" fill="#1565C0"/>
  <path d="M32 96 C32 82 42 74 54 74 C66 74 76 82 76 96 Z" fill="#1565C0"/>
  <circle cx="98" cy="32" r="24" fill="#FFFFFF"/>
  <circle cx="98" cy="32" r="19" fill="#00897B"/>
  <rect x="94" y="21" width="8" height="22" rx="2" fill="#FFFFFF"/>
  <rect x="87" y="28" width="22" height="8" rx="2" fill="#FFFFFF"/>
</svg>
```

Create `saludconecta/assets/illustrations/onboarding_request.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300">
  <ellipse cx="200" cy="156" rx="178" ry="122" fill="#E3F2FD"/>
  <circle cx="58" cy="40" r="6" fill="#F9A825"/>
  <circle cx="352" cy="262" r="5" fill="#F9A825"/>
  <circle cx="352" cy="36" r="4" fill="#00897B"/>
  <rect x="140" y="40" width="120" height="226" rx="22" fill="#0D3B66"/>
  <rect x="150" y="58" width="100" height="190" rx="12" fill="#FFFFFF"/>
  <rect x="184" y="47" width="32" height="5" rx="2.5" fill="#1565C0"/>
  <rect x="160" y="74" width="62" height="22" rx="11" fill="#E0F2F1"/>
  <rect x="178" y="104" width="62" height="22" rx="11" fill="#1565C0"/>
  <rect x="160" y="134" width="50" height="22" rx="11" fill="#E0F2F1"/>
  <rect x="160" y="168" width="80" height="62" rx="10" fill="#E3F2FD"/>
  <rect x="168" y="176" width="26" height="26" rx="6" fill="#00897B"/>
  <rect x="174" y="183" width="14" height="3" rx="1.5" fill="#FFFFFF"/>
  <rect x="174" y="189" width="14" height="3" rx="1.5" fill="#FFFFFF"/>
  <rect x="174" y="195" width="9" height="3" rx="1.5" fill="#FFFFFF"/>
  <rect x="200" y="178" width="32" height="5" rx="2.5" fill="#90CAF9"/>
  <rect x="200" y="188" width="24" height="5" rx="2.5" fill="#90CAF9"/>
  <rect x="168" y="210" width="64" height="12" rx="6" fill="#1565C0"/>
  <circle cx="84" cy="96" r="32" fill="#43A047"/>
  <path d="M70 84 H98 A6 6 0 0 1 104 90 V102 A6 6 0 0 1 98 108 H82 L74 116 V108 H70 A6 6 0 0 1 64 102 V90 A6 6 0 0 1 70 84 Z" fill="#FFFFFF"/>
  <circle cx="76" cy="96" r="3" fill="#43A047"/>
  <circle cx="84" cy="96" r="3" fill="#43A047"/>
  <circle cx="92" cy="96" r="3" fill="#43A047"/>
  <circle cx="318" cy="92" r="30" fill="#1E88E5"/>
  <rect x="300" y="80" width="36" height="25" rx="4" fill="#FFFFFF"/>
  <path d="M302 83 L318 95 L334 83" fill="none" stroke="#1E88E5" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="320" cy="206" r="30" fill="#00897B"/>
  <circle cx="320" cy="206" r="15" fill="none" stroke="#FFFFFF" stroke-width="3"/>
  <ellipse cx="320" cy="206" rx="6.5" ry="15" fill="none" stroke="#FFFFFF" stroke-width="3"/>
  <path d="M305 206 H335" fill="none" stroke="#FFFFFF" stroke-width="3"/>
  <circle cx="82" cy="210" r="30" fill="#283593"/>
  <path d="M71 198 C71 196 73 194 75 194 H80 L83 203 L79 206 C81 211 85 215 90 217 L93 213 L102 216 V221 C102 223 100 225 98 225 C83 225 71 213 71 198 Z" fill="#FFFFFF"/>
  <circle cx="122" cy="110" r="3" fill="#90CAF9"/>
  <circle cx="131" cy="118" r="3" fill="#90CAF9"/>
  <circle cx="278" cy="108" r="3" fill="#90CAF9"/>
  <circle cx="269" cy="116" r="3" fill="#90CAF9"/>
  <circle cx="122" cy="200" r="3" fill="#90CAF9"/>
  <circle cx="131" cy="193" r="3" fill="#90CAF9"/>
  <circle cx="280" cy="200" r="3" fill="#90CAF9"/>
  <circle cx="270" cy="194" r="3" fill="#90CAF9"/>
</svg>
```

Create `saludconecta/assets/illustrations/onboarding_consult.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300">
  <ellipse cx="200" cy="158" rx="178" ry="120" fill="#E0F2F1"/>
  <path d="M24 60 H44 L52 42 L62 78 L70 60 H90" fill="none" stroke="#00897B" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="358" cy="56" r="6" fill="#F9A825"/>
  <circle cx="40" cy="236" r="5" fill="#1565C0"/>
  <ellipse cx="342" cy="182" rx="11" ry="26" fill="#43A047"/>
  <ellipse cx="328" cy="192" rx="8" ry="20" fill="#66BB6A" transform="rotate(-28 328 192)"/>
  <ellipse cx="356" cy="192" rx="8" ry="20" fill="#66BB6A" transform="rotate(28 356 192)"/>
  <rect x="326" y="204" width="32" height="34" rx="6" fill="#00897B"/>
  <rect x="92" y="54" width="216" height="148" rx="12" fill="#0D3B66"/>
  <rect x="102" y="64" width="196" height="128" rx="6" fill="#BBDEFB"/>
  <rect x="118" y="78" width="48" height="38" rx="4" fill="#E3F2FD"/>
  <rect x="140" y="78" width="4" height="38" fill="#BBDEFB"/>
  <path d="M160 192 C160 160 176 146 200 146 C224 146 240 160 240 192 Z" fill="#FFFFFF"/>
  <path d="M191 147 L200 166 L209 147 Z" fill="#00897B"/>
  <path d="M187 152 C184 164 188 174 196 176" fill="none" stroke="#546E7A" stroke-width="3" stroke-linecap="round"/>
  <circle cx="197" cy="177" r="3.5" fill="#546E7A"/>
  <rect x="192" y="124" width="16" height="24" rx="7" fill="#E0A979"/>
  <ellipse cx="200" cy="112" rx="17" ry="20" fill="#E0A979"/>
  <path d="M183 108 C182 94 190 88 200 88 C211 88 219 94 217 108 C213 100 207 97 200 97 C193 97 187 101 183 108 Z" fill="#2B2B2B"/>
  <circle cx="194" cy="113" r="2.2" fill="#263238"/>
  <circle cx="206" cy="113" r="2.2" fill="#263238"/>
  <path d="M195 121 Q200 125 205 121" fill="none" stroke="#263238" stroke-width="2" stroke-linecap="round"/>
  <path d="M234 170 C240 158 244 148 246 140" fill="none" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round"/>
  <circle cx="247" cy="134" r="8" fill="#E0A979"/>
  <rect x="252" y="72" width="40" height="34" rx="5" fill="#FFFFFF"/>
  <path d="M258 106 C258 97 264 93 272 93 C280 93 286 97 286 106 Z" fill="#43A047"/>
  <circle cx="272" cy="85" r="7" fill="#C68642"/>
  <rect x="158" y="166" width="84" height="20" rx="10" fill="#0D3B66" fill-opacity="0.85"/>
  <circle cx="174" cy="176" r="5" fill="#FFFFFF"/>
  <circle cx="192" cy="176" r="5" fill="#FFFFFF"/>
  <circle cx="210" cy="176" r="5" fill="#FFFFFF"/>
  <circle cx="228" cy="176" r="6" fill="#E53935"/>
  <path d="M66 202 H334 L316 222 H84 Z" fill="#90A4AE"/>
  <rect x="176" y="202" width="48" height="5" rx="2.5" fill="#CFD8DC"/>
</svg>
```

Create `saludconecta/assets/illustrations/onboarding_followup.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300">
  <ellipse cx="200" cy="158" rx="178" ry="120" fill="#E8F5E9"/>
  <circle cx="60" cy="60" r="6" fill="#F9A825"/>
  <circle cx="348" cy="70" r="4" fill="#1565C0"/>
  <rect x="122" y="36" width="150" height="208" rx="12" fill="#FFFFFF"/>
  <path d="M122 48 A12 12 0 0 1 134 36 H260 A12 12 0 0 1 272 48 V72 H122 Z" fill="#1565C0"/>
  <rect x="135" y="45" width="6" height="18" rx="1.5" fill="#FFFFFF"/>
  <rect x="129" y="51" width="18" height="6" rx="1.5" fill="#FFFFFF"/>
  <rect x="158" y="48" width="90" height="6" rx="3" fill="#90CAF9"/>
  <rect x="158" y="58" width="60" height="6" rx="3" fill="#90CAF9"/>
  <rect x="138" y="88" width="118" height="7" rx="3.5" fill="#E3F2FD"/>
  <rect x="138" y="102" width="96" height="7" rx="3.5" fill="#E3F2FD"/>
  <rect x="138" y="116" width="108" height="7" rx="3.5" fill="#E3F2FD"/>
  <rect x="138" y="140" width="44" height="18" rx="9" fill="#80CBC4"/>
  <path d="M147 140 H160 V158 H147 A9 9 0 0 1 147 140 Z" fill="#00897B"/>
  <rect x="200" y="172" width="58" height="58" rx="6" fill="#FFFFFF" stroke="#CFD8DC" stroke-width="2"/>
  <rect x="206" y="178" width="16" height="16" rx="2" fill="#0D3B66"/>
  <rect x="210" y="182" width="8" height="8" fill="#FFFFFF"/>
  <rect x="236" y="178" width="16" height="16" rx="2" fill="#0D3B66"/>
  <rect x="240" y="182" width="8" height="8" fill="#FFFFFF"/>
  <rect x="206" y="208" width="16" height="16" rx="2" fill="#0D3B66"/>
  <rect x="210" y="212" width="8" height="8" fill="#FFFFFF"/>
  <rect x="228" y="200" width="6" height="6" fill="#0D3B66"/>
  <rect x="238" y="208" width="6" height="6" fill="#0D3B66"/>
  <rect x="246" y="216" width="6" height="6" fill="#0D3B66"/>
  <rect x="228" y="216" width="6" height="6" fill="#0D3B66"/>
  <rect x="246" y="200" width="6" height="6" fill="#0D3B66"/>
  <path d="M138 214 C146 202 152 226 160 212 C166 202 170 222 180 210" fill="none" stroke="#0D3B66" stroke-width="2.5" stroke-linecap="round"/>
  <rect x="290" y="146" width="56" height="80" rx="10" fill="#F9A825"/>
  <rect x="285" y="130" width="66" height="22" rx="6" fill="#FFFFFF" stroke="#F9A825" stroke-width="3"/>
  <rect x="298" y="170" width="40" height="34" rx="5" fill="#FFF8E1"/>
  <rect x="315" y="176" width="6" height="22" rx="1.5" fill="#E53935"/>
  <rect x="307" y="184" width="22" height="6" rx="1.5" fill="#E53935"/>
  <rect x="44" y="126" width="72" height="70" rx="10" fill="#FFFFFF"/>
  <path d="M44 136 A10 10 0 0 1 54 126 H106 A10 10 0 0 1 116 136 V146 H44 Z" fill="#43A047"/>
  <rect x="58" y="118" width="6" height="16" rx="3" fill="#0D3B66"/>
  <rect x="96" y="118" width="6" height="16" rx="3" fill="#0D3B66"/>
  <circle cx="80" cy="170" r="15" fill="#43A047"/>
  <path d="M72 170 L78 176 L89 164" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

- [ ] **Step 4: Crear las ilustraciones de los roles y de soporte**

Create `saludconecta/assets/illustrations/role_patient.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 160">
  <circle cx="100" cy="88" r="66" fill="#E8F5E9"/>
  <circle cx="32" cy="34" r="5" fill="#F9A825"/>
  <path d="M74 64 C74 40 86 30 100 30 C114 30 126 40 126 64 L128 100 C116 106 84 106 72 100 Z" fill="#3E2723"/>
  <rect x="91" y="86" width="18" height="22" rx="8" fill="#E0A979"/>
  <path d="M52 160 C52 124 72 106 100 106 C128 106 148 124 148 160 Z" fill="#43A047"/>
  <path d="M90 107 Q100 118 110 107 Z" fill="#E0A979"/>
  <ellipse cx="100" cy="68" rx="20" ry="23" fill="#E0A979"/>
  <path d="M80 66 C80 50 89 44 100 44 C111 44 121 50 120 66 C113 57 106 53 100 53 C95 58 88 62 80 66 Z" fill="#3E2723"/>
  <circle cx="93" cy="70" r="2.4" fill="#263238"/>
  <circle cx="107" cy="70" r="2.4" fill="#263238"/>
  <path d="M94 79 Q100 84 106 79" fill="none" stroke="#263238" stroke-width="2.2" stroke-linecap="round"/>
  <path d="M128 150 C132 140 134 132 134 124" fill="none" stroke="#43A047" stroke-width="12" stroke-linecap="round"/>
  <rect x="124" y="98" width="24" height="40" rx="5" fill="#0D3B66"/>
  <rect x="127" y="103" width="18" height="28" rx="2" fill="#BBDEFB"/>
  <circle cx="134" cy="132" r="7" fill="#E0A979"/>
  <circle cx="156" cy="48" r="20" fill="#FFFFFF"/>
  <path d="M156 58 C147 52 143 48 145 42 C147 36 154 36 156 42 C158 36 165 36 167 42 C169 48 165 52 156 58 Z" fill="#E53935"/>
</svg>
```

Create `saludconecta/assets/illustrations/role_admission.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 160">
  <circle cx="100" cy="86" r="66" fill="#E3F2FD"/>
  <circle cx="168" cy="30" r="5" fill="#F9A825"/>
  <rect x="81" y="70" width="18" height="20" rx="8" fill="#C68642"/>
  <path d="M44 132 C44 102 62 88 90 88 C118 88 136 102 136 132 Z" fill="#1E88E5"/>
  <path d="M80 89 Q90 100 100 89 Z" fill="#C68642"/>
  <ellipse cx="90" cy="54" rx="19" ry="22" fill="#C68642"/>
  <path d="M71 52 C70 36 79 30 90 30 C102 30 111 36 109 52 C104 44 97 41 90 41 C83 41 76 45 71 52 Z" fill="#2B2B2B"/>
  <circle cx="84" cy="56" r="2.3" fill="#263238"/>
  <circle cx="96" cy="56" r="2.3" fill="#263238"/>
  <path d="M85 64 Q90 68 95 64" fill="none" stroke="#263238" stroke-width="2" stroke-linecap="round"/>
  <path d="M70 54 C70 36 79 28 90 28 C101 28 110 36 110 54" fill="none" stroke="#0D3B66" stroke-width="4"/>
  <rect x="64" y="48" width="9" height="16" rx="4" fill="#0D3B66"/>
  <rect x="107" y="48" width="9" height="16" rx="4" fill="#0D3B66"/>
  <path d="M68 62 C68 72 74 76 82 76" fill="none" stroke="#0D3B66" stroke-width="3" stroke-linecap="round"/>
  <circle cx="83" cy="76" r="3.5" fill="#0D3B66"/>
  <rect x="24" y="128" width="152" height="12" rx="6" fill="#0D3B66"/>
  <rect x="118" y="78" width="60" height="42" rx="6" fill="#0D3B66"/>
  <rect x="123" y="83" width="50" height="32" rx="3" fill="#FFFFFF"/>
  <rect x="129" y="89" width="22" height="5" rx="2.5" fill="#90CAF9"/>
  <rect x="129" y="98" width="36" height="5" rx="2.5" fill="#BBDEFB"/>
  <rect x="129" y="107" width="28" height="5" rx="2.5" fill="#BBDEFB"/>
  <rect x="143" y="120" width="10" height="9" fill="#0D3B66"/>
  <circle cx="44" cy="44" r="18" fill="#FFFFFF"/>
  <rect x="41" y="34" width="6" height="20" rx="2" fill="#1E88E5"/>
  <rect x="34" y="41" width="20" height="6" rx="2" fill="#1E88E5"/>
</svg>
```

Create `saludconecta/assets/illustrations/role_doctor.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 160">
  <circle cx="100" cy="86" r="66" fill="#E0F2F1"/>
  <circle cx="34" cy="36" r="5" fill="#F9A825"/>
  <rect x="91" y="78" width="18" height="22" rx="8" fill="#F2C9A0"/>
  <path d="M50 160 C50 120 70 98 100 98 C130 98 150 120 150 160 Z" fill="#FFFFFF" stroke="#B2DFDB" stroke-width="2"/>
  <path d="M89 99 L100 122 L111 99 Z" fill="#00897B"/>
  <path d="M89 99 L95 160 M111 99 L105 160" fill="none" stroke="#B2DFDB" stroke-width="2"/>
  <path d="M84 104 C78 120 84 132 94 134" fill="none" stroke="#546E7A" stroke-width="3.5" stroke-linecap="round"/>
  <circle cx="96" cy="135" r="5" fill="#546E7A"/>
  <path d="M116 104 C120 112 120 118 116 124" fill="none" stroke="#546E7A" stroke-width="3.5" stroke-linecap="round"/>
  <ellipse cx="100" cy="60" rx="20" ry="23" fill="#F2C9A0"/>
  <path d="M80 58 C79 41 89 34 100 34 C112 34 122 41 120 58 C114 49 107 45 100 45 C93 45 86 49 80 58 Z" fill="#4E342E"/>
  <circle cx="93" cy="62" r="2.4" fill="#263238"/>
  <circle cx="107" cy="62" r="2.4" fill="#263238"/>
  <path d="M94 71 Q100 76 106 71" fill="none" stroke="#263238" stroke-width="2.2" stroke-linecap="round"/>
  <rect x="136" y="84" width="40" height="52" rx="6" fill="#0D3B66"/>
  <rect x="141" y="92" width="30" height="40" rx="3" fill="#FFFFFF"/>
  <rect x="148" y="80" width="16" height="9" rx="3" fill="#B0BEC5"/>
  <rect x="146" y="100" width="20" height="4" rx="2" fill="#80CBC4"/>
  <rect x="146" y="109" width="16" height="4" rx="2" fill="#B2DFDB"/>
  <rect x="146" y="118" width="18" height="4" rx="2" fill="#B2DFDB"/>
  <circle cx="160" cy="40" r="18" fill="#00897B"/>
  <rect x="157" y="30" width="6" height="20" rx="2" fill="#FFFFFF"/>
  <rect x="150" y="37" width="20" height="6" rx="2" fill="#FFFFFF"/>
</svg>
```

Create `saludconecta/assets/illustrations/role_billing.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 160">
  <circle cx="100" cy="86" r="66" fill="#E8EAF6"/>
  <circle cx="172" cy="28" r="5" fill="#F9A825"/>
  <path d="M58 26 H130 V138 L121 132 L112 138 L103 132 L94 138 L85 132 L76 138 L67 132 L58 138 Z" fill="#FFFFFF"/>
  <rect x="68" y="38" width="40" height="7" rx="3.5" fill="#283593"/>
  <rect x="68" y="56" width="52" height="5" rx="2.5" fill="#C5CAE9"/>
  <rect x="68" y="68" width="44" height="5" rx="2.5" fill="#C5CAE9"/>
  <rect x="68" y="80" width="48" height="5" rx="2.5" fill="#C5CAE9"/>
  <rect x="68" y="96" width="52" height="2" fill="#C5CAE9"/>
  <rect x="94" y="104" width="26" height="8" rx="4" fill="#283593"/>
  <rect x="26" y="86" width="42" height="56" rx="7" fill="#283593"/>
  <rect x="32" y="92" width="30" height="12" rx="2" fill="#E8EAF6"/>
  <circle cx="37" cy="114" r="3.5" fill="#FFFFFF"/>
  <circle cx="47" cy="114" r="3.5" fill="#FFFFFF"/>
  <circle cx="57" cy="114" r="3.5" fill="#FFFFFF"/>
  <circle cx="37" cy="126" r="3.5" fill="#FFFFFF"/>
  <circle cx="47" cy="126" r="3.5" fill="#FFFFFF"/>
  <circle cx="57" cy="126" r="3.5" fill="#F9A825"/>
  <circle cx="144" cy="106" r="26" fill="#F9A825"/>
  <circle cx="144" cy="106" r="20" fill="#FBC02D"/>
  <path d="M151 96 C147 92 137 93 137 100 C137 108 152 105 152 113 C152 120 141 121 136 116" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>
  <path d="M144 88 V124" fill="none" stroke="#FFFFFF" stroke-width="3.5" stroke-linecap="round"/>
  <circle cx="150" cy="44" r="16" fill="#43A047"/>
  <path d="M143 44 L148 49 L157 39" fill="none" stroke="#FFFFFF" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

Create `saludconecta/assets/illustrations/support.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 160">
  <circle cx="100" cy="86" r="66" fill="#F3E5F5"/>
  <circle cx="160" cy="38" r="15" fill="#7B1FA2"/>
  <rect x="156" y="17" width="8" height="10" rx="2" fill="#7B1FA2"/>
  <rect x="156" y="17" width="8" height="10" rx="2" fill="#7B1FA2" transform="rotate(45 160 38)"/>
  <rect x="156" y="17" width="8" height="10" rx="2" fill="#7B1FA2" transform="rotate(90 160 38)"/>
  <rect x="156" y="17" width="8" height="10" rx="2" fill="#7B1FA2" transform="rotate(135 160 38)"/>
  <rect x="156" y="17" width="8" height="10" rx="2" fill="#7B1FA2" transform="rotate(180 160 38)"/>
  <rect x="156" y="17" width="8" height="10" rx="2" fill="#7B1FA2" transform="rotate(225 160 38)"/>
  <rect x="156" y="17" width="8" height="10" rx="2" fill="#7B1FA2" transform="rotate(270 160 38)"/>
  <rect x="156" y="17" width="8" height="10" rx="2" fill="#7B1FA2" transform="rotate(315 160 38)"/>
  <circle cx="160" cy="38" r="6" fill="#F3E5F5"/>
  <rect x="81" y="70" width="18" height="22" rx="8" fill="#E0A979"/>
  <path d="M44 132 C44 102 62 88 90 88 C118 88 136 102 136 132 Z" fill="#7B1FA2"/>
  <path d="M80 89 Q90 100 100 89 Z" fill="#E0A979"/>
  <ellipse cx="90" cy="54" rx="19" ry="22" fill="#E0A979"/>
  <path d="M71 52 C70 36 79 30 90 30 C102 30 111 36 109 52 C104 44 97 41 90 41 C83 41 76 45 71 52 Z" fill="#4E342E"/>
  <circle cx="84" cy="56" r="2.3" fill="#263238"/>
  <circle cx="96" cy="56" r="2.3" fill="#263238"/>
  <path d="M85 64 Q90 68 95 64" fill="none" stroke="#263238" stroke-width="2" stroke-linecap="round"/>
  <path d="M70 54 C70 36 79 28 90 28 C101 28 110 36 110 54" fill="none" stroke="#0D3B66" stroke-width="4"/>
  <rect x="64" y="48" width="9" height="16" rx="4" fill="#0D3B66"/>
  <rect x="107" y="48" width="9" height="16" rx="4" fill="#0D3B66"/>
  <path d="M68 62 C68 72 74 76 82 76" fill="none" stroke="#0D3B66" stroke-width="3" stroke-linecap="round"/>
  <circle cx="83" cy="76" r="3.5" fill="#0D3B66"/>
  <rect x="24" y="128" width="152" height="12" rx="6" fill="#0D3B66"/>
  <rect x="112" y="88" width="62" height="40" rx="5" fill="#0D3B66"/>
  <rect x="117" y="93" width="52" height="30" rx="2" fill="#E1BEE7"/>
  <path d="M131 112 Q143 102 155 112" fill="none" stroke="#7B1FA2" stroke-width="3" stroke-linecap="round"/>
  <path d="M136 117 Q143 111 150 117" fill="none" stroke="#7B1FA2" stroke-width="3" stroke-linecap="round"/>
  <circle cx="143" cy="120" r="2.5" fill="#7B1FA2"/>
</svg>
```

- [ ] **Step 5: Crear los fondos de la videollamada y los estados vacíos**

Create `saludconecta/assets/illustrations/room_clinic.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 600">
  <rect width="400" height="600" fill="#E3F2FD"/>
  <rect y="430" width="400" height="170" fill="#BBDEFB"/>
  <rect y="424" width="400" height="8" fill="#90CAF9"/>
  <rect x="236" y="70" width="128" height="150" rx="8" fill="#FFFFFF"/>
  <rect x="246" y="80" width="108" height="130" rx="4" fill="#B3E5FC"/>
  <rect x="297" y="80" width="6" height="130" fill="#FFFFFF"/>
  <rect x="246" y="142" width="108" height="6" fill="#FFFFFF"/>
  <circle cx="330" cy="104" r="12" fill="#FFF59D"/>
  <circle cx="104" cy="74" r="30" fill="#FFFFFF"/>
  <rect x="98" y="56" width="12" height="36" rx="3" fill="#00897B"/>
  <rect x="86" y="68" width="36" height="12" rx="3" fill="#00897B"/>
  <rect x="34" y="168" width="140" height="8" rx="3" fill="#90A4AE"/>
  <rect x="44" y="128" width="14" height="40" rx="2" fill="#1565C0"/>
  <rect x="60" y="134" width="12" height="34" rx="2" fill="#00897B"/>
  <rect x="74" y="124" width="16" height="44" rx="2" fill="#7B1FA2"/>
  <rect x="92" y="138" width="12" height="30" rx="2" fill="#F9A825"/>
  <rect x="108" y="136" width="12" height="32" rx="2" fill="#43A047" transform="rotate(-12 114 152)"/>
  <rect x="136" y="146" width="24" height="22" rx="5" fill="#FFFFFF"/>
  <rect x="146" y="150" width="4" height="14" rx="1" fill="#E53935"/>
  <rect x="141" y="155" width="14" height="4" rx="1" fill="#E53935"/>
  <rect x="44" y="236" width="70" height="54" rx="4" fill="#FFFFFF" stroke="#90A4AE" stroke-width="4"/>
  <rect x="56" y="250" width="46" height="5" rx="2.5" fill="#BBDEFB"/>
  <rect x="56" y="262" width="34" height="5" rx="2.5" fill="#BBDEFB"/>
  <circle cx="98" cy="276" r="6" fill="#F9A825"/>
  <ellipse cx="350" cy="420" rx="16" ry="44" fill="#43A047"/>
  <ellipse cx="328" cy="436" rx="12" ry="34" fill="#66BB6A" transform="rotate(-24 328 436)"/>
  <ellipse cx="372" cy="436" rx="12" ry="34" fill="#66BB6A" transform="rotate(24 372 436)"/>
  <rect x="326" y="456" width="48" height="56" rx="8" fill="#00897B"/>
  <rect x="24" y="470" width="150" height="100" rx="8" fill="#90CAF9"/>
  <rect x="24" y="470" width="150" height="12" rx="6" fill="#64B5F6"/>
  <rect x="44" y="500" width="50" height="56" rx="4" fill="#BBDEFB"/>
  <rect x="104" y="500" width="50" height="56" rx="4" fill="#BBDEFB"/>
  <circle cx="86" cy="528" r="4" fill="#1565C0"/>
  <circle cx="112" cy="528" r="4" fill="#1565C0"/>
</svg>
```

Create `saludconecta/assets/illustrations/room_home.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 600">
  <rect width="400" height="600" fill="#FFF3E0"/>
  <rect y="460" width="400" height="140" fill="#FFE0B2"/>
  <rect x="44" y="80" width="120" height="90" rx="6" fill="#FFFFFF" stroke="#BCAAA4" stroke-width="6"/>
  <path d="M52 162 L84 118 L104 140 L122 120 L156 162 Z" fill="#81C784"/>
  <circle cx="134" cy="104" r="10" fill="#FFB74D"/>
  <path d="M300 92 H352 L340 132 H312 Z" fill="#FFCC80"/>
  <rect x="323" y="132" width="6" height="150" fill="#8D6E63"/>
  <ellipse cx="326" cy="286" rx="24" ry="6" fill="#8D6E63"/>
  <rect x="226" y="208" width="72" height="8" rx="3" fill="#A1887F"/>
  <rect x="234" y="176" width="12" height="32" rx="2" fill="#4FC3F7"/>
  <rect x="248" y="182" width="12" height="26" rx="2" fill="#F06292"/>
  <circle cx="276" cy="194" r="12" fill="#AED581"/>
  <ellipse cx="44" cy="300" rx="14" ry="40" fill="#66BB6A"/>
  <ellipse cx="26" cy="314" rx="10" ry="30" fill="#81C784" transform="rotate(-24 26 314)"/>
  <ellipse cx="62" cy="314" rx="10" ry="30" fill="#81C784" transform="rotate(24 62 314)"/>
  <rect x="24" y="330" width="40" height="44" rx="6" fill="#BCAAA4"/>
  <rect x="10" y="372" width="380" height="110" rx="30" fill="#7986CB"/>
  <rect x="10" y="420" width="380" height="90" rx="20" fill="#5C6BC0"/>
</svg>
```

Create `saludconecta/assets/illustrations/empty_cases.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 180">
  <ellipse cx="120" cy="98" rx="106" ry="74" fill="#E3F2FD"/>
  <circle cx="34" cy="48" r="5" fill="#F9A825"/>
  <circle cx="206" cy="56" r="4" fill="#00897B"/>
  <rect x="54" y="40" width="112" height="106" rx="12" fill="#FFFFFF"/>
  <path d="M54 52 A12 12 0 0 1 66 40 H154 A12 12 0 0 1 166 52 V64 H54 Z" fill="#1565C0"/>
  <rect x="76" y="30" width="8" height="20" rx="4" fill="#0D3B66"/>
  <rect x="136" y="30" width="8" height="20" rx="4" fill="#0D3B66"/>
  <rect x="68" y="76" width="16" height="14" rx="3" fill="#E3F2FD"/>
  <rect x="90" y="76" width="16" height="14" rx="3" fill="#E3F2FD"/>
  <rect x="112" y="76" width="16" height="14" rx="3" fill="#E3F2FD"/>
  <rect x="134" y="76" width="16" height="14" rx="3" fill="#E3F2FD"/>
  <rect x="68" y="98" width="16" height="14" rx="3" fill="#E3F2FD"/>
  <rect x="90" y="98" width="16" height="14" rx="3" fill="#E3F2FD"/>
  <rect x="112" y="98" width="16" height="14" rx="3" fill="#E3F2FD"/>
  <rect x="68" y="120" width="16" height="14" rx="3" fill="#E3F2FD"/>
  <rect x="90" y="120" width="16" height="14" rx="3" fill="#E3F2FD"/>
  <circle cx="166" cy="120" r="24" fill="#FFFFFF" stroke="#00897B" stroke-width="7"/>
  <path d="M183 137 L204 158" fill="none" stroke="#00897B" stroke-width="10" stroke-linecap="round"/>
</svg>
```

Create `saludconecta/assets/illustrations/empty_results.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 180">
  <ellipse cx="120" cy="98" rx="106" ry="74" fill="#E0F2F1"/>
  <circle cx="40" cy="52" r="5" fill="#F9A825"/>
  <circle cx="204" cy="40" r="4" fill="#1565C0"/>
  <path d="M70 30 H140 L170 60 V156 H70 Z" fill="#FFFFFF"/>
  <path d="M140 30 V60 H170 Z" fill="#B2DFDB"/>
  <rect x="84" y="56" width="44" height="6" rx="3" fill="#B2DFDB"/>
  <rect x="84" y="72" width="66" height="6" rx="3" fill="#E0F2F1"/>
  <rect x="84" y="86" width="56" height="6" rx="3" fill="#E0F2F1"/>
  <rect x="84" y="100" width="62" height="6" rx="3" fill="#E0F2F1"/>
  <circle cx="160" cy="130" r="26" fill="#00897B"/>
  <path d="M150 116 H170 L160 130 L170 144 H150 L160 130 Z" fill="#FFFFFF"/>
  <rect x="148" y="113" width="24" height="4" rx="2" fill="#FFFFFF"/>
  <rect x="148" y="143" width="24" height="4" rx="2" fill="#FFFFFF"/>
</svg>
```

- [ ] **Step 6: Crear los símbolos de las aseguradoras ficticias**

Create `saludconecta/assets/illustrations/insurer_salud_plena.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="30" fill="#00897B"/>
  <path d="M32 48 C19 40 13 33 15 25 C17 17 27 15 32 23 C37 15 47 17 49 25 C51 33 45 40 32 48 Z" fill="#FFFFFF"/>
  <rect x="29.5" y="24" width="5" height="15" rx="1.5" fill="#00897B"/>
  <rect x="24.5" y="29" width="15" height="5" rx="1.5" fill="#00897B"/>
</svg>
```

Create `saludconecta/assets/illustrations/insurer_vida_segura.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <path d="M32 3 L56 12 V30 C56 45 45 55 32 61 C19 55 8 45 8 30 V12 Z" fill="#1565C0"/>
  <path d="M32 9 L50 16 V30 C50 41 42 49 32 54 Z" fill="#1E88E5"/>
  <path d="M21 32 L29 40 L44 24" fill="none" stroke="#FFFFFF" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

Create `saludconecta/assets/illustrations/insurer_familia_sana.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="2" y="2" width="60" height="60" rx="16" fill="#43A047"/>
  <path d="M12 32 L32 14 L52 32 H46 V50 H18 V32 Z" fill="#FFFFFF"/>
  <path d="M32 45 C25 40 22 37 23 33 C24 29 29 28 32 32 C35 28 40 29 41 33 C42 37 39 40 32 45 Z" fill="#E53935"/>
</svg>
```

- [ ] **Step 7: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/assets/scenes_test.dart
```

Expected: `All tests passed!` (16 pruebas).

---

### Task 4: Widgets `AppIllustration` y `AvatarImage`

**Files:**
- Create: `saludconecta/lib/core/widgets/app_illustration.dart`, `saludconecta/lib/core/widgets/avatar_image.dart`
- Test: `saludconecta/test/core/widgets/illustration_widgets_test.dart`

**Interfaces:**
- Consumes: `AppIllustrations`.
- Produces:
  - `AppIllustration(String asset, {double? width, double? height, BoxFit fit = BoxFit.contain, String? semanticLabel})`;
  - `AvatarImage({required String name, String? asset, double size = 48, Color? color})`;
  - `AvatarImage.initialsOf(String name) → String`. Ignora los títulos "Dr.", "Dra." y "Lic.".

- [ ] **Step 1: Escribir la prueba de los widgets**

Create `saludconecta/test/core/widgets/illustration_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/constants/app_illustrations.dart';
import 'package:saludconecta/core/widgets/app_illustration.dart';
import 'package:saludconecta/core/widgets/avatar_image.dart';

void main() {
  test('iniciales sin títulos', () {
    expect(AvatarImage.initialsOf('María Fernández'), 'MF');
    expect(AvatarImage.initialsOf('Dr. Carlos Méndez'), 'CM');
    expect(AvatarImage.initialsOf('Lic. Sofía Herrera'), 'SH');
    expect(AvatarImage.initialsOf('Ana'), 'A');
    expect(AvatarImage.initialsOf('   '), '?');
  });

  testWidgets('AvatarImage sin ilustración muestra las iniciales', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AvatarImage(name: 'Ana Peña'))));
    expect(find.text('AP'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('AvatarImage con ilustración muestra el SVG', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AvatarImage(name: 'María Fernández', asset: AppIllustrations.patients.first))),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('MF'), findsNothing);
  });

  testWidgets('AppIllustration dibuja el SVG del catálogo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppIllustration(AppIllustrations.logo, width: 96, height: 96))),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/core/widgets/illustration_widgets_test.dart
```

Expected: FAIL. No compila porque los widgets no existen.

- [ ] **Step 3: Crear los widgets**

Create `saludconecta/lib/core/widgets/app_illustration.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Muestra una ilustración SVG del catálogo (`AppIllustrations`).
class AppIllustration extends StatelessWidget {
  const AppIllustration(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      semanticsLabel: semanticLabel,
      // Mientras carga, reserva el espacio para que la pantalla no "salte".
      placeholderBuilder: (context) => SizedBox(width: width, height: height),
    );
  }
}
```

Create `saludconecta/lib/core/widgets/avatar_image.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Avatar circular: la ilustración SVG de la persona o, si no tiene, sus iniciales.
class AvatarImage extends StatelessWidget {
  const AvatarImage({super.key, required this.name, this.asset, this.size = 48, this.color});

  final String name;
  final String? asset;
  final double size;

  /// Color de las iniciales (por defecto, el primario del tema).
  final Color? color;

  /// "María Fernández" → "MF"; "Dr. Carlos Méndez" → "CM" (se ignoran los títulos).
  static String initialsOf(String name) {
    const titles = {'dr.', 'dra.', 'lic.'};
    final words = [
      for (final word in name.trim().split(RegExp(r'\s+')))
        if (word.isNotEmpty && !titles.contains(word.toLowerCase())) word,
    ];
    if (words.isEmpty) return '?';
    final first = words.first[0];
    final last = words.length > 1 ? words.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final path = asset;
    if (path != null) {
      return ClipOval(
        child: SvgPicture.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticsLabel: name,
          placeholderBuilder: (context) => SizedBox(width: size, height: size),
        ),
      );
    }
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: tint.withOpacity(0.15),
      child: Text(
        initialsOf(name),
        style: TextStyle(color: tint, fontWeight: FontWeight.bold, fontSize: size * 0.36),
      ),
    );
  }
}
```

- [ ] **Step 4: Ejecutar la prueba y verificar que pasa**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/core/widgets/illustration_widgets_test.dart
```

Expected: `All tests passed!` (4 pruebas).

---

### Task 5: Galería, verificación en web y Android, y commit de la etapa

**Files:**
- Create: `saludconecta/lib/features/shared/illustrations_gallery.dart`
- Modify (reemplazo completo): `saludconecta/lib/features/auth/welcome_screen.dart`
- Modify: `docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md` (enlace a este plan y estado de la etapa 3)

**Interfaces:**
- Consumes: `AppIllustrations`, `AppIllustration`, `AppInfo` y `AppColors`.
- Produces:
  - `IllustrationsGallery()`, que muestra las 29 ilustraciones con su nombre y las 2 infografías;
  - la pantalla provisional de bienvenida con la galería. La prueba `test/app_test.dart` sigue igual y debe seguir pasando.

- [ ] **Step 1: Crear la galería y usarla en la pantalla provisional**

Create `saludconecta/lib/features/shared/illustrations_gallery.dart`:

```dart
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
```

Replace the whole content of `saludconecta/lib/features/auth/welcome_screen.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/constants/app_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_illustration.dart';
import '../shared/illustrations_gallery.dart';

/// Pantalla inicial provisional: muestra la galería de imágenes de la etapa 3.
/// En la etapa 4 se reemplaza por la bienvenida con `PageView`.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  const AppIllustration(AppIllustrations.logo, width: 96, height: 96),
                  const SizedBox(height: 12),
                  Text(AppInfo.appName, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(AppInfo.slogan, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.secondary)),
                  const SizedBox(height: 8),
                  const Text('Etapa 3: ilustraciones e infografías', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  const IllustrationsGallery(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Formato, suite completa y análisis**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
$dart = 'C:\Users\Helen\dev\flutter\bin\dart.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $dart format -l 120 lib test
& $flutter test
& $flutter analyze
```

Expected:
- `All tests passed!` (111 pruebas: las 74 anteriores, 4 del catálogo, 13 de avatares, 16 de escenas y 4 de widgets);
- `No issues found!`.

- [ ] **Step 3: Revisar la galería en la web**

Iniciar la vista previa con `preview_start` (`saludconecta-web`), esperar unos 20 s, recargar la página y tomar capturas del panel. Hay que desplazarse para ver las 29 ilustraciones y las infografías.

Expected:
- cada ilustración se ve completa: personas con cara, escenas con sus elementos y símbolos centrados;
- no hay recuadros vacíos;
- la consola del navegador no muestra errores.

Si algún dibujo se ve mal (formas fuera de lugar o colores invertidos), se corrige el SVG, se vuelve a ejecutar `test/assets/` y se revisa de nuevo.

Al terminar, se detiene el servidor con `preview_stop`.

- [ ] **Step 4: Revisar en el emulador Android**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
$adb = 'C:\Users\Helen\AppData\Local\Android\Sdk\platform-tools\adb.exe'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter build apk --debug --target-platform android-x64
& $adb install -r build\app\outputs\flutter-apk\app-debug.apk
& $adb shell am force-stop edu.unapec.iso910.saludconecta
& $adb shell input keyevent KEYCODE_WAKEUP
& $adb shell am start -n edu.unapec.iso910.saludconecta/.MainActivity
Start-Sleep -Seconds 10
& $adb shell screencap -p /sdcard/saludconecta.png
& $adb pull /sdcard/saludconecta.png <scratchpad>\saludconecta-etapa3.png
```

Expected:
- `Success` al instalar;
- la captura muestra el logo, el nombre, el lema y las primeras ilustraciones de la galería.

- [ ] **Step 5: Actualizar la hoja de ruta**

En `docs/superpowers/plans/2026-11-09-saludconecta-00-hoja-de-ruta.md`, en la fila de la etapa 3:
- cambiar `se escribe al cerrar la etapa 2` por `[03-ilustraciones](2026-11-09-saludconecta-03-ilustraciones.md)`;
- cambiar el estado `pendiente` por `hecha`.

- [ ] **Step 6: Commit de la etapa 3**

```powershell
$repo = 'C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial'
git -C $repo add saludconecta docs/superpowers/plans
git -C $repo status --short
git -C $repo commit -m "feat: ilustraciones e infografías de SaludConecta (etapa 3)" -m "29 ilustraciones SVG propias (13 avatares generados, escenas, roles, fondos de videollamada, estados vacíos y aseguradoras ficticias), las 2 infografías del equipo, catálogo AppIllustrations, widgets AppIllustration y AvatarImage, y galería provisional."
git -C $repo log --oneline -3
```

Expected:
- el commit tiene como autor `FDLG301201`;
- no incluye `.claude/` ni el generador de avatares.

Siguiente paso: escribir el plan de la etapa 4, `2026-11-09-saludconecta-04-estado-y-shells.md`.
