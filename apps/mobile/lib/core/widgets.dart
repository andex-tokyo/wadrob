import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'api.dart';

class ItemImage extends StatelessWidget {
  const ItemImage({
    super.key,
    required this.api,
    this.image,
    this.original = false,
    this.thumbnail = true,
  });
  final Api api;
  final Map<String, dynamic>? image;
  final bool original, thumbnail;

  @override
  Widget build(BuildContext context) {
    final fallback = image == null ? null : image!['originalUrl'] as String?;
    final processed = image == null
        ? null
        : thumbnail
        ? image!['thumbnailUrl'] ?? image!['displayUrl']
        : image!['displayUrl'];
    final url = (original ? fallback : processed ?? fallback) as String?;
    Widget placeholder() => const Center(
      child: Icon(Icons.checkroom_outlined, size: 38, color: Color(0xffb8b5ae)),
    );
    Widget network(String path, {bool retry = true}) => CachedNetworkImage(
      imageUrl: api.url(path),
      httpHeaders: path.startsWith('/') ? api.headers : null,
      fit: BoxFit.contain,
      memCacheWidth: thumbnail ? 480 : 1200,
      placeholder: (_, _) => const SizedBox.expand(),
      errorWidget: (_, _, _) => retry && fallback != null && fallback != path
          ? network(fallback, retry: false)
          : placeholder(),
    );
    final normalized =
        url?.contains('/display') == true ||
        url?.contains('/thumbnail') == true;
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ColoredBox(
        color: const Color(0xfff6f5f2),
        child: Padding(
          padding: EdgeInsets.all(normalized ? 0 : 12),
          child: url == null ? placeholder() : network(url),
        ),
      ),
    );
  }
}

void showError(BuildContext context, Object error) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(errorMessage(error))));
Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('実行'),
          ),
        ],
      ),
    ) ??
    false;
