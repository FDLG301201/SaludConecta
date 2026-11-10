# SaludConecta · Etapa 8: Flujo de Facturación — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir las pantallas de Facturación (§6 Facturación): pendientes de cierre, el cierre administrativo (factura, reclamación, auditoría y pago) y la lista de reclamaciones.

**Architecture:**

- Pantallas en `lib/features/billing/`. La factura sale de `CaseProvider.invoiceFor`. La auditoría y la regla de cierre salen de `BillingCalculator`, que es dominio puro y ya está probado.
- El cierre muestra cada parte con su estado. "Cerrar caso" se habilita solo cuando `BillingCalculator.canClose` lo permite.
- `CaseListScreen` (la lista provisional de la etapa 4) ya no se usa: se elimina.

**Tech Stack:** `LoadingButton` con `isBusy` (reclamación), `ChoiceChip` (método de pago), filtros con contador.

**Hoja de ruta:** [00-hoja-de-ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md) · **Spec:** §6 Facturación, §4 (regla del paso 9)

## Global Constraints

Las de la [hoja de ruta](2026-11-09-saludconecta-00-hoja-de-ruta.md#global-constraints) y sus notas de pruebas. Un solo commit al final (tarea 3).

## Archivos de la etapa

| Archivo | Responsabilidad |
|---|---|
| `lib/features/billing/billing_pending_screen.dart` | Casos con el paso 9 pendiente y su copago |
| `lib/features/billing/closure_screen.dart` | Cierre administrativo (paso 9) |
| `lib/features/billing/claims_screen.dart` | Reclamaciones con filtro por estado |
| `lib/core/router/app_router.dart` | Rutas de Facturación (ediciones) |
| `lib/features/shared/case_list_screen.dart` | Se elimina |
| `test/features/billing/` | Pruebas |

---

### Task 1: Pendientes y cierre administrativo

**Files:**
- Create: `saludconecta/lib/features/billing/billing_pending_screen.dart`, `saludconecta/lib/features/billing/closure_screen.dart`
- Modify: `saludconecta/lib/core/router/app_router.dart` (edición)
- Test: `saludconecta/test/features/billing/closure_test.dart`

**Interfaces:**
- Consumes: `CaseProvider.billingInbox`, `invoiceFor`, `submitClaim(id, {staff})` (lenta), `registerPayment(id, {staff, method})`, `closeAdministratively(id, {staff})` e `isBusy`; `BillingCalculator.claimStatusOf`, `auditChecklist`, `paymentPending` y `canClose`.
- Produces:
  - `BillingPendingScreen()` (título "Pendientes de cierre"; botón "Cerrar caso" por tarjeta).
  - `ClosureScreen({required String caseId})`. Botones "Enviar reclamación a {aseguradora}", "Registrar pago de copago RD$…" y "Cerrar caso".

- [ ] **Step 1: Escribir la prueba**

Create `saludconecta/test/features/billing/closure_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 150, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  VoidCallback? onPressedOf(WidgetTester tester, String label) => tester
      .widget<ButtonStyleButton>(
        find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
      )
      .onPressed;

  testWidgets('Facturación ve los casos pendientes de cierre', (tester) async {
    await tester.pumpWidget(appWith(staffDependencies(UserRole.billing)));
    await tester.pumpAndSettle();
    expect(find.text('Pendientes de cierre'), findsOneWidget);
    expect(find.text('Ramón Ortiz'), findsOneWidget);
    expect(find.text('Cerrar caso'), findsOneWidget);
  });

  testWidgets('Roberto envía la reclamación, registra el pago y cierra el caso de Ramón', (tester) async {
    final deps = staffDependencies(UserRole.billing);
    final c = openCaseOf(deps, SeedIds.ramon, ProcessStep.administrativeClosure);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.closure));
    await tester.pumpAndSettle();

    expect(find.text('Cierre administrativo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cerrar caso'), 150, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(onPressedOf(tester, 'Cerrar caso'), isNull);

    // La reclamación está más arriba: se desplaza hacia arriba.
    final claim = find.textContaining('Enviar reclamación a');
    await tester.scrollUntilVisible(claim, -150, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(claim);
    await tester.pumpAndSettle();
    expect(find.textContaining('Aprobada · REC-'), findsOneWidget);

    await tapVisible(tester, find.text('Tarjeta'));
    await tapVisible(tester, find.textContaining('Registrar pago de copago'));
    expect(find.textContaining('Pagado con Tarjeta'), findsOneWidget);

    await tapVisible(tester, find.text('Cerrar caso'));
    final closed = deps.cases.caseById(c.id)!;
    expect(closed.currentStep, ProcessStep.followUp);
    expect(closed.billing!.closedAt, isNotNull);
    expect(find.text('Pendientes de cierre'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
$flutter = 'C:\Users\Helen\dev\flutter\bin\flutter.bat'
Set-Location C:\Users\Helen\Desktop\UNAPEC\CUATRIMESTRES\C11\ISO910\Proyecto2doParcial\saludconecta
& $flutter test test/features/billing/closure_test.dart
```

Expected: FAIL. El cierre todavía es `ComingSoonScreen`.

- [ ] **Step 3: Crear los pendientes y el cierre**

Create `saludconecta/lib/features/billing/billing_pending_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/case_card.dart';
import '../../core/widgets/page_body.dart';
import '../../state/case_provider.dart';

/// Pendientes de Facturación (§6): casos con el paso 9 (cierre administrativo) pendiente.
class BillingPendingScreen extends StatelessWidget {
  const BillingPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final items = cases.billingInbox();
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Pendientes de cierre', style: theme.textTheme.headlineSmall),
          Text('Casos con el paso 9 pendiente: factura, reclamación, auditoría y pago',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay casos pendientes de cierre.', textAlign: TextAlign.center),
              ),
            )
          else
            for (final c in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CaseCard(
                      telemedicineCase: c,
                      onTap: () => context.push(AppRoutes.caseDetail(c.id)),
                      trailing: Text(
                        'Copago ${Formatters.money(cases.invoiceFor(c).copay)}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.caseAction(c.id, CaseAction.closure)),
                      icon: const Icon(Icons.request_quote_outlined),
                      label: const Text('Cerrar caso'),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
```

Create `saludconecta/lib/features/billing/closure_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/loading_button.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/section_card.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/case_records.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/people.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_exception.dart';
import '../../domain/process/process_step.dart';
import '../../domain/services/billing_calculator.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';
import '../patient/patient_case_builder.dart';
import '../shared/not_found_screen.dart';

/// Cierre administrativo (paso 9): factura, reclamación al seguro, auditoría y pago del copago.
/// "Cerrar caso" se habilita solo cuando todo está completo.
class ClosureScreen extends StatelessWidget {
  const ClosureScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CaseProvider>().caseById(caseId);
    if (c == null) {
      return const NotFoundScreen(title: 'Caso no encontrado', message: 'El caso que buscas no existe.');
    }
    if (c.status != CaseStatus.active || c.currentStep != ProcessStep.administrativeClosure) {
      return CaseNotice(
        screenTitle: 'Cierre administrativo',
        title: c.billing?.closedAt != null ? 'El caso ya está cerrado' : 'Aún no se puede cerrar',
        message: 'El caso ${c.id} está en el paso ${c.currentStep.number}: ${c.currentStep.title}.',
      );
    }
    return _ClosureForm(telemedicineCase: c);
  }
}

class _ClosureForm extends StatefulWidget {
  const _ClosureForm({required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  @override
  State<_ClosureForm> createState() => _ClosureFormState();
}

class _ClosureFormState extends State<_ClosureForm> {
  PaymentMethod _method = PaymentMethod.cash;

  TelemedicineCase get _case => widget.telemedicineCase;

  StaffMember get _staff => context.read<SessionProvider>().currentStaff!;

  void _run(void Function() action, String success) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    try {
      action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _submitClaim() async {
    final cases = context.read<CaseProvider>();
    final staff = _staff;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final number = await cases.submitClaim(_case.id, staff: staff);
      messenger.showSnackBar(SnackBar(content: Text('Reclamación aprobada: $number.')));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _close() {
    final router = GoRouter.of(context);
    _run(() {
      context.read<CaseProvider>().closeAdministratively(_case.id, staff: _staff);
      router.go(AppRoutes.billingPending);
    }, 'Caso ${_case.id} cerrado. Pasa a seguimiento.');
  }

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final catalog = context.read<CatalogRepository>();
    final c = _case;
    final invoice = cases.invoiceFor(c);
    final patient = catalog.patientById(c.patientId);
    final insurer = catalog.insurerById(patient.affiliation.insurerId);
    final claim = BillingCalculator.claimStatusOf(c, invoice);
    final audit = BillingCalculator.auditChecklist(c, invoice);
    final payment = c.billing?.payment;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cierre administrativo')),
      body: PageBody(
        child: ListView(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(patient.fullName),
                subtitle: Text('${c.id} · ${insurer.name}, plan ${patient.affiliation.plan}'),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Factura',
              icon: Icons.receipt_outlined,
              child: Column(
                children: [
                  _Row('Concepto', catalog.serviceById(c.serviceId).name),
                  _Row('Tarifa', Formatters.money(invoice.fee)),
                  _Row('Cobertura', c.privatePay ? 'Privado' : '${invoice.coveragePercent}%'),
                  _Row('A cargo del seguro', Formatters.money(invoice.insurerAmount)),
                  _Row('Copago del paciente', Formatters.money(invoice.copay)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Reclamación al seguro',
              icon: Icons.outgoing_mail,
              child: switch (claim) {
                ClaimStatus.notApplicable => const Text('No aplica: el seguro no cubre este caso (paciente privado).'),
                ClaimStatus.approved => Text(
                    'Aprobada · ${c.billing?.claimNumber ?? ''}',
                    style: theme.textTheme.titleSmall?.copyWith(color: AppColors.done),
                  ),
                _ => Align(
                    alignment: Alignment.centerLeft,
                    child: LoadingButton(
                      label: 'Enviar reclamación a ${insurer.name}',
                      icon: Icons.send,
                      loading: cases.isBusy(c.id),
                      onPressed: _submitClaim,
                    ),
                  ),
              },
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Auditoría',
              icon: Icons.fact_check_outlined,
              child: Column(
                children: [
                  for (final item in audit)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item.ok ? Icons.check_circle : Icons.cancel,
                        color: item.ok ? AppColors.done : AppColors.danger,
                      ),
                      title: Text(item.label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Pago del copago',
              icon: Icons.payments_outlined,
              child: _payment(invoice, payment),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: BillingCalculator.canClose(c, invoice) ? _close : null,
              icon: const Icon(Icons.task_alt),
              label: const Text('Cerrar caso'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _payment(Invoice invoice, Payment? payment) {
    if (invoice.copay == 0) return const Text('Sin copago: el seguro cubre el 100%.');
    if (payment != null) {
      return Text(
        'Pagado con ${payment.method.label} · ${Formatters.money(payment.amount)} · ${Formatters.dateTime(payment.at)}',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Método de pago (solo se registra el método; no se piden datos de tarjeta).'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final method in PaymentMethod.values)
              ChoiceChip(
                label: Text(method.label),
                selected: method == _method,
                onSelected: (_) => setState(() => _method = method),
              ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _run(
            () => context.read<CaseProvider>().registerPayment(_case.id, staff: _staff, method: _method),
            'Pago registrado.',
          ),
          icon: const Icon(Icons.point_of_sale),
          label: Text('Registrar pago de copago ${Formatters.money(invoice.copay)}'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
```

En `saludconecta/lib/core/router/app_router.dart`, agregar después de `import '../../features/auth/welcome_screen.dart';`:

```dart
import '../../features/billing/billing_pending_screen.dart';
import '../../features/billing/closure_screen.dart';
```

cambiar la pestaña "Pendientes":

```dart
            (context, state) => CaseListScreen(
              title: 'Pendientes de cierre',
              subtitle: 'Casos con el paso 9 pendiente',
              select: (cases, session) => cases.billingInbox(),
            ),
```

por:

```dart
            (context, state) => const BillingPendingScreen(),
```

y, en `_caseAction`:

```dart
        CaseAction.closure => const ComingSoonScreen(title: 'Cierre administrativo', stage: 8),
```

por:

```dart
        CaseAction.closure => ClosureScreen(caseId: caseId),
```

- [ ] **Step 4: Ejecutar la prueba y verificar que pasa**

```powershell
& $flutter test test/features/billing/closure_test.dart
```

Expected: `All tests passed!` (2 pruebas).

---

### Task 2: Reclamaciones

**Files:**
- Create: `saludconecta/lib/features/billing/claims_screen.dart`
- Modify: `saludconecta/lib/core/router/app_router.dart` (edición)
- Delete: `saludconecta/lib/features/shared/case_list_screen.dart`
- Test: `saludconecta/test/features/billing/claims_test.dart`

**Interfaces:**
- Produces: `ClaimsScreen()`, con los filtros "Todas", "Aprobada", "Pendiente" y "Glosada" (cada uno con su contador) y una fila por reclamación.

- [ ] **Step 1: Escribir la prueba**

Create `saludconecta/test/features/billing/claims_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/domain/models/enums.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('las reclamaciones se filtran por estado y cada filtro dice cuántas hay', (tester) async {
    final deps = staffDependencies(UserRole.billing);
    int count(ClaimStatus status) => deps.cases.cases.where((c) => c.billing?.claimStatus == status).length;
    final approved = count(ClaimStatus.approved);
    final objected = count(ClaimStatus.objected);
    expect(objected, greaterThan(0));

    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(AppRoutes.billingClaims);
    await tester.pumpAndSettle();
    expect(find.text('Reclamaciones'), findsWidgets);
    expect(find.text('Aprobada ($approved)'), findsOneWidget);

    await tester.tap(find.text('Glosada ($objected)'));
    await tester.pumpAndSettle();
    expect(find.text('Aprobada'), findsNothing);
    expect(find.text('Glosada'), findsWidgets);
  });
}
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla**

```powershell
& $flutter test test/features/billing/claims_test.dart
```

Expected: FAIL. "Reclamaciones" todavía es `ComingSoonScreen`.

- [ ] **Step 3: Crear la pantalla y quitar la lista provisional**

Create `saludconecta/lib/features/billing/claims_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../state/case_provider.dart';

/// Reclamaciones al seguro (§6 Facturación): históricas y en vivo, con filtro por estado.
class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  /// `null` = todas.
  ClaimStatus? _filter;

  static const _statuses = [ClaimStatus.approved, ClaimStatus.pending, ClaimStatus.objected];

  static Color colorOf(ClaimStatus status) => switch (status) {
        ClaimStatus.approved => AppColors.done,
        ClaimStatus.pending => AppColors.currentText,
        ClaimStatus.objected => AppColors.danger,
        ClaimStatus.notApplicable => AppColors.pending,
      };

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final catalog = context.read<CatalogRepository>();
    final claims = [
      for (final c in cases.cases)
        if (_statuses.contains(c.billing?.claimStatus)) c,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final shown = [
      for (final c in claims)
        if (_filter == null || c.billing!.claimStatus == _filter) c,
    ];
    final total = shown.fold<int>(0, (sum, c) => sum + c.billing!.invoice.insurerAmount);
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Reclamaciones', style: theme.textTheme.headlineSmall),
          Text('${shown.length} reclamaciones · ${Formatters.money(total)} a cargo de los seguros',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('Todas (${claims.length})'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final status in _statuses)
                ChoiceChip(
                  label: Text('${status.label} (${claims.where((c) => c.billing!.claimStatus == status).length})'),
                  selected: _filter == status,
                  onSelected: (_) => setState(() => _filter = status),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final c in shown) _ClaimTile(telemedicineCase: c, catalog: catalog),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimTile extends StatelessWidget {
  const _ClaimTile({required this.telemedicineCase, required this.catalog});

  final TelemedicineCase telemedicineCase;
  final CatalogRepository catalog;

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final billing = c.billing!;
    final patient = catalog.patientById(c.patientId);
    final color = _ClaimsScreenState.colorOf(billing.claimStatus);
    final theme = Theme.of(context);
    return ListTile(
      onTap: () => context.push(AppRoutes.caseDetail(c.id)),
      title: Text(patient.fullName),
      subtitle: Text(
        '${catalog.insurerById(patient.affiliation.insurerId).name} · ${billing.claimNumber ?? 'Sin número'} · ${c.id}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(Formatters.money(billing.invoice.insurerAmount), style: theme.textTheme.titleSmall),
          Text(
            billing.claimStatus.label,
            style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
```

En `saludconecta/lib/core/router/app_router.dart`, cambiar:

```dart
import '../../features/billing/billing_pending_screen.dart';
```

por:

```dart
import '../../features/billing/billing_pending_screen.dart';
import '../../features/billing/claims_screen.dart';
```

quitar `import '../../features/shared/case_list_screen.dart';`, y cambiar la pestaña "Reclamaciones":

```dart
              (context, state) => const ComingSoonScreen(title: 'Reclamaciones', stage: 8, inShell: true)),
```

por:

```dart
              (context, state) => const ClaimsScreen()),
```

Después, borrar `saludconecta/lib/features/shared/case_list_screen.dart`.

- [ ] **Step 4: Ejecutar las pruebas y verificar que pasan**

```powershell
& $flutter test test/features
```

Expected: `All tests passed!`

---

### Task 3: Verificación y commit de la etapa

- [ ] **Step 1:** `dart format -l 120 lib test` (0 cambios), `flutter test` y `flutter analyze` (sin avisos).
- [ ] **Step 2: Recorrido:** Roberto Díaz → Pendientes → Ramón → "Cerrar caso". Envía la reclamación, registra el pago, revisa la auditoría y cierra. Después, Reclamaciones con sus filtros. El recorrido va en la web o, si el panel no responde, en el emulador.
- [ ] **Step 3: Android:** capturar el cierre administrativo en el teléfono.
- [ ] **Step 4: Hoja de ruta:** fila de la etapa 8 con el enlace a este plan y "hecha".
- [ ] **Step 5: Commit:** "feat: flujo de Facturación de SaludConecta (etapa 8)".

Siguiente paso: el plan de la etapa 9, `2026-11-10-saludconecta-09-indicadores.md`.
