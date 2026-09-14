import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wadrob/core/api.dart';
import 'package:wadrob/core/cache.dart';
import 'package:wadrob/core/session.dart';
import 'package:wadrob/features/wardrobe/wardrobe_screen.dart';

void main() {
  testWidgets('トップスとシャツでは全袖丈を直接切り替えられる', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final cache = WardrobeCache(NativeDatabase.memory());
    addTearDown(cache.close);
    final session = Session(
      Api(client: Dio(BaseOptions(baseUrl: 'http://localhost'))),
      cache,
      await SharedPreferences.getInstance(),
    )..loaded = true;
    session.browse.category = 'tops';

    await tester.pumpWidget(
      MaterialApp(home: WardrobeScreen(session: session)),
    );

    final shortcuts = find.byKey(const ValueKey('sleeve-shortcuts'));
    expect(shortcuts, findsOneWidget);
    for (final label in ['すべて', '半袖', '長袖', 'ノースリーブ', '七分袖']) {
      expect(
        find.descendant(of: shortcuts, matching: find.text(label)),
        findsOneWidget,
      );
    }

    await tester.tap(
      find.descendant(of: shortcuts, matching: find.text('ノースリーブ')),
    );
    await tester.pump();
    expect(session.browse.sleeve, 'sleeveless');

    await tester.tap(find.widgetWithText(TextButton, 'シャツ'));
    await tester.pumpAndSettle();
    expect(session.browse.sleeve, 'sleeveless');
    expect(shortcuts, findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'パンツ'));
    await tester.pumpAndSettle();
    expect(session.browse.sleeve, isEmpty);
    expect(shortcuts, findsNothing);

    final swipeArea = find.byKey(const ValueKey('category-swipe-area'));
    final pantsPage = find.byKey(const ValueKey('category-page-pants'));
    final start = tester.getTopLeft(pantsPage).dx;
    final gesture = await tester.startGesture(tester.getCenter(swipeArea));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-240, 0));
    await tester.pump();
    expect(tester.getTopLeft(pantsPage).dx, lessThan(start - 200));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.fling(swipeArea, const Offset(-800, 0), 1200);
    await tester.pumpAndSettle();
    expect(session.browse.category, 'suits');

    await tester.fling(swipeArea, const Offset(800, 0), 1200);
    await tester.pumpAndSettle();
    expect(session.browse.category, 'pants');

    expect(find.text('クローゼット'), findsNothing);
    expect(find.byKey(const ValueKey('add-item-button')), findsOneWidget);
    final addButton = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('add-item-button')),
    );
    expect(addButton.backgroundColor, Colors.black);
    expect(addButton.foregroundColor, Colors.white);
  });
}
