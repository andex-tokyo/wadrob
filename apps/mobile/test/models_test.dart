import 'package:flutter_test/flutter_test.dart';
import 'package:wadrob/core/models.dart';

void main() {
  final items = [
    WardrobeItem({
      'id': '1',
      'name': 'ウールコート',
      'brand': 'AURALEE',
      'category': 'outerwear',
      'normalizedColor': 'beige',
      'sleeve': 'long',
      'size': '3',
      'status': 'active',
      'createdAt': '2026-01-02',
      'images': [],
    }),
    WardrobeItem({
      'id': '2',
      'name': 'スラックス',
      'brand': 'COMOLI',
      'category': 'pants',
      'normalizedColor': 'blue',
      'sleeve': null,
      'size': '2',
      'status': 'archived',
      'createdAt': '2026-01-01',
      'images': [],
    }),
  ];
  test('Japanese local search and status filtering', () {
    final o = BrowseOptions(query: 'コート');
    expect(o.apply(items).single.id, '1');
    o.query = '';
    o.status = 'archived';
    expect(o.apply(items).single.id, '2');
  });
  test('combined filters and density restore', () {
    final o = BrowseOptions.fromJson({
      'density': 3,
      'category': 'outerwear',
      'brand': 'AURALEE',
      'color': 'beige',
    });
    expect(o.density, 3);
    expect(o.apply(items).single.id, '1');
  });

  test('brand spelling variants share one filter key', () {
    expect(brandKey('SNIDEL'), 'snidel');
    expect(brandKey(' snidel '), 'snidel');
    expect(brandKey('ＳＮＩＤＥＬ'), 'snidel');
    expect(brandKey('A.P.C.'), 'apc');
    expect(brandKey('株式会社 ナイキ'), 'ナイキ');
    expect(brandKey('H&M'), 'h&m');
  });

  test('one brand filter matches every spelling variant', () {
    final mixed = [
      WardrobeItem({
        'id': 'a',
        'name': 'ニット',
        'brand': 'SNIDEL',
        'status': 'active',
        'createdAt': '2026-02-01',
        'images': [],
      }),
      WardrobeItem({
        'id': 'b',
        'name': 'ワンピース',
        'brand': 'snidel',
        'status': 'active',
        'createdAt': '2026-02-02',
        'images': [],
      }),
      WardrobeItem({
        'id': 'c',
        'name': 'スカート',
        'brand': 'FRAY I.D',
        'status': 'active',
        'createdAt': '2026-02-03',
        'images': [],
      }),
    ];
    final o = BrowseOptions(brand: 'snidel');
    expect(o.apply(mixed).map((i) => i.id).toSet(), {'a', 'b'});
    // 旧バージョンが保存した表示名でも同じ結果になる。
    final legacy = BrowseOptions(brand: 'ＳＮＩＤＥＬ');
    expect(legacy.apply(mixed).map((i) => i.id).toSet(), {'a', 'b'});
  });

  test('size spelling variants share one filter key', () {
    expect(sizeKey('M'), 'm');
    expect(sizeKey(' m '), 'm');
    expect(sizeKey('Ｍ'), 'm');
    expect(sizeKey('Mサイズ'), 'm');
    expect(sizeKey('メンズM'), 'm');
    expect(sizeKey('38cm'), '38');
    expect(sizeKey('フリーサイズ'), 'フリー');
    expect(sizeKey('LL'), isNot(sizeKey('L')));
  });

  test('sleeve and size filters work together', () {
    final items = [
      WardrobeItem({
        'id': 'a',
        'name': '半袖Tシャツ',
        'category': 'tops',
        'sleeve': 'short',
        'size': 'Mサイズ',
        'status': 'active',
        'createdAt': '2026-03-01',
        'images': [],
      }),
      WardrobeItem({
        'id': 'b',
        'name': '長袖シャツ',
        'category': 'shirts',
        'sleeve': 'long',
        'size': 'M',
        'status': 'active',
        'createdAt': '2026-03-02',
        'images': [],
      }),
    ];
    final bySleeve = BrowseOptions(sleeve: 'short');
    expect(bySleeve.apply(items).single.id, 'a');
    // 「Mサイズ」と「M」は同じサイズとして一致する。
    final bySize = BrowseOptions(size: 'm');
    expect(bySize.apply(items).map((i) => i.id).toSet(), {'a', 'b'});
    expect(BrowseOptions().apply(items).first.id, 'b');
  });

  test('Japanese sleeve label is searchable', () {
    final items = [
      WardrobeItem({
        'id': 'a',
        'name': 'Tシャツ',
        'sleeve': 'short',
        'status': 'active',
        'createdAt': '2026-03-01',
        'images': [],
      }),
    ];
    expect(BrowseOptions(query: '半袖').apply(items).single.id, 'a');
  });
}
