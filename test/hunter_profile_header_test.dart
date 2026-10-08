import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hunt/features/profile/widgets/hunter_profile_header.dart';

import 'fixtures/mock_hunter_service.dart';

void main() {
  for (final width in [320.0, 390.0, 1200.0]) {
    testWidgets('header fits a $width pixel viewport', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HunterProfileHeader(
                profile: const MockHunterService().profile,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('64.0%'), findsOneWidget);
      expect(find.text('38.0%'), findsOneWidget);
      final card = find
          .descendant(
            of: find.byType(HunterProfileHeader),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getSize(card).width, lessThanOrEqualTo(800));
      if (width > 800) {
        expect(tester.getCenter(card).dx, width / 2);
      }
    });
  }

  testWidgets('tabs change selection and notify the parent', (tester) async {
    HunterProfileTab? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HunterProfileHeader(
              profile: const MockHunterService().profile,
              onTabChanged: (tab) => selected = tab,
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('武器特质'));
    await tester.tap(find.text('武器特质'));
    await tester.pumpAndSettle();
    expect(selected, HunterProfileTab.weaponTraits);
    await tester.tap(find.text('个人战力'));
    await tester.pumpAndSettle();
    expect(selected, HunterProfileTab.power);
    expect(tester.takeException(), isNull);
  });
}
