import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_step.dart';
import '../patient_case_builder.dart';
import 'connection_check.dart';

/// Sala de espera (paso 7, lado del paciente): prueba de conexión, Soporte TI y "Unirse a la consulta".
class WaitingRoomScreen extends StatelessWidget {
  const WaitingRoomScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return PatientCaseBuilder(
      caseId: caseId,
      builder: (context, c, patient) {
        if (c.status == CaseStatus.active && c.currentStep == ProcessStep.consultation && c.appointment != null) {
          return _WaitingRoom(telemedicineCase: c);
        }
        final needsConsent = c.status == CaseStatus.active && c.currentStep == ProcessStep.consentAdmission;
        return CaseNotice(
          screenTitle: 'Sala de espera',
          title: needsConsent ? 'Primero firma tu consentimiento' : 'La sala de espera no está disponible',
          message: needsConsent
              ? 'Después de firmarlo podrás entrar a la sala de espera.'
              : 'Tu consulta ya terminó o todavía no está agendada.',
          action: needsConsent
              ? FilledButton.icon(
                  onPressed: () => context.pushReplacement(AppRoutes.caseAction(c.id, CaseAction.consent)),
                  icon: const Icon(Icons.draw),
                  label: const Text('Firmar consentimiento'),
                )
              : null,
        );
      },
    );
  }
}

class _WaitingRoom extends StatefulWidget {
  const _WaitingRoom({required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  @override
  State<_WaitingRoom> createState() => _WaitingRoomState();
}

class _WaitingRoomState extends State<_WaitingRoom> {
  bool _ready = false;

  /// Reemplaza la sala de espera: al colgar se vuelve a la pantalla anterior.
  void _join() => context.pushReplacement(AppRoutes.caseAction(widget.telemedicineCase.id, CaseAction.videoCall));

  /// Llama a Soporte TI con el marcador del teléfono (`url_launcher` con `tel:`).
  Future<void> _callSupport(String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll('-', '')));
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo abrir el marcador. Llama al $phone.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.telemedicineCase.appointment!;
    final catalog = context.read<CatalogRepository>();
    final doctor = catalog.doctorById(appointment.doctorId);
    final support = catalog.staffFor(Actor.support);
    final phone = support.phone;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sala de espera')),
      body: PageBody(
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AvatarImage(name: doctor.displayName, asset: doctor.avatarAsset, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doctor.displayName, style: theme.textTheme.titleMedium),
                          Text(doctor.specialty.label, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 4),
                          Text(Formatters.dateTime(appointment.dateTime), style: theme.textTheme.bodySmall),
                          const SizedBox(height: 8),
                          Chip(
                            avatar: Icon(AppIcons.platform(appointment.platform), size: 18),
                            label: Text(appointment.platform.label),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Prueba de conexión',
              icon: Icons.network_check,
              child: ConnectionCheck(
                platform: appointment.platform,
                onFinished: () => setState(() => _ready = true),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '¿Problemas para conectarte?',
              icon: Icons.support_agent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarImage(name: support.fullName, asset: support.avatarAsset, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(support.fullName, style: theme.textTheme.titleSmall),
                            Text(
                              '${Actor.support.label} · ${phone ?? 'sin teléfono'}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: phone == null ? null : () => _callSupport(phone),
                    icon: const Icon(Icons.call),
                    label: const Text('Llamar a soporte'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      // "Unirse a la consulta" queda fijo abajo: siempre a la vista, aunque la lista sea larga.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PageBody.maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _ready ? _join : null,
                  icon: const Icon(Icons.video_call),
                  label: Text(_ready ? 'Unirse a la consulta' : 'Comprobando tu conexión…'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
