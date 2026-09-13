import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../item_editor/editor_screen.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.session, required this.id});
  final Session session;
  final String id;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool original = false, busy = false;
  Future<void> action(String value, WardrobeItem item) async {
    if (value == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditorScreen(session: widget.session, item: item),
        ),
      );
      return;
    }
    if (value == 'process') {
      setState(() => busy = true);
      for (final image in item.images) {
        await ImageService(widget.session.api).process(image);
      }
      await widget.session.sync();
      if (mounted) setState(() => busy = false);
      return;
    }
    final archive = value == 'archive';
    if (!await confirm(
      context,
      archive ? 'この服を手放しますか？' : '完全に削除しますか？',
      archive ? '「手放した服」からいつでも確認できます。' : '写真と登録内容を削除します。この操作は元に戻せません。',
    )) {
      return;
    }
    try {
      setState(() => busy = true);
      archive
          ? await widget.session.archive(item.id)
          : await widget.session.deleteItem(item.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.session,
    builder: (context, _) {
      final item = widget.session.items
          .where((i) => i.id == widget.id)
          .firstOrNull;
      if (item == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('服が見つかりません')),
        );
      }
      final details = {
        'category': 'カテゴリ',
        'originalColor': 'カラー',
        'sleeve': '袖丈',
        'size': 'サイズ',
        'listPrice': '定価',
        'purchasePrice': '購入価格',
        'purchasedAt': '購入日',
        'productCode': '商品コード',
        'sku': 'SKU',
        'shopName': '購入店',
        'description': 'メモ',
      };
      return Scaffold(
        appBar: AppBar(
          actions: [
            TextButton(
              onPressed: busy ? null : () => action('edit', item),
              child: const Text('編集'),
            ),
            PopupMenuButton<String>(
              enabled: !busy,
              onSelected: (v) => action(v, item),
              itemBuilder: (_) => [
                if (item.text('status') == 'active')
                  const PopupMenuItem(value: 'archive', child: Text('手放す')),
                const PopupMenuItem(value: 'process', child: Text('画像を再処理')),
                const PopupMenuItem(value: 'delete', child: Text('完全に削除')),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            LayoutBuilder(
              builder: (_, b) => SizedBox(
                height: b.maxWidth * 1.25,
                child: PageView(
                  children: item.images.isEmpty
                      ? [ItemImage(api: widget.session.api)]
                      : item.images
                            .asMap()
                            .entries
                            .map(
                              (e) => e.key == 0
                                  ? Hero(
                                      tag: item.id,
                                      child: ItemImage(
                                        api: widget.session.api,
                                        image: e.value,
                                        original: original,
                                        thumbnail: false,
                                      ),
                                    )
                                  : ItemImage(
                                      api: widget.session.api,
                                      image: e.value,
                                      original: original,
                                      thumbnail: false,
                                    ),
                            )
                            .toList(),
                ),
              ),
            ),
            if (item.images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${item.images.length}枚',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => original = !original),
                      child: Text(original ? '整えた画像を見る' : '元画像を見る'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text('brand').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 25, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  ...details.entries
                      .where((e) => item.text(e.key).isNotEmpty)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text(
                                  e.value,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.key == 'category'
                                      ? categories[item.text(e.key)] ??
                                            item.text(e.key)
                                      : e.key == 'sleeve'
                                      ? sleeves[item.text(e.key)] ??
                                            item.text(e.key)
                                      : [
                                          'listPrice',
                                          'purchasePrice',
                                        ].contains(e.key)
                                      ? '${item.text(e.key)} ${item.text('currency')}'
                                      : item.text(e.key),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (item.text('sourceUrl').isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final u = Uri.tryParse(item.text('sourceUrl'));
                        if (u != null) {
                          await launchUrl(
                            u,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('商品ページを見る'),
                    ),
                  if (item.text('status') == 'archived')
                    TextButton(
                      onPressed: () async {
                        await widget.session.save(
                          item.toInput()..['status'] = 'active',
                          id: item.id,
                        );
                      },
                      child: const Text('クローゼットに戻す'),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
