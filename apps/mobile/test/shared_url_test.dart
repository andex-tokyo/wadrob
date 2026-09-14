import 'package:flutter_test/flutter_test.dart';
import 'package:wadrob/core/shared_url.dart';

void main() {
  test('共有テキストから最初の商品URLだけを取り出す', () {
    expect(
      SharedUrlReceiver.extractUrl(
        '商品名はこちら\nhttps://shop.example/items/123?color=black\n#fashion',
      ),
      'https://shop.example/items/123?color=black',
    );
    expect(
      SharedUrlReceiver.extractUrl('https://shop.example/items/123）。'),
      'https://shop.example/items/123',
    );
  });

  test('URLを含まない共有テキストは無視する', () {
    expect(SharedUrlReceiver.extractUrl('商品名だけ'), isNull);
    expect(SharedUrlReceiver.extractUrl(null), isNull);
  });

  test('共有URLは一度だけ消費する', () {
    final receiver = SharedUrlReceiver();
    receiver.receiveText('https://shop.example/item');
    expect(receiver.pendingUrl, 'https://shop.example/item');
    expect(receiver.take(), 'https://shop.example/item');
    expect(receiver.take(), isNull);
  });
}
