import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../item_detail/detail_screen.dart';
import '../item_editor/editor_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key, required this.session});
  final Session session;
  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final scroll = ScrollController();
  final search = TextEditingController();
  bool searching = false;
  Session get session => widget.session;
  @override
  void dispose() {
    scroll.dispose();
    search.dispose();
    super.dispose();
  }

  void changed() {
    session.persistBrowse();
    setState(() {});
  }

  Future<void> addItem({String? mode}) async {
    final selected =
        mode ??
        await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (c) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in {
                  'url': 'URLから追加',
                  'photo': '写真から追加',
                  'manual': '手動で追加',
                }.entries)
                  ListTile(
                    leading: Icon(
                      e.key == 'url'
                          ? Icons.link
                          : e.key == 'photo'
                          ? Icons.photo_camera_outlined
                          : Icons.edit_outlined,
                    ),
                    title: Text(e.value),
                    onTap: () => Navigator.pop(c, e.key),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
    if (selected == null || !mounted) return;
    final saved = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(session: session, mode: selected),
      ),
    );
    if (!mounted || saved == null) return;
    if (saved == 'photo') {
      // 撮影が続くときのために、その場で次を撮れるようにする。
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('登録しました'),
          action: SnackBarAction(
            label: '続けて撮る',
            onPressed: () => addItem(mode: 'photo'),
          ),
        ),
      );
    }
    if (saved == true) {
      search.clear();
      if (scroll.hasClients) scroll.jumpTo(0);
      setState(() => searching = false);
    }
  }

  Widget select(
    String label,
    String value,
    Map<String, String> values,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label$value'),
    initialValue: values.containsKey(value) ? value : '',
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: '', child: Text('すべて')),
      ...values.entries.map(
        (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
      ),
    ],
    onChanged: (v) => change(v ?? ''),
  );

  Future<void> filters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, update) {
          // 表記ゆれを1件にまとめる。表示名は最初に見つかったものを使う。
          final brands = <String, String>{};
          final sizes = <String, String>{};
          for (final i in session.items) {
            final name = i.text('brand');
            if (name.isNotEmpty) brands.putIfAbsent(brandKey(name), () => name);
            final size = i.text('size');
            if (size.isNotEmpty) sizes.putIfAbsent(sizeKey(size), () => size);
          }
          void set(void Function() fn) {
            update(fn);
            changed();
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  24 + MediaQuery.viewInsetsOf(c).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('絞り込み', style: TextStyle(fontSize: 22)),
                        TextButton(
                          onPressed: () => set(() {
                            session.browse.clear();
                            search.clear();
                          }),
                          child: const Text('すべて解除'),
                        ),
                      ],
                    ),
                    select(
                      'ブランド',
                      brandKey(session.browse.brand),
                      brands,
                      (v) => set(() => session.browse.brand = v),
                    ),
                    select(
                      'カラー',
                      session.browse.color,
                      colors,
                      (v) => set(() => session.browse.color = v),
                    ),
                    select(
                      '袖丈',
                      session.browse.sleeve,
                      sleeves,
                      (v) => set(() => session.browse.sleeve = v),
                    ),
                    select(
                      'サイズ',
                      sizeKey(session.browse.size),
                      sizes,
                      (v) => set(() => session.browse.size = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('手放した服'),
                      value: session.browse.status == 'archived',
                      onChanged: (v) => set(
                        () => session.browse.status = v ? 'archived' : 'active',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(c),
                        child: Text(
                          '${session.browse.apply(session.items).length}点を表示',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, _) {
      final items = session.browse.apply(session.items),
          density = session.browse.density;
      return Scaffold(
        appBar: AppBar(
          title: searching
              ? TextField(
                  controller: search,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'ブランド・商品名で検索',
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => session.browse.query = v),
                )
              : const Text(
                  'WDRB',
                  style: TextStyle(fontSize: 21, letterSpacing: 4),
                ),
          actions: [
            IconButton(
              tooltip: searching ? '検索を閉じる' : '検索',
              onPressed: () => setState(() {
                searching = !searching;
                if (!searching) {
                  search.clear();
                  session.browse.query = '';
                }
              }),
              icon: Icon(searching ? Icons.close : Icons.search),
            ),
            IconButton(
              tooltip: '絞り込み',
              onPressed: filters,
              icon: Badge(
                isLabelVisible: session.browse.filterCount > 0,
                label: Text('${session.browse.filterCount}'),
                child: const Icon(Icons.tune),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'logout' &&
                    await confirm(
                      context,
                      'ログアウトしますか？',
                      'この端末のクローゼットキャッシュを削除します。',
                    )) {
                  await session.logout();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(session.user?['email']?.toString() ?? ''),
                ),
                const PopupMenuItem(value: 'logout', child: Text('ログアウト')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final e in {'': 'すべて', ...categories}.entries)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: session.browse.category == e.key
                            ? Colors.black
                            : Colors.grey,
                      ),
                      onPressed: () {
                        session.browse.category = e.key;
                        if (!['tops', 'shirts'].contains(e.key)) {
                          session.browse.sleeve = '';
                        }
                        changed();
                      },
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: session.browse.category == e.key
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (['tops', 'shirts'].contains(session.browse.category))
              SizedBox(
                key: const ValueKey('sleeve-shortcuts'),
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: sleeves.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, index) {
                    final entry = index == 0
                        ? const MapEntry('', 'すべて')
                        : sleeves.entries.elementAt(index - 1);
                    final selected = session.browse.sleeve == entry.key;
                    return ChoiceChip(
                      showCheckmark: false,
                      selected: selected,
                      selectedColor: Colors.black,
                      backgroundColor: const Color(0xfff3f2ef),
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      label: Text(entry.value),
                      onSelected: (_) {
                        session.browse.sleeve = entry.key;
                        changed();
                      },
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${items.length} ITEMS',
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      color: Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    initialValue: session.browse.sort,
                    onSelected: (v) {
                      session.browse.sort = v;
                      changed();
                    },
                    itemBuilder: (_) => sorts.entries
                        .map(
                          (e) =>
                              PopupMenuItem(value: e.key, child: Text(e.value)),
                        )
                        .toList(),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        '${sorts[session.browse.sort]} ↓',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '表示密度 $density列',
                    onPressed: () {
                      session.browse.density = density == 4 ? 2 : density + 1;
                      changed();
                    },
                    icon: Icon(
                      density == 2
                          ? Icons.grid_view
                          : density == 3
                          ? Icons.grid_on
                          : Icons.apps,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            if (session.error != null)
              InkWell(
                onTap: session.sync,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${session.error}  ↻',
                    style: const TextStyle(fontSize: 12, color: Colors.brown),
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: session.sync,
                child: _content(items, density),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.checkroom_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('クローゼット', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: addItem,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('服を追加', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _content(List<WardrobeItem> items, int density) {
    if (!session.loaded && session.syncing) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: .65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 24,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => const ColoredBox(color: Color(0xfff6f5f2)),
      );
    }
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 130),
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.checkroom_outlined,
                  size: 38,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                Text(session.items.isEmpty ? 'まだ服がありません' : 'この条件の服はありません'),
                const SizedBox(height: 8),
                if (session.items.isEmpty)
                  const Text(
                    'URLや写真から追加できます',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: session.items.isEmpty
                      ? addItem
                      : () {
                          session.browse.clear();
                          search.clear();
                          changed();
                        },
                  child: Text(session.items.isEmpty ? '服を追加' : '条件を解除'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, bounds) {
        final width = (bounds.maxWidth - 32 - (density - 1) * 12) / density;
        return GridView.builder(
          key: const PageStorageKey('wardrobe-grid'),
          controller: scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: density,
            crossAxisSpacing: 12,
            mainAxisSpacing: 24,
            mainAxisExtent: width * 1.25 + (density == 4 ? 24 : 68),
          ),
          itemCount: items.length,
          itemBuilder: (_, n) {
            final item = items[n];
            return Semantics(
              label: '${item.text('brand')} ${item.name}',
              button: true,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetailScreen(session: session, id: item.id),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: item.id,
                      child: ItemImage(
                        api: session.api,
                        image: item.images.firstOrNull,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      item.text('brand').isEmpty
                          ? '—'
                          : item.text('brand').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: density == 4 ? 9 : 11,
                        letterSpacing: .7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (density != 4) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: Color(0xff706e69),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
