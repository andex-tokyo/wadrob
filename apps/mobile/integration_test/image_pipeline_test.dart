// 端末上で画像の正規化とローカルcache（ネイティブのsqlite3）が動くことを確認するスモーク。
// 実行: scripts/smoke-device.sh [device-id]（MODE=profile でリリースに近い設定）
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:wadrob/core/cache.dart';
import 'package:wadrob/core/images.dart';
import 'package:wadrob/core/models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 服に見立てた矩形を、白背景に置いた合成画像。
  Uint8List sampleJpeg() {
    final source = img.Image(width: 600, height: 800);
    img.fill(source, color: img.ColorRgb8(250, 250, 250));
    img.fillRect(
      source,
      x1: 150,
      y1: 120,
      x2: 450,
      y2: 720,
      color: img.ColorRgb8(40, 45, 70),
    );
    return Uint8List.fromList(img.encodeJpg(source, quality: 90));
  }

  testWidgets('画像の正規化が4:5の表示用画像とサムネイルを返す', (tester) async {
    final result = await NormalizationProcessor().process(sampleJpeg());
    expect(result.display, isNotEmpty);
    expect(result.thumbnail, isNotEmpty);

    final display = img.decodeImage(result.display)!;
    final thumbnail = img.decodeImage(result.thumbnail)!;
    expect(display.width, 960);
    expect(display.height, 1200);
    expect(thumbnail.width, 360);
    expect(thumbnail.height, 450);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('端末のsqlite3でローカルcacheを読み書きできる', (tester) async {
    final cache = WardrobeCache(NativeDatabase.memory());
    await cache.replace('user-1', [
      WardrobeItem({'id': 'a', 'name': 'ニット', 'images': []}),
    ]);
    final items = await cache.read('user-1');
    expect(items.single.name, 'ニット');
    await cache.clear();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
