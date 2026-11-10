import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Elementos que las ilustraciones no deben usar (flutter_svg no los dibuja o el spec los prohíbe).
const unsupportedSvgElements = ['<text', '<filter', '<mask', '<style', '<image', '<script', '<foreignObject'];

/// Verifica que [path] exista, que respete las restricciones del spec y que flutter_svg lo interprete.
Future<void> expectValidSvg(String path) async {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'falta $path');
  final svg = file.readAsStringSync();
  expect(svg, contains('viewBox'), reason: '$path no tiene viewBox');
  for (final element in unsupportedSvgElements) {
    expect(svg.contains(element), isFalse, reason: '$path usa $element');
  }
  // Lo compila el mismo código que usa SvgPicture: si el SVG está mal escrito, aquí falla.
  final bytes = await SvgStringLoader(svg).loadBytes(null);
  expect(bytes.lengthInBytes, greaterThan(0), reason: path);
}
