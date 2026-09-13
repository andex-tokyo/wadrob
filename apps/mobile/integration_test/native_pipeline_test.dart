// 端末上でネイティブ経路（ONNX Runtime の背景除去）と画像正規化を通すスモーク。
// R8 が JNI から参照されるクラスを消すと、ここでプロセスごと落ちる。
// 実行: scripts/smoke-device.sh [device-id]（MODE=release でリリースビルド）
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_background_remover/image_background_remover.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wadrob/core/images.dart';

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

  testWidgets('ONNXの背景除去が端末上で完走する', (tester) async {
    final bytes = sampleJpeg();
    await BackgroundRemover.instance.initializeOrt();
    final cutout = await BackgroundRemover.instance.removeBg(
      bytes,
      threshold: .48,
      smoothMask: true,
      enhanceEdges: true,
    );
    expect(cutout.width, greaterThan(0));
    expect(cutout.height, greaterThan(0));
    cutout.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('背景除去と正規化が4:5の画像を返す', (tester) async {
    final bytes = sampleJpeg();
    final result = await ClothingImageProcessor().process(bytes);
    expect(result.display, isNotEmpty);
    expect(result.thumbnail, isNotEmpty);

    final display = img.decodeImage(result.display)!;
    final thumbnail = img.decodeImage(result.thumbnail)!;
    expect(display.width, 960);
    expect(display.height, 1200);
    expect(thumbnail.width, 360);
    expect(thumbnail.height, 450);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
