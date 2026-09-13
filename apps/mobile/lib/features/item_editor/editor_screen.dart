import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';
import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.session,
    this.mode = 'manual',
    this.item,
  });
  final Session session;
  final String mode;
  final WardrobeItem? item;
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

/// メイン画像を示す小さなバッジ。
class _ImageBadge extends StatelessWidget {
  const _ImageBadge(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xff252522),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
    ),
  );
}

class _EditorScreenState extends State<EditorScreen> {
  final formKey = GlobalKey<FormState>();
  final url = TextEditingController();
  final nameFocus = FocusNode();
  final fields = <String, TextEditingController>{};
  // 画像は表示順そのまま。先頭がメイン画像になる。
  // 登録済み/アップロード済みは 'id'、URL取込の未取得画像は 'url' を持つ。
  // 選べる画像（URL取込の候補＋撮影した写真）と、実際に登録する画像（順序つき、先頭がメイン）。
  List<Map<String, dynamic>> imageCandidates = [];
  var previews = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> candidates = [];
  String? category, color, sleeve, message;
  bool busy = false, imported = false;
  static const labels = {
    'name': '商品名 *',
    'brand': 'ブランド',
    'originalColor': 'カラー（商品表記）',
    'size': 'サイズ',
    'listPrice': '定価',
    'purchasePrice': '購入価格',
    'currency': '通貨',
    'purchasedAt': '購入日',
    'productCode': '商品コード',
    'sku': 'SKU',
    'shopName': '購入店',
    'subCategory': 'サブカテゴリ',
    'sourceUrl': '商品ページURL',
    'description': 'メモ',
  };

  @override
  void initState() {
    super.initState();
    for (final key in labels.keys) {
      fields[key] = TextEditingController(
        text: widget.item?.text(key) ?? (key == 'currency' ? 'JPY' : ''),
      );
    }
    category = widget.item?.data['category'] as String?;
    color = widget.item?.data['normalizedColor'] as String?;
    sleeve = widget.item?.data['sleeve'] as String?;
    for (final image in widget.item?.images ?? <Map<String, dynamic>>[]) {
      imageCandidates.add(image);
      previews.add(image);
    }
    if (widget.mode == 'photo') {
      // 2回目以降は前回使った方（カメラ/ライブラリ）をすぐ開く。
      WidgetsBinding.instance.addPostFrameCallback((_) => pickPhoto());
    } else if (widget.mode == 'manual') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) nameFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    nameFocus.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    url.dispose();
    super.dispose();
  }

  Future<void> importUrl() async {
    final value = url.text.trim(), uri = Uri.tryParse(url.text.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      setState(() => message = '商品ページのURLを入力してください');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    fields['sourceUrl']!.text = value;
    await loadFrom(value);
  }

  /// 商品名とブランドから候補を探す。URLは推測させず、検索結果のURLだけを使う。
  Future<void> searchProducts() async {
    final name = fields['name']!.text.trim(),
        brand = fields['brand']!.text.trim();
    if (name.isEmpty && brand.isEmpty) {
      setState(() => message = '商品名かブランドを入力してください');
      return;
    }
    setState(() {
      busy = true;
      message = null;
      candidates = [];
    });
    try {
      final result = await widget.session.api.post('/api/import/search', {
        'name': name.isEmpty ? brand : name,
        if (brand.isNotEmpty) 'brand': brand,
      });
      if (!mounted) return;
      setState(() {
        candidates = (result['candidates'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (candidates.isEmpty) {
          message = '候補が見つかりませんでした。URLから登録してください';
        }
      });
    } catch (e) {
      if (mounted) setState(() => message = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// 候補の商品ページを取り込む。
  Future<void> importCandidate(Map<String, dynamic> candidate) async {
    final value = candidate['url']?.toString() ?? '';
    if (value.isEmpty) return;
    setState(() {
      busy = true;
      message = null;
    });
    fields['sourceUrl']!.text = value;
    await loadFrom(value);
  }

  /// 取り込んだ画像から、実際に登録する画像を選ぶ。
  /// 既定は1枚。複数選ぶと選んだ順に並び、先頭がメインになる。
  Future<void> pickImages() async {
    if (imageCandidates.isEmpty) return;
    final chosen = List<Map<String, dynamic>>.from(previews);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) {
          void toggle(Map<String, dynamic> candidate) => update(() {
            if (chosen.any((c) => identical(c, candidate))) {
              chosen.removeWhere((c) => identical(c, candidate));
            } else if (chosen.length < 8) {
              chosen.add(candidate);
            }
          });

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('使う画像を選ぶ', style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      Text(
                        '${chosen.length}枚',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'タップで選択。番号の小さい画像が一覧のメインになります。',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        for (final (index, candidate)
                            in imageCandidates.indexed)
                          GestureDetector(
                            key: ValueKey('candidate-$index'),
                            onTap: () => toggle(candidate),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ItemImage(
                                    api: widget.session.api,
                                    image: candidate,
                                    thumbnail: false,
                                  ),
                                ),
                                if (chosen.any((c) => identical(c, candidate)))
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: _ImageBadge(
                                      '${chosen.indexWhere((c) => identical(c, candidate)) + 1}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('この画像で登録'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    setState(() => previews = chosen);
  }

  /// 名前からカテゴリ・検索用カラーを推定し、未選択のときだけ埋める。
  /// カテゴリは一覧の軸なので、選ばせずに埋まるに越したことはない。
  Future<void> classify() async {
    final name = fields['name']!.text.trim();
    if (name.isEmpty || busy) return;
    try {
      final result = await widget.session.api.post('/api/classify', {
        'name': name,
        if (fields['brand']!.text.trim().isNotEmpty)
          'brand': fields['brand']!.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        final suggestedCategory = result['category']?.toString();
        if (category == null && categories.containsKey(suggestedCategory)) {
          category = suggestedCategory;
        }
        final suggestedColor = result['normalizedColor']?.toString();
        if (color == null && colors.containsKey(suggestedColor)) {
          color = suggestedColor;
        }
        final suggestedSleeve = result['sleeve']?.toString();
        if (sleeve == null && sleeves.containsKey(suggestedSleeve)) {
          sleeve = suggestedSleeve;
        }
      });
    } catch (_) {
      // 分類できなくても登録はできる。
    }
  }

  Future<void> loadFrom(String value) async {
    try {
      final result = await widget.session.api.post('/api/import/url', {
        'url': value,
      });
      applyResult(result);
      if (mounted) {
        setState(() => candidates = []);
        // 画像が複数あるときは、その場でどれを使うか選ばせる。
        if (imageCandidates.length > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) pickImages();
          });
        }
      }
    } catch (_) {
      message = '商品情報を取得できませんでした。入力して登録できます';
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          imported = true;
        });
      }
    }
  }

  /// 解析結果をフォームへ反映する（URL取込と候補取込で共通）。
  void applyResult(Map<String, dynamic> result) {
    final draft = Map<String, dynamic>.from(result['draft'] as Map);
    for (final key in fields.keys) {
      final value = draft[key]?.toString();
      if (value == null || value.isEmpty) continue;
      final field = fields[key]!;
      // 通貨は既定値JPYのときだけ解析結果で置き換える。
      if (key == 'currency' ? field.text == 'JPY' : field.text.isEmpty) {
        field.text = value;
      }
    }
    // カテゴリと検索用カラーは解析結果をドロップダウンへ反映する。
    final importedCategory = draft['category']?.toString();
    if (category == null && categories.containsKey(importedCategory)) {
      category = importedCategory;
    }
    final importedColor = draft['normalizedColor']?.toString();
    if (color == null && colors.containsKey(importedColor)) {
      color = importedColor;
    }
    final importedSleeve = draft['sleeve']?.toString();
    if (sleeve == null && sleeves.containsKey(importedSleeve)) {
      sleeve = importedSleeve;
    }
    for (final url in (draft['imageUrls'] as List? ?? []).cast<String>()) {
      imageCandidates.add({'url': url, 'originalUrl': url});
    }
    // 既定は1枚（先頭）。複数ある場合はモーダルで選び直せる。
    if (previews.isEmpty && imageCandidates.isNotEmpty) {
      previews.add(imageCandidates.first);
    }
    message = result['duplicate'] == true
        ? 'この商品はすでに登録されている可能性があります'
        : (result['warnings'] as List? ?? []).join('\n');
  }

  /// [choose] が true のときは毎回カメラ/ライブラリを選ばせる。
  Future<void> pickPhoto({bool choose = false}) async {
    ImageSource? source;
    if (!choose) {
      final remembered = widget.session.prefs.getString('photoSource');
      source = remembered == 'camera'
          ? ImageSource.camera
          : remembered == 'gallery'
          ? ImageSource.gallery
          : null;
    }
    source ??= await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('カメラで撮影'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('写真を選ぶ'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await widget.session.prefs.setString(
      'photoSource',
      source == ImageSource.camera ? 'camera' : 'gallery',
    );
    setState(() => busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 4000,
        maxHeight: 4000,
        imageQuality: 92,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 10000000) throw Exception('10MB以下の画像を選択してください');
      final image = await ImageService(widget.session.api).upload(bytes);
      previews.add(image);
      imageCandidates.add(image);
      unawaited(ImageService(widget.session.api).process(image));
      // 撮った直後に名前を入力できるようキーボードを出す。
      if (mounted) nameFocus.requestFocus();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    // カテゴリ未選択なら保存前に一度だけ推定する。
    if (category == null && fields['name']!.text.trim().isNotEmpty) {
      await classify();
    }
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final data = <String, dynamic>{
        for (final e in fields.entries)
          e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
        'name': fields['name']!.text.trim(),
        'currency': fields['currency']!.text.trim().toUpperCase(),
        'category': category,
        'normalizedColor': color,
        'sleeve': sleeve,
        'status': widget.item?.text('status') ?? 'active',
        'images': [
          for (final preview in previews)
            if (preview['id'] != null)
              {'id': preview['id']}
            else if (preview['url'] != null)
              {'url': preview['url']},
        ],
      };
      for (final key in ['listPrice', 'purchasePrice']) {
        data[key] = int.tryParse(fields[key]!.text.trim());
      }
      await widget.session.save(data, id: widget.item?.id);
      if (mounted) {
        // 写真モードは「続けて撮る」ために呼び出し元へ知らせる。
        Navigator.pop(context, widget.mode == 'photo' ? 'photo' : true);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget input(String key, {FocusNode? focus, VoidCallback? onSubmitted}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: fields[key],
          focusNode: focus,
          onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
          maxLines: key == 'description' ? 3 : 1,
          keyboardType: ['listPrice', 'purchasePrice'].contains(key)
              ? TextInputType.number
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: labels[key],
            helperText: key == 'purchasePrice'
                ? '実際に支払った金額'
                : key == 'listPrice'
                ? 'URL取得価格は定価候補として入ります'
                : null,
          ),
          validator: (v) {
            if (key == 'name' && (v == null || v.trim().isEmpty)) {
              return '商品名を入力してください';
            }
            if (['listPrice', 'purchasePrice'].contains(key) &&
                v!.isNotEmpty &&
                (int.tryParse(v) == null || int.parse(v) < 0)) {
              return '0以上の整数で入力してください';
            }
            if (key == 'currency' && !RegExp(r'^[A-Z]{3}$').hasMatch(v ?? '')) {
              return 'JPYなど3文字で入力してください';
            }
            return null;
          },
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.item != null
            ? '服を編集'
            : widget.mode == 'url'
            ? 'URLから追加'
            : '服を追加',
        style: const TextStyle(fontSize: 17),
      ),
      actions: [
        if (widget.mode != 'url' || imported)
          TextButton(onPressed: busy ? null : save, child: const Text('保存')),
      ],
    ),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          if (widget.mode == 'url' && !imported) ...[
            const Text(
              '商品ページを、クローゼットへ。',
              style: TextStyle(fontSize: 22, height: 1.6),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://…',
                suffixIcon: IconButton(
                  tooltip: '貼り付け',
                  onPressed: () async {
                    final d = await Clipboard.getData('text/plain');
                    url.text = d?.text ?? '';
                  },
                  icon: const Icon(Icons.content_paste),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : importUrl,
              child: Text(busy ? '商品情報を取得中…' : '商品情報を読み込む'),
            ),
            TextButton(
              onPressed: () => setState(() {
                imported = true;
                fields['sourceUrl']!.text = url.text.trim();
              }),
              child: const Text('手動で入力する'),
            ),
          ],
          if (message?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                message!,
                style: const TextStyle(color: Colors.brown),
              ),
            ),
          if (widget.mode != 'url' || imported) ...[
            if (previews.isNotEmpty)
              SizedBox(
                height: 270,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: previews.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, n) => SizedBox(
                    width: 210,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: n == 0
                                ? null
                                : () => setState(() {
                                    final picked = previews.removeAt(n);
                                    previews.insert(0, picked);
                                  }),
                            child: ItemImage(
                              api: widget.session.api,
                              image: previews[n],
                              thumbnail: false,
                            ),
                          ),
                        ),
                        if (n == 0)
                          const Positioned(
                            left: 8,
                            top: 8,
                            child: _ImageBadge('メイン'),
                          )
                        else
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: TextButton(
                              onPressed: () => setState(() {
                                final picked = previews.removeAt(n);
                                previews.insert(0, picked);
                              }),
                              child: const Text(
                                'メインにする',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: 'この画像を使わない',
                            onPressed: () =>
                                setState(() => previews.removeAt(n)),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (previews.length < 8)
              TextButton.icon(
                onPressed: busy ? null : () => pickPhoto(choose: true),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('写真を追加'),
              ),
            if (imageCandidates.length > 1)
              TextButton.icon(
                onPressed: busy ? null : pickImages,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text('画像を選ぶ（${imageCandidates.length}枚から）'),
              ),
            if (previews.length > 1)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'タップするとその画像をメイン（一覧の1枚目）にします。×で使わない画像を外せます。',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            input('name', focus: nameFocus, onSubmitted: classify),
            input('brand'),
            if (widget.mode != 'url') ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: busy ? null : searchProducts,
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('AIで商品を探す'),
                ),
              ),
              const Text(
                '商品名やブランドから候補を探し、選ぶと写真と情報を取り込みます。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              for (final candidate in candidates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    candidate['title']?.toString() ??
                        candidate['url'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    candidate['shop']?.toString() ??
                        Uri.tryParse(candidate['url'].toString())?.host ??
                        '',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.add, size: 18),
                  onTap: busy ? null : () => importCandidate(candidate),
                ),
              if (candidates.isNotEmpty) const SizedBox(height: 8),
            ],
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'カテゴリ',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final entry in categories.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: category == entry.key,
                        onSelected: (_) => setState(
                          () => category = category == entry.key
                              ? null
                              : entry.key,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '袖丈',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final entry in sleeves.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: sleeve == entry.key,
                        onSelected: (_) => setState(
                          () => sleeve = sleeve == entry.key ? null : entry.key,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _details(),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? '保存中…' : 'クローゼットに保存'),
            ),
          ],
        ],
      ),
    ),
  );

  /// 詳細項目は既定で畳んでおき、写真と名前だけで保存できるようにする。
  Widget _details() => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text('詳細を入力', style: TextStyle(fontSize: 13)),
      subtitle: const Text(
        'カテゴリ・カラー・価格など（任意）',
        style: TextStyle(fontSize: 11, color: Colors.grey),
      ),
      children: [
        input('originalColor'),
        DropdownButtonFormField<String>(
          initialValue: color,
          decoration: const InputDecoration(labelText: '検索用カラー'),
          items: [
            const DropdownMenuItem(value: null, child: Text('未設定')),
            ...colors.entries.map(
              (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
            ),
          ],
          onChanged: (v) => color = v,
        ),
        const SizedBox(height: 16),
        ...labels.keys
            .where((k) => !['name', 'brand', 'originalColor'].contains(k))
            .map(input),
      ],
    ),
  );
}
