import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../domain/models/enums.dart';

/// Prueba de conexión de la sala de espera (simulada): internet, cámara, micrófono y plataforma.
/// Revisa un elemento cada [stepDuration] y avisa con [onFinished] al terminar.
class ConnectionCheck extends StatefulWidget {
  const ConnectionCheck({super.key, required this.platform, required this.onFinished});

  static const stepDuration = Duration(milliseconds: 600);

  final VideoPlatform platform;
  final VoidCallback onFinished;

  @override
  State<ConnectionCheck> createState() => _ConnectionCheckState();
}

class _ConnectionCheckState extends State<ConnectionCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _levels;
  Timer? _timer;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _levels = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _timer = Timer.periodic(ConnectionCheck.stepDuration, (timer) {
      setState(() => _done++);
      if (_done == 4) {
        timer.cancel();
        _levels.stop();
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _levels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checks = [
      (Icons.wifi, 'Internet', 'Latencia de 42 ms: conexión estable'),
      (Icons.videocam_outlined, 'Cámara', 'Imagen nítida'),
      (Icons.mic_none, 'Micrófono', 'Nivel de audio correcto'),
      (AppIcons.platform(widget.platform), widget.platform.label, 'Plataforma operativa'),
    ];
    return Column(
      children: [
        for (var i = 0; i < checks.length; i++)
          _CheckRow(
            icon: checks[i].$1,
            title: checks[i].$2,
            detail: checks[i].$3,
            done: i < _done,
            checking: i == _done,
            levels: i == 2 ? _levels : null,
          ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.done,
    required this.checking,
    this.levels,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool done;
  final bool checking;

  /// Animación de las barras de nivel (solo el micrófono).
  final Animation<double>? levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final animation = levels;
    final color = done ? AppColors.done : AppColors.primary;
    final Widget status;
    if (done) {
      status = const Icon(Icons.check_circle, color: AppColors.done);
    } else if (checking) {
      status = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4));
    } else {
      status = Icon(Icons.radio_button_unchecked, color: theme.colorScheme.outlineVariant);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(done ? detail : (checking ? 'Comprobando…' : 'En espera'), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (animation != null) ...[_LevelBars(animation: animation), const SizedBox(width: 12)],
          status,
        ],
      ),
    );
  }
}

/// Barras de nivel del micrófono que suben y bajan con la animación.
class _LevelBars extends AnimatedWidget {
  const _LevelBars({required Animation<double> animation}) : super(listenable: animation);

  static const _base = [0.35, 0.8, 0.55, 1.0, 0.45];

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _base.length; i++)
            Container(
              width: 4,
              height: 4 + 20 * _base[i] * (i.isEven ? t : 1 - t),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(color: AppColors.done, borderRadius: BorderRadius.circular(2)),
            ),
        ],
      ),
    );
  }
}
