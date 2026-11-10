import 'package:flutter/material.dart';

/// Botón que muestra un indicador de carga y se deshabilita mientras [loading] es `true`
/// (operaciones lentas: seguro, envío del enlace, reclamación).
class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const spinner = SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4));
    if (!loading && icon == null) {
      return FilledButton(onPressed: onPressed, child: Text(label));
    }
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading ? spinner : Icon(icon),
      label: Text(label),
    );
  }
}
