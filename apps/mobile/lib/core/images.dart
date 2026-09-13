import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:dio/dio.dart';
import 'api.dart';

abstract class ImageProcessor {
  Future<ProcessedImage> process(Uint8List bytes);
}

class ProcessedImage {
  final Uint8List display, thumbnail;
  ProcessedImage(this.display, this.thumbnail);
}

class NormalizationProcessor implements ImageProcessor {
  @override
  Future<ProcessedImage> process(Uint8List bytes) =>
      compute(normalizeImage, bytes);
}

ProcessedImage normalizeImage(Uint8List bytes) {
  if (bytes.length > 10000000) throw Exception('画像は10MB以下にしてください');
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 24000000) {
    throw Exception('画像のサイズが大きすぎます');
  }
  var source = img.bakeOrientation(decoder!.decode(bytes)!);
  if (source.width > 1600 || source.height > 1600) {
    source = img.copyResize(
      source,
      width: source.width >= source.height ? 1600 : null,
      height: source.height > source.width ? 1600 : null,
    );
  }
  // Conservative boundary-connected removal: only nearly uniform light backgrounds.
  final corners = [
    source.getPixel(0, 0),
    source.getPixel(source.width - 1, 0),
    source.getPixel(0, source.height - 1),
    source.getPixel(source.width - 1, source.height - 1),
  ];
  final r = corners.map((p) => p.r).reduce((a, b) => a + b) / 4,
      g = corners.map((p) => p.g).reduce((a, b) => a + b) / 4,
      b = corners.map((p) => p.b).reduce((a, b) => a + b) / 4;
  final uniform =
      corners.every(
        (p) => (p.r - r).abs() + (p.g - g).abs() + (p.b - b).abs() < 35,
      ) &&
      r > 210 &&
      g > 210 &&
      b > 210;
  source = source.convert(numChannels: 4);
  if (uniform) {
    final w = source.width, h = source.height, seen = Uint8List(w * h);
    final queue = <int>[];
    void add(int n) {
      if (seen[n] != 0) return;
      seen[n] = 1;
      final p = source.getPixel(n % w, n ~/ w);
      if ((p.r - r).abs() + (p.g - g).abs() + (p.b - b).abs() < 48) {
        queue.add(n);
      }
    }

    for (var x = 0; x < w; x++) {
      add(x);
      add((h - 1) * w + x);
    }
    for (var y = 0; y < h; y++) {
      add(y * w);
      add(y * w + w - 1);
    }
    for (var at = 0; at < queue.length; at++) {
      final n = queue[at], x = n % w, y = n ~/ w;
      source.getPixel(x, y).a = 0;
      if (x > 0) add(n - 1);
      if (x < w - 1) add(n + 1);
      if (y > 0) add(n - w);
      if (y < h - 1) add(n + w);
    }
  }
  var left = source.width, top = source.height, right = 0, bottom = 0;
  for (final p in source) {
    if (p.a > 16) {
      if (p.x < left) left = p.x;
      if (p.x > right) right = p.x;
      if (p.y < top) top = p.y;
      if (p.y > bottom) bottom = p.y;
    }
  }
  if (right > left && bottom > top) {
    source = img.copyCrop(
      source,
      x: left,
      y: top,
      width: right - left + 1,
      height: bottom - top + 1,
    );
  }
  img.Image canvas(int width) {
    final height = (width * 1.25).round();
    final result = img.Image(width: width, height: height);
    img.fill(result, color: img.ColorRgb8(246, 245, 242));
    final scale = (width * .88 / source.width) < (height * .88 / source.height)
        ? width * .88 / source.width
        : height * .88 / source.height;
    final object = img.copyResize(
      source,
      width: (source.width * scale).round().clamp(1, width),
      height: (source.height * scale).round().clamp(1, height),
      interpolation: img.Interpolation.average,
    );
    img.compositeImage(
      result,
      object,
      dstX: (width - object.width) ~/ 2,
      dstY: (height - object.height) ~/ 2,
    );
    return result;
  }

  return ProcessedImage(
    Uint8List.fromList(img.encodeJpg(canvas(960), quality: 88)),
    Uint8List.fromList(img.encodeJpg(canvas(360), quality: 82)),
  );
}

class ImageService {
  final Api api;
  final ImageProcessor processor;
  ImageService(this.api, {ImageProcessor? processor})
    : processor = processor ?? NormalizationProcessor();
  Future<Map<String, dynamic>> upload(Uint8List bytes) async =>
      Map<String, dynamic>.from(
        (await api.dio.post(
              '/api/images',
              data: bytes,
              options: Options(
                headers: {
                  ...api.headers,
                  'Content-Type': 'application/octet-stream',
                },
              ),
            )).data['image']
            as Map,
      );
  Future<void> process(Map<String, dynamic> image) async {
    final id = image['id'];
    try {
      await api.post(
        '/api/images/$id/process',
        FormData.fromMap({'status': 'processing'}),
      );
      final r = await api.dio.get<List<int>>(
        api.url(image['originalUrl'] as String),
        options: Options(
          headers: api.headers,
          responseType: ResponseType.bytes,
        ),
      );
      final result = await processor.process(Uint8List.fromList(r.data!));
      await api.post(
        '/api/images/$id/process',
        FormData.fromMap({
          'display': MultipartFile.fromBytes(
            result.display,
            filename: 'display.jpg',
          ),
          'thumbnail': MultipartFile.fromBytes(
            result.thumbnail,
            filename: 'thumbnail.jpg',
          ),
        }),
      );
    } catch (_) {
      try {
        await api.post(
          '/api/images/$id/process',
          FormData.fromMap({'status': 'failed'}),
        );
      } catch (_) {}
    }
  }
}
