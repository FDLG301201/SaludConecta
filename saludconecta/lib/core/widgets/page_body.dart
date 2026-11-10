import 'package:flutter/widgets.dart';

/// Contenido de una pantalla: arriba y al centro, con un ancho máximo de 1100 px (§6 del spec).
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  static const maxWidth = 1100.0;

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
