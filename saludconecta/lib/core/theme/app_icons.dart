import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';
import '../../domain/process/process_step.dart';

/// Íconos de Material para los conceptos del dominio. El dominio no depende de Flutter:
/// guarda claves (`iconKey`) o enums, y aquí se traducen a `IconData`.
class AppIcons {
  const AppIcons._();

  static const _services = <String, IconData>{
    'stethoscope': Icons.medical_services,
    'monitor_heart': Icons.monitor_heart,
    'child_care': Icons.child_care,
    'female': Icons.female,
    'favorite': Icons.favorite,
    'psychology': Icons.psychology,
    'restaurant': Icons.restaurant,
    'groups': Icons.groups,
    'medication': Icons.medication,
    'event_available': Icons.event_available,
    'healing': Icons.healing,
    'fact_check': Icons.fact_check,
    'support_agent': Icons.support_agent,
    'school': Icons.school,
    'notifications_active': Icons.notifications_active,
    'thumb_up': Icons.thumb_up,
    'receipt_long': Icons.receipt_long,
    'science': Icons.science,
    'image_search': Icons.image_search,
    'alt_route': Icons.alt_route,
    'assignment': Icons.assignment,
    'calendar_month': Icons.calendar_month,
    'verified_user': Icons.verified_user,
    'verified': Icons.verified,
  };

  /// Ícono de un servicio por su `iconKey`.
  static IconData service(String iconKey) => _services[iconKey] ?? Icons.medical_services;

  static IconData channel(RequestChannel channel) => switch (channel) {
        RequestChannel.mobile => Icons.smartphone,
        RequestChannel.email => Icons.email_outlined,
        RequestChannel.whatsapp => Icons.chat_outlined,
        RequestChannel.webPortal => Icons.language,
        RequestChannel.phone => Icons.call_outlined,
      };

  /// Teams, Zoom y Meet se muestran por nombre con íconos genéricos (sin sus logos).
  static IconData platform(VideoPlatform platform) => switch (platform) {
        VideoPlatform.teams => Icons.groups_outlined,
        VideoPlatform.zoom => Icons.videocam_outlined,
        VideoPlatform.meet => Icons.video_call_outlined,
      };

  static IconData step(ProcessStep step) => switch (step) {
        ProcessStep.requestAppointment => Icons.edit_calendar,
        ProcessStep.reception => Icons.support_agent,
        ProcessStep.insuranceValidation => Icons.verified_user,
        ProcessStep.scheduling => Icons.calendar_month,
        ProcessStep.patientConfirmation => Icons.mark_email_read,
        ProcessStep.consentAdmission => Icons.draw,
        ProcessStep.consultation => Icons.video_camera_front,
        ProcessStep.consultationResult => Icons.receipt_long,
        ProcessStep.administrativeClosure => Icons.request_quote,
        ProcessStep.followUp => Icons.favorite,
      };

  static IconData actor(Actor actor) => switch (actor) {
        Actor.patient => Icons.person,
        Actor.admission => Icons.support_agent,
        Actor.doctor => Icons.medical_services,
        Actor.support => Icons.settings,
        Actor.billing => Icons.receipt_long,
      };

  static IconData role(UserRole role) => actor(role.actor);
}
