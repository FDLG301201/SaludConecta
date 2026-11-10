import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Muestra una ilustración SVG del catálogo (`AppIllustrations`).
class AppIllustration extends StatelessWidget {
  const AppIllustration(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      semanticsLabel: semanticLabel,
      // Mientras carga, reserva el espacio para que la pantalla no "salte".
      placeholderBuilder: (context) => SizedBox(width: width, height: height),
    );
  }
}
