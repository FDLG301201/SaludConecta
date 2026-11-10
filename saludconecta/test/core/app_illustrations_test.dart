import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/constants/app_illustrations.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';

void main() {
  test('el catálogo tiene las 29 ilustraciones del spec, sin repetir', () {
    expect(AppIllustrations.all, hasLength(29));
    expect(AppIllustrations.all.toSet(), hasLength(29));
    expect(AppIllustrations.doctors, hasLength(7));
    expect(AppIllustrations.patients, hasLength(6));
    expect(AppIllustrations.scenes, hasLength(13));
    expect(AppIllustrations.insurers, hasLength(3));
    expect(AppIllustrations.onboarding, hasLength(3));
  });

  test('cada rol tiene su ilustración', () {
    for (final role in UserRole.values) {
      expect(AppIllustrations.all, contains(AppIllustrations.forRole(role)), reason: role.label);
    }
  });

  test('los datos semilla solo usan ilustraciones del catálogo', () {
    final referenced = <String>[
      for (final d in SeedCatalog.doctors) d.avatarAsset,
      for (final p in SeedCatalog.demoPatients) p.avatarAsset!,
      for (final i in SeedCatalog.insurers) i.symbolAsset,
      for (final s in SeedCatalog.staff)
        if (s.avatarAsset != null) s.avatarAsset!,
    ];
    expect(referenced, hasLength(7 + 6 + 3 + 1));
    for (final path in referenced) {
      expect(AppIllustrations.all, contains(path), reason: path);
    }
  });

  test('las 2 infografías del equipo están en los assets', () {
    expect(File(AppIllustrations.processInfographic).existsSync(), isTrue);
    expect(File(AppIllustrations.servicesInfographic).existsSync(), isTrue);
  });
}
