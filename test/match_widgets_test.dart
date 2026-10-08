import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hunt/features/match/widgets/match_card.dart';
import 'package:hunt/features/match/widgets/match_filter_bar.dart';

import 'fixtures/mock_hunter_service.dart';

void main() {
  final records = const MockHunterService().matchHistory;

  for (final width in [320.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('history fits width $width and text scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      MatchFilterBar(
                        selectedFilter: MatchFilter.all,
                        onChanged: (_) {},
                      ),
                      MatchCard(
                        record: records.first,
                        now: records.first.matchTime.add(
                          const Duration(hours: 2),
                        ),
                      ),
                      MatchCard(record: records[1], now: records[1].matchTime),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('2小时前'), findsOneWidget);
        expect(find.text('刚刚'), findsOneWidget);
        expect(find.text('3 / 0 / 1'), findsOneWidget);
        expect(find.text('MMR +18'), findsOneWidget);
        expect(find.text('MMR -12'), findsOneWidget);
        expect(find.text('成功撤离'), findsOneWidget);
        expect(find.text('阵亡'), findsOneWidget);
      });
    }
  }

  testWidgets('selection filters history and allows returning to all', (
    tester,
  ) async {
    var selected = MatchFilter.all;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                MatchFilterBar(
                  selectedFilter: selected,
                  onChanged: (filter) => setState(() => selected = filter),
                ),
                for (final record in records.where(selected.matches))
                  Text(record.matchId),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text(records.first.matchId), findsOneWidget);
    await tester.tap(find.text('仅阵亡'));
    await tester.pump();
    expect(selected, MatchFilter.dead);
    expect(records.where(selected.matches).length, 2);
    expect(find.text(records.first.matchId), findsNothing);
    expect(find.text(records[1].matchId), findsOneWidget);
    await tester.tap(find.text('仅撤离成功'));
    await tester.pump();
    expect(records.where(selected.matches).length, 3);
    expect(find.text(records.first.matchId), findsOneWidget);
    expect(find.text(records[1].matchId), findsNothing);
    await tester.tap(find.text('全部对局'));
    await tester.pump();
    for (final record in records) {
      expect(find.text(record.matchId), findsOneWidget);
    }
  });
}
