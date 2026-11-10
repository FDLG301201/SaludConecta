import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/people.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_exception.dart';
import '../../../domain/process/process_step.dart';
import '../../../state/case_provider.dart';
import '../patient_case_builder.dart';
import 'signature_pad.dart';

/// Texto del consentimiento informado (redactado para la demostración).
const consentText = 'Autorizo a SaludConecta y a su equipo de salud a atenderme por telemedicina: una consulta '
    'por videollamada en la que el médico evalúa mis síntomas, me orienta y puede emitir recetas, órdenes de '
    'estudios, indicaciones o un referimiento a consulta presencial.\n\n'
    'Entiendo que la telemedicina no sustituye la atención de emergencias y que, si el médico lo considera '
    'necesario, me indicará acudir a un centro de salud. La videollamada no se graba. Mis datos de salud son '
    'confidenciales y solo los usa el personal que participa en mi atención.\n\n'
    'Puedo retirar este consentimiento antes de la consulta cancelando la cita desde la app.\n\n'
    'Documento de demostración del proyecto académico SaludConecta (ISO910, UNAPEC).';

/// Paso 6: consentimiento informado y admisión virtual. Las tres casillas y la firma son obligatorias.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return PatientCaseBuilder(
      caseId: caseId,
      builder: (context, c, patient) {
        final consent = c.consent;
        if (consent != null) {
          final inWaitingRoom = c.status == CaseStatus.active && c.currentStep == ProcessStep.consultation;
          return CaseNotice(
            screenTitle: 'Consentimiento informado',
            title: 'Ya firmaste el consentimiento',
            message: 'Lo firmaste el ${Formatters.dateTime(consent.at)}.',
            action: inWaitingRoom
                ? FilledButton.icon(
                    onPressed: () => context.pushReplacement(AppRoutes.caseAction(c.id, CaseAction.waitingRoom)),
                    icon: const Icon(Icons.meeting_room),
                    label: const Text('Ir a la sala de espera'),
                  )
                : null,
          );
        }
        if (c.status != CaseStatus.active || c.currentStep != ProcessStep.consentAdmission) {
          return const CaseNotice(
            screenTitle: 'Consentimiento informado',
            title: 'Aún no puedes firmar',
            message: 'El consentimiento se firma después de que Admisión te confirme la cita.',
          );
        }
        return _ConsentForm(telemedicineCase: c, patient: patient);
      },
    );
  }
}

class _ConsentForm extends StatefulWidget {
  const _ConsentForm({required this.telemedicineCase, required this.patient});

  final TelemedicineCase telemedicineCase;
  final Patient patient;

  @override
  State<_ConsentForm> createState() => _ConsentFormState();
}

class _ConsentFormState extends State<_ConsentForm> {
  final _signature = SignatureController();
  bool _terms = false;
  bool _dataUse = false;
  bool _identity = false;

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  void _sign() {
    final c = widget.telemedicineCase;
    final cases = context.read<CaseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    // Un mensaje nuevo reemplaza al anterior en lugar de esperar su turno.
    messenger.removeCurrentSnackBar();
    try {
      cases.signConsent(
        c.id,
        patient: widget.patient,
        acceptedTerms: _terms,
        acceptedDataUse: _dataUse,
        identityConfirmed: _identity,
        signature: _signature.strokes,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Consentimiento firmado. Pasa a la sala de espera.')));
      context.pushReplacement(AppRoutes.caseAction(c.id, CaseAction.waitingRoom));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.telemedicineCase;
    final patient = widget.patient;
    final catalog = context.read<CatalogRepository>();
    final appointment = c.appointment;
    final doctor = appointment == null ? null : catalog.doctorById(appointment.doctorId);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Consentimiento informado')),
      body: PageBody(
        child: ListView(
          children: [
            if (appointment != null && doctor != null)
              Card(
                child: ListTile(
                  leading: AvatarImage(name: doctor.displayName, asset: doctor.avatarAsset, size: 44),
                  title: Text('${catalog.serviceById(c.serviceId).name} con ${doctor.displayName}'),
                  subtitle: Text('${Formatters.dateTime(appointment.dateTime)} · ${appointment.platform.label}'),
                ),
              ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Consentimiento informado para telemedicina',
              icon: Icons.description_outlined,
              child: Text(consentText, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _terms,
              onChanged: (value) => setState(() => _terms = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('He leído y acepto el consentimiento informado'),
            ),
            CheckboxListTile(
              value: _dataUse,
              onChanged: (value) => setState(() => _dataUse = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Autorizo el uso de mis datos de salud para esta atención'),
            ),
            CheckboxListTile(
              value: _identity,
              onChanged: (value) => setState(() => _identity = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('Confirmo mi identidad: ${patient.fullName}, cédula ${patient.cedula}'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      // La firma va fija abajo, fuera de la lista: así el gesto de firmar no desplaza la pantalla
      // y los avisos (`SnackBar`) aparecen encima, sin tapar el botón.
      bottomNavigationBar: Material(
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: PageBody.maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Tu firma', style: theme.textTheme.titleMedium),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _signature.clear,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Borrar'),
                        ),
                      ],
                    ),
                    SignaturePad(controller: _signature, height: 130),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _sign,
                      icon: const Icon(Icons.draw),
                      label: const Text('Firmar y continuar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
