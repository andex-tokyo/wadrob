import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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

class _EditorScreenState extends State<EditorScreen> {
  final formKey = GlobalKey<FormState>();
  final url = TextEditingController();
  final fields = <String, TextEditingController>{};
  final imageIds = <String>[];
  final imageUrls = <String>[];
  final previews = <Map<String, dynamic>>[];
  String? category, color, message;
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
    for (final image in widget.item?.images ?? <Map<String, dynamic>>[]) {
      imageIds.add(image['id'] as String);
      previews.add(image);
    }
    if (widget.mode == 'photo') {
      WidgetsBinding.instance.addPostFrameCallback((_) => pickPhoto());
    }
  }

  @override
  void dispose() {
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
    try {
      final result = await widget.session.api.post('/api/import/url', {
        'url': value,
      });
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
      imageUrls.addAll((draft['imageUrls'] as List? ?? []).cast<String>());
      previews.addAll(imageUrls.map((u) => {'originalUrl': u}));
      message = result['duplicate'] == true
          ? 'この商品はすでに登録されている可能性があります'
          : (result['warnings'] as List? ?? []).join('\n');
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

  Future<void> pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
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
      imageIds.add(image['id'] as String);
      previews.add(image);
      unawaited(ImageService(widget.session.api).process(image));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
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
        'status': widget.item?.text('status') ?? 'active',
        'imageIds': imageIds,
        'imageUrls': imageUrls,
      };
      for (final key in ['listPrice', 'purchasePrice']) {
        data[key] = int.tryParse(fields[key]!.text.trim());
      }
      await widget.session.save(data, id: widget.item?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget input(String key) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
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
                    child: ItemImage(
                      api: widget.session.api,
                      image: previews[n],
                      thumbnail: false,
                    ),
                  ),
                ),
              ),
            if (previews.length < 8)
              TextButton.icon(
                onPressed: busy ? null : pickPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('写真を追加'),
              ),
            input('name'),
            input('brand'),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'カテゴリ'),
              items: [
                const DropdownMenuItem(value: null, child: Text('未設定')),
                ...categories.entries.map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                ),
              ],
              onChanged: (v) => category = v,
            ),
            const SizedBox(height: 16),
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
}
