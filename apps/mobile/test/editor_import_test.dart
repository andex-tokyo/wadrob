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
  _StubAdapter(this.payload);
  final Map<String, dynamic> payload;
  int calls = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  testWidgets('URL取込の解析結果をエディタへ反映する', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final adapter = _StubAdapter({
      'sourceUrl': 'https://shop.example/item',
      'fields': <String, dynamic>{},
      'warnings': <String>[],
      'duplicate': false,
      'draft': {
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
      },
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    final session = Session(
      Api(client: dio),
      WardrobeCache(NativeDatabase.memory()),
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

    expect(adapter.calls, 1);
    expect(find.text('コットンニット'), findsOneWidget);
    expect(find.text('ニット'), findsOneWidget);
    expect(find.text('グレー'), findsOneWidget);
    expect(find.text('15400'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
  });
}
