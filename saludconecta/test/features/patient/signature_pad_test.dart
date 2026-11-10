import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/features/patient/consent/signature_pad.dart';

void main() {
  test('guarda los puntos normalizados al tamaño del lienzo y exige dos puntos', () {
    final controller = SignatureController();
    const size = Size(200, 100);
    controller.begin(const Offset(50, 25), size);
    expect(controller.hasSignature, isFalse);

    controller.extend(const Offset(250, 120), size);
    expect(controller.hasSignature, isTrue);
    final stroke = controller.strokes.single;
    expect(stroke.first.x, 0.25);
    expect(stroke.first.y, 0.25);
    // Lo que sale del recuadro se recorta al borde.
    expect(stroke.last.x, 1.0);
    expect(stroke.last.y, 1.0);

    controller.clear();
    expect(controller.strokes, isEmpty);
  });

  testWidgets('dibujar sobre el recuadro crea un trazo', (tester) async {
    final controller = SignatureController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: SignaturePad(controller: controller)),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SignaturePad)));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(12, 4));
    }
    await gesture.up();
    await tester.pump();
    expect(controller.hasSignature, isTrue);
    expect(controller.strokes.single.length, greaterThan(2));
  });
}
