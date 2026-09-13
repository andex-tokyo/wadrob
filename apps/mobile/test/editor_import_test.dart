import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wadrob/core/api.dart';
import 'package:wadrob/core/cache.dart';
import 'package:wadrob/core/session.dart';
import 'package:wadrob/features/item_editor/editor_screen.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.responses);
  final Map<String, Map<String, dynamic>> responses;
  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options.path);
    final data = options.data;
    if (data is Map) bodies.add(Map<String, dynamic>.from(data));
    return ResponseBody.fromString(
      jsonEncode(
        responses[options.path] ??
            {
              'error': {'message': 'no stub for ${options.path}'},
            },
      ),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> draftResponse(Map<String, dynamic> draft) => {
  'sourceUrl': 'https://shop.example/item',
  'fields': <String, dynamic>{},
  'warnings': <String>[],
  'duplicate': false,
  'draft': draft,
};

final _cache = WardrobeCache(NativeDatabase.memory());

Future<Session> sessionWith(HttpClientAdapter adapter) async => Session(
  Api(
    client: Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter,
  ),
  _cache,
  await SharedPreferences.getInstance(),
);

void main() {
  testWidgets('URL取込の解析結果をエディタへ反映する', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final adapter = _StubAdapter({
      '/api/import/url': draftResponse({
        'name': 'コットンニット',
        'brand': 'AURALEE',
        'category': 'knitwear',
        'normalizedColor': 'gray',
        'currency': 'USD',
        'listPrice': 15400,
        'purchasePrice': null,
        'purchasedAt': null,
        'size': null,
        'sourceUrl': 'https://shop.example/item',
      }),
    });
    final session = Session(
      Api(
        client: Dio(BaseOptions(baseUrl: 'http://localhost'))
          ..httpClientAdapter = adapter,
      ),
      _cache,
      await SharedPreferences.getInstance(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(session: session, mode: 'url'),
      ),
    );
    await tester.enterText(
      find.byType(TextField).first,
      'https://shop.example/item',
    );
    await tester.tap(find.text('商品情報を読み込む'));
    await tester.pumpAndSettle();

    expect(adapter.calls, contains('/api/import/url'));
    expect(find.text('コットンニット'), findsOneWidget);
    // 詳細は既定で畳まれているので開いてから確認する。
    final knit = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'ニット'),
    );
    expect(knit.selected, isTrue);
    await tester.tap(find.text('詳細を入力'));
    await tester.pumpAndSettle();
    expect(find.text('グレー'), findsOneWidget);
    expect(find.text('15400'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
  });

  testWidgets('名前とブランドから候補を探して取り込める', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final adapter = _StubAdapter({
      '/api/import/search': {
        'query': 'AURALEE ウールコート',
        'candidates': [
          {
            'url': 'https://zozo.jp/shop/auralee/goods/1/',
            'title': 'ウールコート',
            'shop': 'ZOZOTOWN Yahoo!店',
          },
        ],
      },
      '/api/import/url': draftResponse({
        'name': 'ウールコート',
        'brand': 'AURALEE',
        'category': 'outerwear',
        'normalizedColor': 'beige',
        'listPrice': 88000,
        'sourceUrl': 'https://zozo.jp/shop/auralee/goods/1/',
      }),
    });
    await tester.pumpWidget(
      MaterialApp(home: EditorScreen(session: await sessionWith(adapter))),
    );

    final inputs = find.byType(TextFormField);
    await tester.enterText(inputs.at(0), 'ウールコート');
    await tester.enterText(inputs.at(1), 'AURALEE');
    await tester.tap(find.text('AIで商品を探す'));
    await tester.pumpAndSettle();

    expect(find.text('ウールコート'), findsWidgets);
    expect(find.text('ZOZOTOWN Yahoo!店'), findsOneWidget);

    await tester.tap(find.text('ウールコート').last);
    await tester.pumpAndSettle();

    expect(adapter.calls, contains('/api/import/search'));
    expect(adapter.calls, contains('/api/import/url'));
    final outer = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'アウター'),
    );
    expect(outer.selected, isTrue);
    await tester.tap(find.text('詳細を入力'));
    await tester.pumpAndSettle();
    expect(find.text('ベージュ'), findsOneWidget);
    expect(find.text('88000'), findsOneWidget);
  });

  testWidgets('URL取込の画像をモーダルで選べる（既定1枚）', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    const a = 'https://shop.example/a.jpg';
    const b = 'https://shop.example/b.jpg';
    const c = 'https://shop.example/c.jpg';
    final adapter = _StubAdapter({
      '/api/import/url': draftResponse({
        'name': 'コットンニット',
        'imageUrls': [a, b, c],
        'sourceUrl': 'https://shop.example/item',
      }),
      '/api/items': {
        'item': {'id': 'x', 'name': 'コットンニット', 'images': []},
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(session: await sessionWith(adapter), mode: 'url'),
      ),
    );
    await tester.enterText(
      find.byType(TextField).first,
      'https://shop.example/item',
    );
    await tester.tap(find.text('商品情報を読み込む'));
    await tester.pumpAndSettle();

    // 取込後は画像選択のモーダルが開き、既定で1枚だけ選ばれている。
    expect(find.text('使う画像を選ぶ'), findsOneWidget);
    expect(find.text('1枚'), findsOneWidget);

    // 2枚目（b）を追加で選ぶ。
    await tester.tap(find.byKey(const ValueKey('candidate-1')));
    await tester.pumpAndSettle();
    expect(find.text('2枚'), findsOneWidget);
    await tester.tap(find.text('この画像で登録'));
    await tester.pumpAndSettle();

    // 保存時の順序が [a, b] になっている。
    await tester.tap(find.text('保存').first);
    await tester.pumpAndSettle();
    expect(adapter.bodies.last['images'], [
      {'url': a},
      {'url': b},
    ]);
  });
}
