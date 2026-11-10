import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/case_records.dart';

/// Trazos de la firma en coordenadas normalizadas (de 0 a 1), como los guarda `ConsentRecord`.
class SignatureController extends ChangeNotifier {
  final List<List<SignaturePoint>> _strokes = [];

  /// Copia de los trazos: cada trazo es una lista de puntos.
  List<List<SignaturePoint>> get strokes => [for (final stroke in _strokes) List.unmodifiable(stroke)];

  /// Hay firma si algún trazo tiene al menos dos puntos (la misma regla del dominio).
  bool get hasSignature => _strokes.any((stroke) => stroke.length >= 2);

  /// Empieza un trazo en [position], dentro de un lienzo de tamaño [size].
  void begin(Offset position, Size size) {
    _strokes.add([_normalize(position, size)]);
    notifyListeners();
  }

  /// Agrega [position] al trazo actual.
  void extend(Offset position, Size size) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(_normalize(position, size));
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  static SignaturePoint _normalize(Offset position, Size size) =>
      SignaturePoint(_unit(position.dx / size.width), _unit(position.dy / size.height));

  static double _unit(double value) => value < 0 ? 0.0 : (value > 1 ? 1.0 : value);
}

/// Recuadro para firmar con el dedo (o con el mouse en la web).
class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.controller, this.height = 160});

  final SignatureController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, height);
        return GestureDetector(
          // El trazo empieza donde se apoya el dedo, no cuando el gesto se reconoce.
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (details) => controller.begin(details.localPosition, size),
          onPanUpdate: (details) => controller.extend(details.localPosition, size),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.pending.withOpacity(0.6)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(size: size, painter: SignaturePainter(controller)),
            ),
          ),
        );
      },
    );
  }
}

/// Pinta la línea base y los trazos; se repinta cada vez que cambia el controlador.
class SignaturePainter extends CustomPainter {
  SignaturePainter(this.controller) : super(repaint: controller);

  final SignatureController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = AppColors.pending.withOpacity(0.5)
      ..strokeWidth = 1;
    final y = size.height * 0.78;
    canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), baseline);

    final ink = Paint()
      ..color = AppColors.navy
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in controller.strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.x * size.width, stroke.first.y * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.x * size.width, point.y * size.height);
      }
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => oldDelegate.controller != controller;
}
