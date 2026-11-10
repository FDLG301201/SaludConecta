import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/constants/app_illustrations.dart';
import 'package:saludconecta/core/widgets/app_illustration.dart';
import 'package:saludconecta/core/widgets/avatar_image.dart';

void main() {
  test('iniciales sin títulos', () {
    expect(AvatarImage.initialsOf('María Fernández'), 'MF');
    expect(AvatarImage.initialsOf('Dr. Carlos Méndez'), 'CM');
    expect(AvatarImage.initialsOf('Lic. Sofía Herrera'), 'SH');
    expect(AvatarImage.initialsOf('Ana'), 'A');
    expect(AvatarImage.initialsOf('   '), '?');
  });

  testWidgets('AvatarImage sin ilustración muestra las iniciales', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AvatarImage(name: 'Ana Peña'))));
    expect(find.text('AP'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('AvatarImage con ilustración muestra el SVG', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AvatarImage(name: 'María Fernández', asset: AppIllustrations.patients.first))),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('MF'), findsNothing);
  });

  testWidgets('AppIllustration dibuja el SVG del catálogo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppIllustration(AppIllustrations.logo, width: 96, height: 96))),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
