import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/shared/widgets/salon_carousel.dart';

void main() {
  Widget carousel({bool enabled = true, bool reducedMotion = false}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(
            body: TickerMode(
              enabled: enabled,
              child: const SalonCarousel(
                children: [Text('First'), Text('Second'), Text('Third')],
              ),
            ),
          ),
        ),
      );

  double page(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!.page!;

  testWidgets('rotates after three seconds and wraps around', (tester) async {
    await tester.pumpWidget(carousel());
    for (final expected in [1, 2, 0]) {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(page(tester), expected.toDouble());
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pauses off-tab, in background and for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(carousel(enabled: false));
    await tester.pump(const Duration(seconds: 4));
    expect(page(tester), 0);
    await tester.pumpWidget(carousel());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));
    expect(page(tester), 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(page(tester), 1);
    await tester.pumpWidget(carousel(reducedMotion: true));
    await tester.pump(const Duration(seconds: 4));
    expect(page(tester), 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
