# Guía de SaludConecta

> App de telemedicina multi-rol en Flutter · ISO910, UNAPEC · Proyecto del 2do parcial · Cuatrimestre C11
>
> *Más acceso, mejor salud.*

Esta guía reúne el contexto del aplicativo y los pasos para ejecutarlo en local, de cero, en otra computadora.

**Equipo:**

| Integrante | Matrícula |
|---|---|
| Francisco Daniel Lora | A00114255 |
| Rafiel Colon | A00109961 |
| Gabriel Peña | A00114138 |
| Ruby Rosario | A00105745 |
| Justin S. Uceta Montero | A00116654 |

---

## 1. ¿Qué es SaludConecta?

SaludConecta lleva a una app las dos infografías del equipo:

1. **Proceso Integral de Telemedicina entre Pacientes y el Sistema de Salud:** 10 pasos y 5 actores.
2. **Servicios de telemedicina:** 24 servicios en 3 grupos, más los canales de contacto (Celular, Correo, WhatsApp, Portal web y Teléfono).

La idea central es un **caso de telemedicina** que recorre los 10 pasos. Cada paso lo completa un rol distinto, y la app deja **cambiar de rol en cualquier momento**. Así, en una sola demo se ve el proceso completo desde los ojos de cada actor.

### Los 10 pasos y quién los completa

| # | Paso | Actor (color en los diagramas) | Rol que lo completa en la app |
|---|---|---|---|
| 1 | Solicitud de cita | Paciente (verde) | Paciente |
| 2 | Recepción en Hospital / PSS | Admisión (azul) | Admisión |
| 3 | Validación con el seguro | Admisión | Admisión |
| 4 | Agendamiento | Admisión | Admisión |
| 5 | Confirmación al paciente | Admisión | Admisión |
| 6 | Consentimiento y admisión virtual | Paciente | Paciente |
| 7 | Consulta de telemedicina | Médico (verde azulado) | Médico |
| 8 | Resultado de la consulta | Médico | Médico |
| 9 | Cierre administrativo | Facturación (índigo) | Facturación |
| 10 | Seguimiento al paciente | Admisión | Paciente (responde la encuesta) |

El 5.º actor, **Personal de apoyo y tecnología (Soporte TI, morado)**, no es un rol de la app. Aparece en tres lugares:

- en los diagramas;
- en la prueba de conexión de la sala de espera;
- como contacto de soporte ("Llamar a soporte").

### Reglas del proceso

- Los pasos van en orden: no se puede completar uno sin haber completado el anterior.
- Cada paso solo lo completa su rol.
- Si el seguro **rechaza** la validación (por ejemplo, por una afiliación inactiva), Admisión elige **"Continuar como privado"**, y el paciente paga el 100%, o **"Cancelar solicitud"**.
- El paciente puede cancelar su cita solo hasta el paso 6.
- El **copago** se calcula así:
  - copago = tarifa × (100 − cobertura) %;
  - la cobertura depende del plan de la aseguradora;
  - algunos servicios tienen cobertura reducida (20 puntos menos).
- El **cierre** (paso 9) solo se habilita cuando están listas la reclamación, la auditoría y el pago.

## 2. Qué hace cada rol

### Paciente: Inicio · Mis citas · Servicios · Perfil

- **Inicio:**
  - saludo y campana de notificaciones;
  - tarjeta del caso activo ("Paso X de 10") con el botón de la siguiente acción;
  - accesos rápidos;
  - consejos de salud.
- **Solicitar cita:** asistente de 3 pasos:
  1. servicio;
  2. canal y motivo;
  3. fecha.
- **Consentimiento:** texto, 3 casillas y **firma con el dedo**.
- **Sala de espera:** prueba de conexión animada y Soporte TI.
- **Videollamada:** simulada, con micrófono, cámara, chat y colgar.
- **Resultados:**
  - receta con aspecto de documento y **código QR**;
  - órdenes y referimiento;
  - "Solicitar cita de seguimiento".
- **Encuesta:** estrellas, NPS de 0 a 10 y un comentario.
- **Servicios:** los 24 servicios de la infografía.
- **Perfil:**
  - carnet de seguro dibujado;
  - datos personales;
  - **Mi resumen**, con una dona de lo cubierto frente a lo pagado y barras por especialidad.

### Admisión: Bandeja · Agenda · Seguimiento · Indicadores

- **Bandeja:** filtros Nuevas, Por validar, Por agendar y Por confirmar. Cada caso muestra cuánto tiempo lleva esperando.
- **Procesar solicitud:**
  1. registrar;
  2. validar el seguro (simulado);
  3. agendar (médico, día, hora y plataforma Teams, Zoom o Meet);
  4. enviar la confirmación por WhatsApp o Correo.
- **Agenda:** las citas de los próximos 7 días, por médico.
- **Seguimiento:** casos en el paso 10, con "Registrar llamada".

### Médico: Agenda · Indicadores

- **Agenda:** citas de hoy y próximas. Cuando el paciente está en la sala de espera, se habilita **"Iniciar consulta"**.
- **Consulta:** videollamada con **notas clínicas** (motivo, evaluación, diagnóstico y plan).
- **Emitir resultados:**
  - receta;
  - órdenes de laboratorio e imágenes;
  - referimiento;
  - indicaciones;
  - próxima cita.

### Facturación: Pendientes · Reclamaciones · Indicadores

- **Cierre administrativo:**
  - factura;
  - reclamación al seguro ("Aprobada · REC-…");
  - auditoría automática ✓/✗;
  - pago del copago;
  - **Cerrar caso**.
- **Reclamaciones:** todas, con filtro Aprobada, Pendiente o Glosada.

### Comunes

- **Indicadores**, con 4 pestañas. La pestaña inicial depende del rol.
- **Diagramas del proceso:**
  - flujo;
  - carriles por actor.
- **Diagrama del caso:** un caso concreto sobre el diagrama de flujo.
- **Acerca de:**
  - infografías;
  - arquitectura;
  - equipo.
- **Detalle del caso**, con línea de tiempo.

## 3. Gráficas, imágenes y diagramas

La rúbrica valora estos elementos. Todas las gráficas se calculan **en vivo** a partir de los mismos casos: cuando se cierra un caso durante la demo, los indicadores cambian.

| Dónde | Gráfica | Tipo |
|---|---|---|
| Operación | Solicitudes del mes, casos en proceso, días a la consulta, % de rechazo | KPIs |
| Operación | Solicitudes por canal | Dona |
| Operación | Solicitudes vs. consultas por mes | Líneas (2 series) |
| Operación | Embudo de los 10 pasos | Barras horizontales |
| Operación | Horas promedio por etapa | Barras |
| Clínico | Consultas por especialidad · Resultados emitidos | Barras |
| Clínico | Plataforma usada | Dona |
| Financiero | Facturación mensual (seguro + copago) | Barras apiladas |
| Financiero | Reclamaciones por estado | Dona |
| Financiero | Facturación por aseguradora | Barras horizontales |
| Satisfacción | Calificación promedio, NPS, encuestas | KPIs |
| Satisfacción | Distribución 1–5★ | Barras |
| Satisfacción | Promedio por mes | Líneas |
| Perfil del paciente | Cubierto vs. pagado · Consultas por especialidad | Dona · Barras |

**Diagramas** (dibujados con `CustomPainter`):

- **Diagrama de flujo:**
  - inicio, los 10 pasos y el rombo "¿El seguro aprueba?";
  - rama "No": privado o cancelar;
  - zoom con los dedos;
  - al tocar un paso se abre su detalle.
- **Modo caso:** los pasos completados van en verde con ✓, el actual en ámbar **con un pulso animado** y los pendientes en gris.
- **Diagrama de carriles:** 5 carriles, uno por actor, y 10 columnas.
- **Línea de tiempo** del caso.
- **Diagrama de arquitectura** de Flutter y de la app.

**Imágenes:**

- 29 ilustraciones SVG propias: logo, roles, avatares de médicos y pacientes, escenas de la videollamada y aseguradoras;
- las 2 infografías del equipo;
- el QR de la receta;
- el carnet de seguro;
- la firma con el dedo.

## 4. Arquitectura

### Arquitectura de Flutter (para la exposición)

- **Framework (Dart):** las capas van de arriba abajo:
  1. Material / Cupertino;
  2. Widgets;
  3. Rendering;
  4. Animation / Painting / Gestures;
  5. Foundation.

  En Flutter, todo lo que se ve es un **widget**.
- **Engine (C++):** Skia / Impeller dibuja cada píxel. También incluye el *runtime* de Dart, el texto y los *platform channels*.
- **Embedder:** conecta el engine con cada plataforma; aquí, **Android** y **Web**.

### Arquitectura de SaludConecta (4 capas)

```
Presentación   lib/features/ y lib/core/   pantallas por rol, gráficas, diagramas, rutas y tema
     │ lee y escucha (Provider)
Estado         lib/state/                  CaseProvider, SessionProvider (ChangeNotifier)
     │ usa
Dominio        lib/domain/                 Dart puro: ProcessStep, ProcessRules, CaseWorkflow,
     ▲                                     BillingCalculator, StatsCalculator, ScheduleService
     │ implementa las interfaces
Datos          lib/data/                   repositorios en memoria, gateways simulados, semilla
```

- **`app_dependencies.dart`** es la *raíz de composición*: crea los datos, el seguro simulado, el estado y las rutas, y los publica con `MultiProvider`.
- **Estado:** se usa `provider`. Las pantallas leen con `context.watch` y, cuando el caso cambia, `notifyListeners()` redibuja todo lo que depende de él.
- **Navegación:** se usa `go_router`.
  - Hay un `redirect` por rol: cada rol solo entra a sus pantallas.
  - Cada rol tiene un `StatefulShellRoute` con barra inferior, y cada pestaña conserva su estado.
- **Reglas:** cada acción pasa por `ProcessRules`. Si no es válida, lanza `ProcessException` y la pantalla muestra el mensaje.
- **Datos:** todo vive en memoria.
  - La semilla es **determinista**: unos 200 casos históricos en 12 meses más 10 casos "en vivo".
  - Al cerrar la app, todo vuelve al estado inicial.
  - No hay backend.

### Estructura de carpetas

```
Proyecto2doParcial/
├── README.md                    índice del repositorio
├── docs/
│   ├── GUIA-SALUDCONECTA.md     esta guía
│   ├── infografias/             las 2 infografías del equipo
│   └── superpowers/
│       ├── specs/               documento de diseño completo
│       └── plans/               hoja de ruta y plan de las 11 etapas
└── saludconecta/                proyecto Flutter (fuentes)
    ├── lib/
    │   ├── main.dart, app.dart, app_dependencies.dart
    │   ├── core/        constantes (app_info.dart), tema, rutas, formatos y widgets reutilizables
    │   ├── domain/      modelos, proceso de 10 pasos y servicios de cálculo
    │   ├── data/        repositorios, gateways simulados y semilla
    │   ├── state/       CaseProvider y SessionProvider
    │   └── features/    auth, patient, admission, doctor, billing, indicators, diagrams, about, shared
    ├── assets/          illustrations/ (SVG) e images/ (infografías)
    ├── test/            200 pruebas automáticas
    └── android/, web/   proyectos de cada plataforma
```

### Paquetes

| Paquete | Para qué |
|---|---|
| `provider` | Estado (ChangeNotifier) |
| `go_router` | Rutas y redirect por rol |
| `fl_chart` 0.69 | Gráficas (la 0.70+ no compila con Flutter 3.19) |
| `flutter_svg` | Ilustraciones SVG |
| `intl` + `flutter_localizations` | Fechas y montos en español (RD$) |
| `qr_flutter` | QR de la receta |
| `url_launcher` | "Llamar a soporte" (`tel:`) |

## 5. Cómo ejecutarla en local

### 5.1 Requisitos

| Herramienta | Versión | Nota |
|---|---|---|
| **Flutter SDK** | **3.19.0** (incluye Dart 3.3.0) | Usa esta versión exacta: con otras pueden fallar algunos paquetes |
| Git | cualquiera | Para clonar o copiar el repositorio |
| **Android Studio** | reciente | Trae el Android SDK, el emulador y el JDK 21 |
| Google Chrome | reciente | Opcional, para correrla en web |
| Visual Studio Code | opcional | Con la extensión "Flutter" |

Versiones de Android que ya trae configuradas el proyecto (no hay que tocarlas):

- Gradle 8.11.1;
- Android Gradle Plugin 8.6.1;
- Kotlin 2.1.21.

Se usan esas versiones porque el JDK de Android Studio es Java 21.

### 5.2 Instalar Flutter 3.19.0 (Windows)

1. Descarga el SDK 3.19.0 desde el archivo de versiones de Flutter: <https://docs.flutter.dev/release/archive> (Windows → Stable → 3.19.0).
2. Descomprímelo en una ruta **sin espacios ni acentos**, por ejemplo `C:\dev\flutter`.
3. Agrega `C:\dev\flutter\bin` al **PATH**: Configuración → Variables de entorno → `Path` → Nuevo.

   Si no quieres tocar el PATH, usa la ruta completa en cada comando, por ejemplo `C:\dev\flutter\bin\flutter.bat run`.
4. Abre una terminal nueva y comprueba la versión:
   ```bash
   flutter --version
   ```
   Debe decir `Flutter 3.19.0`.

   > Si ya tienes otra versión de Flutter, no la actualices ni la reemplaces. Instala la 3.19.0 en otra carpeta y úsala con su ruta completa.

### 5.3 Preparar Android

1. Instala **Android Studio** y ábrelo una vez para que instale el Android SDK.
2. En **More Actions → Virtual Device Manager**, crea un emulador. El equipo usó un **Pixel 3a, API 34**.
3. Acepta las licencias de Android:
   ```bash
   flutter doctor --android-licenses
   ```
4. Revisa que todo esté en orden:
   ```bash
   flutter doctor
   ```
   Deben salir en verde **Flutter**, **Android toolchain** y, si vas a usar web, **Chrome**. Los avisos de Visual Studio (Windows desktop) se pueden ignorar, porque la app no se compila para Windows.

### 5.4 Descargar dependencias y ejecutar

Desde la carpeta del proyecto Flutter:

```bash
cd saludconecta
flutter pub get
```

**En el emulador Android** (recomendado para la demo):

1. Abre el emulador desde Android Studio, o desde la terminal:
   ```bash
   flutter emulators --launch Pixel_3a_API_34_extension_level_7_x86_64
   ```
   El nombre puede ser distinto: `flutter emulators` lista los que tienes.
2. Mira el id del dispositivo:
   ```bash
   flutter devices
   ```
3. Ejecuta la app:
   ```bash
   flutter run -d emulator-5554
   ```

**En Chrome:**

```bash
flutter run -d chrome
```

**En un teléfono Android real:**

1. Activa *Opciones de desarrollador → Depuración USB*.
2. Conecta el teléfono por cable.
3. Ejecuta `flutter run`.

Mientras la app corre, en la terminal:

- `r` aplica cambios en caliente (*hot reload*);
- `R` reinicia la app, que vuelve al estado inicial;
- `q` sale.

### 5.5 Generar el APK para instalarlo

```bash
flutter build apk --debug
```

El APK queda en `saludconecta/build/app/outputs/flutter-apk/app-debug.apk`. Para instalarlo:

- en el emulador, arrastra el archivo a su ventana;
- en un teléfono, cópialo y ábrelo.

### 5.6 Pruebas y análisis

```bash
flutter test       # 200 pruebas: dominio, datos, estado y pantallas
flutter analyze    # debe decir "No issues found!"
```

### 5.7 Problemas comunes

| Síntoma | Solución |
|---|---|
| `flutter` no se reconoce | Flutter no está en el PATH. Usa la ruta completa o agrega `...\flutter\bin` al PATH y abre una terminal nueva |
| Errores de paquetes (`fl_chart`, APIs desconocidas) | Estás usando otra versión de Flutter. Comprueba con `flutter --version` que sea la 3.19.0 |
| Gradle falla con *Unsupported class file major version* | El proyecto ya trae Gradle 8. Ejecuta `flutter clean` y luego `flutter pub get`, y vuelve a correrlo |
| *Android license status unknown* | Ejecuta `flutter doctor --android-licenses` y acepta todo con `y` |
| `No devices found` | Abre el emulador antes de `flutter run`, o usa `-d chrome` |
| La primera compilación de Android tarda varios minutos | Es normal: Gradle descarga dependencias. Las siguientes compilaciones son rápidas |
| La app "olvidó" lo que hice | Es así a propósito: los datos viven en memoria y se reinician al cerrar la app |

## 6. Cómo usarla: ingreso y datos de ejemplo

- **Ingreso:**
  - en la bienvenida, toca *Omitir*, o recorre las 3 pantallas;
  - elige el rol;
  - como **paciente**, toca uno de los pacientes de ejemplo y luego *Ingresar*;
  - como **personal**, toca su nombre.

  No hay contraseñas: es una demo.
- **Cambiar de rol:** usa el ícono de la barra superior.
- **Personal:**
  - Admisión: **Ana Peña**;
  - Facturación: **Roberto Díaz**;
  - Soporte TI: Luis Castillo (solo como contacto).
- **Médicos:**
  - **Dr. Carlos Méndez** (Medicina general);
  - Dra. Laura Jiménez (Medicina interna);
  - Dr. Andrés Rosario;
  - Dra. Patricia Núñez;
  - Dr. Miguel Santana;
  - Lic. Sofía Herrera;
  - Lic. Daniela Cruz.
- **Pacientes:**
  - **María Fernández**: principal; no tiene caso activo, así que su caso se crea en vivo;
  - José Martínez;
  - Carmen Reyes;
  - **Pedro Almonte**: afiliación inactiva, por lo que el seguro rechaza su validación;
  - Luisa Gómez;
  - Ramón Ortiz.
- **Aseguradoras (ficticias):** ARS Salud Plena, ARS Vida Segura y ARS Familia Sana, con planes Básico, Plus y Premium.

### Casos "en vivo" listos para mostrar cada pantalla

| Paciente | Paso pendiente | Dónde verlo |
|---|---|---|
| José Martínez | 2 Recepción | Admisión → Nuevas |
| Carmen Reyes | 3 Validación | Admisión → Por validar |
| Pedro Almonte | 3 Validación (rechazo) | Admisión → Por validar |
| Luisa Gómez | 4 Agendamiento | Admisión → Por agendar |
| Ramón Ortiz | 5 Confirmación | Admisión → Por confirmar |
| José Martínez | 6 Consentimiento | Paciente José → Inicio |
| Carmen Reyes | 7 Consulta | Médico Méndez → "Paciente en sala de espera" |
| Luisa Gómez | 8 Resultados | Médico Méndez → Agenda |
| Ramón Ortiz | 9 Cierre | Facturación → Pendientes |
| José Martínez | 10 Seguimiento | Admisión → Seguimiento; Paciente José → Encuesta |

## 7. Guion de demo (unos 8 minutos)

1. **Paciente María** → **Solicitar cita**:
   - Consulta médica general;
   - WhatsApp;
   - motivo;
   - fecha.
2. **Admisión (Ana Peña)** → Nuevas → **Procesar**:
   1. registrar;
   2. validar el seguro (80%);
   3. agendar con el Dr. Méndez por Teams;
   4. confirmar por WhatsApp.
3. **Paciente María** → notificación → **firmar el consentimiento** → sala de espera → **videollamada**.
4. **Médico (Dr. Méndez)** → **Iniciar consulta** → notas → colgar → **Emitir resultados** (receta, órdenes y seguimiento a 15 días).
5. **Facturación (Roberto Díaz)** → **Cerrar caso**: reclamación, auditoría, pago del copago (RD$300) y cerrar.
6. **Paciente María** → **receta con QR** → **encuesta 5★**.
7. **Admisión → Indicadores:** el caso nuevo ya cuenta. Después, **Diagramas del proceso**.
8. **Camino alterno:** Admisión → **Pedro Almonte** → validar → rechazado → **Continuar como privado**.

Extras para la exposición:

- **Ver en el diagrama**, desde el detalle de un caso: el modo caso con el pulso animado.
- **Acerca de → Arquitectura.**
- **Perfil → Mi resumen.**

## 8. Qué queda fuera de alcance

- Backend, base de datos e inicio de sesión real.
- Cámara y videollamada reales.
- Envíos reales por WhatsApp o correo.
- Notificaciones push y exportación a PDF.
- iOS y Windows.
- Modo oscuro.

Las aseguradoras, los pacientes y los casos son **ficticios**. Teams, Zoom y Meet se nombran, pero no se usan sus logos.

## 9. Para profundizar

- Diseño completo: `docs/superpowers/specs/2026-11-08-saludconecta-design.md`.
- Plan por etapas (11), con lo que se hizo en cada una: `docs/superpowers/plans/`.
- README de la app: `saludconecta/README.md`.
