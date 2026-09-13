const categories = {
  'outerwear': 'アウター',
  'tops': 'トップス',
  'shirts': 'シャツ',
  'knitwear': 'ニット',
  'pants': 'パンツ',
  'suits': 'スーツ',
  'shoes': 'シューズ',
  'accessories': 'アクセサリー',
  'other': 'その他',
};
const colors = {
  'black': 'ブラック',
  'gray': 'グレー',
  'white': 'ホワイト',
  'navy': 'ネイビー',
  'blue': 'ブルー',
  'brown': 'ブラウン',
  'beige': 'ベージュ',
  'green': 'グリーン',
  'red': 'レッド',
  'purple': 'パープル',
  'yellow': 'イエロー',
  'orange': 'オレンジ',
  'silver': 'シルバー',
  'gold': 'ゴールド',
  'multi': 'マルチ',
  'other': 'その他',
};
const sorts = {
  'recent': '最近追加',
  'oldest': '古い順',
  'brand': 'ブランド',
  'purchasePrice': '購入価格',
  'listPrice': '定価',
};

/// ブランド表記ゆれ（大小文字・全角・区切り記号・会社名）を吸収した比較キー。
/// 表示用ではなく、filterのグルーピングと一致判定にだけ使う。
String brandKey(String value) {
  final half = StringBuffer();
  for (final rune in value.runes) {
    if (rune >= 0xff01 && rune <= 0xff5e) {
      half.writeCharCode(rune - 0xfee0);
    } else if (rune == 0x3000) {
      half.write(' ');
    } else {
      half.writeCharCode(rune);
    }
  }
  return half
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'^(株式会社|有限会社|合同会社)'), '')
      .replaceAll(RegExp(r'(株式会社|有限会社|合同会社)$'), '')
      .replaceAll(RegExp(r"[.\s'’`・、,，]"), '');
}

class WardrobeItem {
  final Map<String, dynamic> data;
  WardrobeItem(this.data);
  String get id => data['id'] as String;
  String get name => data['name'] as String? ?? '';
  String text(String key) => data[key]?.toString() ?? '';
  List<Map<String, dynamic>> get images => (data['images'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Map<String, dynamic> toInput() => Map.fromEntries(
    data.entries.where(
      (e) =>
          !['id', 'userId', 'images', 'createdAt', 'updatedAt'].contains(e.key),
    ),
  )..['imageIds'] = images.map((e) => e['id']).toList();
}

class BrowseOptions {
  int density;
  String category, brand, color, size, status, sort, query;
  BrowseOptions({
    this.density = 2,
    this.category = '',
    this.brand = '',
    this.color = '',
    this.size = '',
    this.status = 'active',
    this.sort = 'recent',
    this.query = '',
  });
  factory BrowseOptions.fromJson(Map<String, dynamic> j) => BrowseOptions(
    density: [2, 3, 4].contains(j['density']) ? j['density'] : 2,
    category: j['category'] ?? '',
    brand: j['brand'] ?? '',
    color: j['color'] ?? '',
    size: j['size'] ?? '',
    status: j['status'] ?? 'active',
    sort: j['sort'] ?? 'recent',
  );
  Map<String, dynamic> toJson() => {
    'density': density,
    'category': category,
    'brand': brand,
    'color': color,
    'size': size,
    'status': status,
    'sort': sort,
  };
  int get filterCount =>
      [brand, color, size].where((v) => v.isNotEmpty).length +
      (status == 'archived' ? 1 : 0);
  void clear() {
    category = '';
    brand = '';
    color = '';
    size = '';
    status = 'active';
    query = '';
  }

  List<WardrobeItem> apply(List<WardrobeItem> all) {
    final q = query.toLowerCase().trim();
    final selectedBrand = brandKey(brand);
    final result = all.where((i) {
      if (i.text('status') != status) return false;
      if (brand.isNotEmpty && brandKey(i.text('brand')) != selectedBrand) {
        return false;
      }
      for (final pair in [
        [category, 'category'],
        [color, 'normalizedColor'],
        [size, 'size'],
      ]) {
        if (pair[0].isNotEmpty && i.text(pair[1]) != pair[0]) return false;
      }
      return q.isEmpty ||
          [
                'name',
                'brand',
                'category',
                'subCategory',
                'originalColor',
                'normalizedColor',
                'productCode',
                'sku',
                'shopName',
              ]
              .map(i.text)
              .followedBy([categories[i.text('category')] ?? ''])
              .join(' ')
              .toLowerCase()
              .contains(q);
    }).toList();
    result.sort((a, b) {
      if (sort == 'recent' || sort == 'oldest') {
        final r = a.text('createdAt').compareTo(b.text('createdAt'));
        return sort == 'recent' ? -r : r;
      }
      final x = a.data[sort], y = b.data[sort];
      if (x == null) return y == null ? 0 : 1;
      if (y == null) return -1;
      return x is num && y is num
          ? x.compareTo(y)
          : x.toString().compareTo(y.toString());
    });
    return result;
  }
}
