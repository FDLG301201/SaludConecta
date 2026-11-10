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
