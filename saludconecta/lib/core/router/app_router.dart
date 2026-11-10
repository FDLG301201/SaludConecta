import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/enums.dart';
import '../../features/admission/admission_agenda_screen.dart';
import '../../features/admission/admission_inbox_screen.dart';
import '../../features/admission/follow_up_screen.dart';
import '../../features/admission/process_case_screen.dart';
import '../../features/auth/patient_login_screen.dart';
import '../../features/auth/role_selection_screen.dart';
import '../../features/auth/staff_login_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/patient/appointments_screen.dart';
import '../../features/patient/call/patient_video_call_screen.dart';
import '../../features/patient/consent/consent_screen.dart';
import '../../features/patient/patient_home_screen.dart';
import '../../features/patient/profile/profile_screen.dart';
import '../../features/patient/request/request_appointment_screen.dart';
import '../../features/patient/results/results_screen.dart';
import '../../features/patient/services_screen.dart';
import '../../features/patient/survey/survey_screen.dart';
import '../../features/patient/waiting_room/waiting_room_screen.dart';
import '../../features/shared/case_detail/case_detail_screen.dart';
import '../../features/shared/case_list_screen.dart';
import '../../features/shared/not_found_screen.dart';
import '../../features/shared/role_shell.dart';
import '../../state/session_provider.dart';
import '../widgets/coming_soon_screen.dart';
import 'app_routes.dart';
import 'route_guard.dart';

/// Rutas de la app (§6 del spec) con `redirect` por rol. Lo que se construye en etapas posteriores
/// apunta por ahora a `ComingSoonScreen`; cada etapa reemplaza su pantalla aquí.
class AppRouter {
  const AppRouter._();

  static GoRouter create({required SessionProvider session, String initialLocation = AppRoutes.welcome}) {
    return GoRouter(
      initialLocation: initialLocation,
      // Cuando cambia la sesión, go_router vuelve a evaluar el redirect.
      refreshListenable: session,
      redirect: (context, state) => RouteGuard.redirect(state.uri.path, session.role),
      errorBuilder: (context, state) => const NotFoundScreen(),
      routes: [
        GoRoute(path: AppRoutes.welcome, builder: (context, state) => const WelcomeScreen()),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const RoleSelectionScreen(),
          routes: [
            GoRoute(path: 'paciente', builder: (context, state) => const PatientLoginScreen()),
            GoRoute(
              path: 'personal/:rol',
              builder: (context, state) {
                final role = UserRole.fromSlug(state.pathParameters['rol']!);
                if (role == null || role == UserRole.patient) return const NotFoundScreen();
                return StaffLoginScreen(role: role);
              },
            ),
          ],
        ),
        _shell(UserRole.patient, [
          _Tab(AppRoutes.patientHome, 'Inicio', Icons.home_outlined, Icons.home,
              (context, state) => const PatientHomeScreen()),
          _Tab(AppRoutes.patientAppointments, 'Mis citas', Icons.event_note_outlined, Icons.event_note,
              (context, state) => const AppointmentsScreen()),
          _Tab(AppRoutes.patientServices, 'Servicios', Icons.medical_services_outlined, Icons.medical_services,
              (context, state) => const ServicesScreen()),
          _Tab(AppRoutes.patientProfile, 'Perfil', Icons.person_outline, Icons.person,
              (context, state) => const ProfileScreen()),
        ]),
        GoRoute(
          path: AppRoutes.requestAppointmentPath,
          // `?servicio=` y `?fecha=` llegan desde Servicios y desde los resultados (cita de seguimiento).
          builder: (context, state) => RequestAppointmentScreen(
            initialServiceId: state.uri.queryParameters['servicio'],
            initialDate: DateTime.tryParse(state.uri.queryParameters['fecha'] ?? ''),
          ),
        ),
        _shell(UserRole.admission, [
          _Tab(
            AppRoutes.admissionInbox,
            'Bandeja',
            Icons.inbox_outlined,
            Icons.inbox,
            (context, state) => const AdmissionInboxScreen(),
          ),
          _Tab(AppRoutes.admissionAgenda, 'Agenda', Icons.calendar_month_outlined, Icons.calendar_month,
              (context, state) => const AdmissionAgendaScreen()),
          _Tab(
            AppRoutes.admissionFollowUp,
            'Seguimiento',
            Icons.call_outlined,
            Icons.call,
            (context, state) => const FollowUpScreen(),
          ),
          _Tab(AppRoutes.admissionIndicators, 'Indicadores', Icons.insights_outlined, Icons.insights,
              (context, state) => const ComingSoonScreen(title: 'Indicadores', stage: 9, inShell: true)),
        ]),
        _shell(UserRole.doctor, [
          _Tab(
            AppRoutes.doctorAgenda,
            'Agenda',
            Icons.event_available_outlined,
            Icons.event_available,
            (context, state) => CaseListScreen(
              title: 'Mi agenda',
              subtitle: 'Citas con los pasos 6 a 8 pendientes',
              select: (cases, session) => cases.doctorAgenda(session.currentDoctor?.id ?? ''),
            ),
          ),
          _Tab(AppRoutes.doctorIndicators, 'Indicadores', Icons.insights_outlined, Icons.insights,
              (context, state) => const ComingSoonScreen(title: 'Indicadores', stage: 9, inShell: true)),
        ]),
        _shell(UserRole.billing, [
          _Tab(
            AppRoutes.billingPending,
            'Pendientes',
            Icons.pending_actions_outlined,
            Icons.pending_actions,
            (context, state) => CaseListScreen(
              title: 'Pendientes de cierre',
              subtitle: 'Casos con el paso 9 pendiente',
              select: (cases, session) => cases.billingInbox(),
            ),
          ),
          _Tab(AppRoutes.billingClaims, 'Reclamaciones', Icons.receipt_long_outlined, Icons.receipt_long,
              (context, state) => const ComingSoonScreen(title: 'Reclamaciones', stage: 8, inShell: true)),
          _Tab(AppRoutes.billingIndicators, 'Indicadores', Icons.insights_outlined, Icons.insights,
              (context, state) => const ComingSoonScreen(title: 'Indicadores', stage: 9, inShell: true)),
        ]),
        GoRoute(
          path: '/caso/:id',
          builder: (context, state) => CaseDetailScreen(caseId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'diagrama',
              builder: (context, state) => const ComingSoonScreen(title: 'Diagrama del caso', stage: 10),
            ),
            for (final action in CaseAction.values)
              GoRoute(
                path: action.segment,
                builder: (context, state) => _caseAction(action, state.pathParameters['id']!),
              ),
          ],
        ),
        GoRoute(
          path: AppRoutes.process,
          builder: (context, state) => const ComingSoonScreen(title: 'Diagramas del proceso', stage: 10),
        ),
        GoRoute(
          path: AppRoutes.about,
          builder: (context, state) => const ComingSoonScreen(title: 'Acerca de', stage: 10),
        ),
      ],
    );
  }

  /// Pantalla de cada acción sobre un caso; las que aún no se construyen apuntan a `ComingSoonScreen`.
  static Widget _caseAction(CaseAction action, String caseId) => switch (action) {
        CaseAction.consent => ConsentScreen(caseId: caseId),
        CaseAction.waitingRoom => WaitingRoomScreen(caseId: caseId),
        CaseAction.videoCall => PatientVideoCallScreen(caseId: caseId),
        CaseAction.results => ResultsScreen(caseId: caseId),
        CaseAction.survey => SurveyScreen(caseId: caseId),
        CaseAction.process => ProcessCaseScreen(caseId: caseId),
        CaseAction.consultation => const ComingSoonScreen(title: 'Consulta', stage: 7),
        CaseAction.issueResults => const ComingSoonScreen(title: 'Emitir resultados', stage: 7),
        CaseAction.closure => const ComingSoonScreen(title: 'Cierre administrativo', stage: 8),
      };

  /// Shell de un rol: una rama por pestaña (`StatefulShellRoute.indexedStack` conserva cada pestaña).
  static StatefulShellRoute _shell(UserRole role, List<_Tab> tabs) {
    return StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => RoleShell(
        role: role,
        navigationShell: navigationShell,
        destinations: [for (final tab in tabs) tab.destination],
      ),
      branches: [
        for (final tab in tabs) StatefulShellBranch(routes: [GoRoute(path: tab.path, builder: tab.builder)]),
      ],
    );
  }
}

/// Una pestaña de un shell: su ruta, su ícono y su pantalla.
class _Tab {
  const _Tab(this.path, this.label, this.icon, this.selectedIcon, this.builder);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final GoRouterWidgetBuilder builder;

  RoleDestination get destination => RoleDestination(label: label, icon: icon, selectedIcon: selectedIcon);
}
