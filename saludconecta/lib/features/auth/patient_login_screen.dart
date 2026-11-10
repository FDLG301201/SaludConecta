import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../state/session_provider.dart';

/// Ingreso del paciente con su número de carnet. Los chips rellenan el campo con los 6 pacientes demo.
class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({super.key});

  @override
  State<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Escribe tu número de carnet.';
    if (context.read<CatalogRepository>().patientByAffiliateNumber(text) == null) {
      return 'No encontramos ese carnet. Revisa el número.';
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final patient = context.read<CatalogRepository>().patientByAffiliateNumber(_number.text);
    if (patient == null) return;
    final router = GoRouter.of(context);
    context.read<SessionProvider>().loginPatient(patient);
    router.go(AppRoutes.patientHome);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogRepository>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ingreso de paciente')),
      body: PageBody(
        child: ListView(
          children: [
            const AppIllustration(AppIllustrations.rolePatient, height: 130),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _number,
                decoration: const InputDecoration(
                  labelText: 'Número de carnet de seguro',
                  hintText: 'Ej.: SP-100245',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: _validate,
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Pacientes de demostración', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in catalog.demoPatients)
                  ActionChip(
                    avatar: AvatarImage(name: p.fullName, asset: p.avatarAsset, size: 24),
                    label: Text(p.fullName),
                    onPressed: () {
                      _number.text = p.affiliation.affiliateNumber;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.login), label: const Text('Ingresar')),
          ],
        ),
      ),
    );
  }
}
