import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/constants/app_illustrations.dart';

import '../support/svg_checks.dart';

void main() {
  for (final path in [...AppIllustrations.doctors, ...AppIllustrations.patients]) {
    test('avatar válido: $path', () => expectValidSvg(path));
  }
}
