import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_illustrations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_illustration.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/people.dart';

/// Desde qué lado se ve la videollamada.
enum CallPerspective { patient, doctor }

/// Un mensaje del chat de la videollamada (simulado: no sale de la app).
class CallMessage {
  const CallMessage({required this.fromMe, required this.text});

  final bool fromMe;
  final String text;
}

/// Videollamada simulada (§6 del spec): el otro participante a pantalla completa, el propio video en un
/// recuadro, cronómetro, plataforma, conexión y controles. La usan el paciente (etapa 5) y el médico
/// (etapa 7, que agrega sus notas clínicas en [extraControls]).
class VideoCallView extends StatefulWidget {
  const VideoCallView({
    super.key,
    required this.perspective,
    required this.doctor,
    required this.patient,
    required this.platform,
    required this.onHangUp,
    this.extraControls = const [],
  });

  final CallPerspective perspective;
  final Doctor doctor;
  final Patient patient;
  final VideoPlatform platform;

  /// Qué pasa al colgar: el paciente sale; el médico finaliza la consulta.
  final VoidCallback onHangUp;

  /// Botones extra de la barra inferior, antes de "Colgar".
  final List<Widget> extraControls;

  @override
  State<VideoCallView> createState() => _VideoCallViewState();
}

class _VideoCallViewState extends State<VideoCallView> with SingleTickerProviderStateMixin {
  late final AnimationController _speaking;
  late final ValueNotifier<List<CallMessage>> _messages;
  Timer? _clock;
  int _seconds = 0;
  bool _micOn = true;
  bool _cameraOn = true;

  bool get _isPatient => widget.perspective == CallPerspective.patient;

  @override
  void initState() {
    super.initState();
    _speaking = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _messages = ValueNotifier([
      CallMessage(
        fromMe: !_isPatient,
        text: 'Hola, ${widget.patient.firstName}. Soy ${widget.doctor.displayName}. ¿Me escuchas bien?',
      ),
      CallMessage(fromMe: _isPatient, text: 'Sí, se escucha bien. Gracias.'),
    ]);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _speaking.dispose();
    _messages.dispose();
    super.dispose();
  }

  /// Cronómetro "mm:ss".
  String get _elapsed {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(_seconds ~/ 60)}:${two(_seconds % 60)}';
  }

  void _openChat() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        // Sube la hoja cuando aparece el teclado.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: _ChatSheet(messages: _messages),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final patient = widget.patient;
    final remoteName = _isPatient ? doctor.displayName : patient.fullName;
    final remoteSubtitle = _isPatient ? doctor.specialty.label : 'Carnet ${patient.affiliation.affiliateNumber}';
    final remoteAvatar = _isPatient ? doctor.avatarAsset : patient.avatarAsset;
    final remoteRoom = _isPatient ? AppIllustrations.roomClinic : AppIllustrations.roomHome;
    final localName = _isPatient ? patient.fullName : doctor.displayName;
    final localAvatar = _isPatient ? patient.avatarAsset : doctor.avatarAsset;
    final localRoom = _isPatient ? AppIllustrations.roomHome : AppIllustrations.roomClinic;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          Positioned.fill(child: AppIllustration(remoteRoom, fit: BoxFit.cover)),
          Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(0.2))),
          Center(child: _SpeakingAvatar(animation: _speaking, name: remoteName, asset: remoteAvatar)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Degradado oscuro detrás de la barra: el texto blanco se lee sobre cualquier fondo.
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                  child: _TopBar(
                    name: remoteName,
                    subtitle: remoteSubtitle,
                    platform: widget.platform,
                    elapsed: _elapsed,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 104,
            child: _SelfView(name: localName, asset: localAvatar, room: localRoom, cameraOn: _cameraOn, micOn: _micOn),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    CallControlButton(
                      icon: _micOn ? Icons.mic : Icons.mic_off,
                      tooltip: _micOn ? 'Silenciar micrófono' : 'Activar micrófono',
                      active: _micOn,
                      onPressed: () => setState(() => _micOn = !_micOn),
                    ),
                    CallControlButton(
                      icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
                      tooltip: _cameraOn ? 'Apagar cámara' : 'Encender cámara',
                      active: _cameraOn,
                      onPressed: () => setState(() => _cameraOn = !_cameraOn),
                    ),
                    CallControlButton(icon: Icons.chat_bubble_outline, tooltip: 'Chat', onPressed: _openChat),
                    ...widget.extraControls,
                    CallControlButton(
                      icon: Icons.call_end,
                      tooltip: 'Colgar',
                      color: AppColors.danger,
                      onPressed: widget.onHangUp,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón redondo de la barra de la videollamada.
class CallControlButton extends StatelessWidget {
  const CallControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = true,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// `false` cuando el micrófono o la cámara están apagados: el botón se ve blanco.
  final bool active;

  /// Color de fondo fijo (p. ej., rojo para colgar).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final background = color ?? (active ? Colors.white24 : Colors.white);
    final foreground = color != null || active ? Colors.white : AppColors.navy;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 26,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        fixedSize: const Size(56, 56),
      ),
      icon: Icon(icon),
    );
  }
}

/// Avatar del otro participante con un anillo que "respira" mientras habla.
class _SpeakingAvatar extends AnimatedWidget {
  const _SpeakingAvatar({required Animation<double> animation, required this.name, required this.asset})
      : super(listenable: animation);

  final String name;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: 1 + 0.12 * t,
            child: Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary.withOpacity(0.35 + 0.5 * t), width: 4),
              ),
            ),
          ),
          AvatarImage(name: name, asset: asset, size: 150),
        ],
      ),
    );
  }
}

/// Nombre y especialidad del otro participante, plataforma, cronómetro y conexión.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.name, required this.subtitle, required this.platform, required this.elapsed});

  final String name;
  final String subtitle;
  final VideoPlatform platform;
  final String elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            // Sin esto, la columna ocupa toda la altura y la fila centra las píldoras a media pantalla.
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ],
          ),
        ),
        _Pill(icon: AppIcons.platform(platform), label: platform.label),
        const SizedBox(width: 8),
        _Pill(icon: Icons.fiber_manual_record, label: elapsed, iconColor: Colors.redAccent),
        const SizedBox(width: 8),
        const Tooltip(
          message: 'Conexión estable',
          child: Icon(Icons.signal_cellular_alt, color: Colors.greenAccent),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.iconColor = Colors.white});

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// El propio video en un recuadro: con la cámara apagada se ven las iniciales.
class _SelfView extends StatelessWidget {
  const _SelfView({
    required this.name,
    required this.asset,
    required this.room,
    required this.cameraOn,
    required this.micOn,
  });

  final String name;
  final String? asset;
  final String room;
  final bool cameraOn;
  final bool micOn;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 110,
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraOn) AppIllustration(room, fit: BoxFit.cover) else const ColoredBox(color: Color(0xFF263238)),
            Center(child: AvatarImage(name: name, asset: cameraOn ? asset : null, size: 64)),
            if (!micOn) const Positioned(top: 6, right: 6, child: Icon(Icons.mic_off, color: Colors.white, size: 18)),
            const Positioned(
              left: 8,
              bottom: 6,
              child: Text('Tú', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat de la consulta: mensajes simulados en los que se puede escribir.
class _ChatSheet extends StatefulWidget {
  const _ChatSheet({required this.messages});

  final ValueNotifier<List<CallMessage>> messages;

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    widget.messages.value = [...widget.messages.value, CallMessage(fromMe: true, text: text)];
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Chat de la consulta', style: theme.textTheme.titleMedium),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<CallMessage>>(
              valueListenable: widget.messages,
              builder: (context, messages, _) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final m in messages)
                    Align(
                      alignment: m.fromMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: m.fromMe ? AppColors.primary : theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(m.text, style: TextStyle(color: m.fromMe ? Colors.white : null)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _send, tooltip: 'Enviar', icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
