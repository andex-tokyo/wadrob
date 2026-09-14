import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SharedUrlReceiver extends ChangeNotifier {
  SharedUrlReceiver({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'tokyo.andex.wadrob/share';
  final MethodChannel _channel;
  String? _pendingUrl;

  String? get pendingUrl => _pendingUrl;

  Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText') receiveText(call.arguments as String?);
    });
    try {
      receiveText(await _channel.invokeMethod<String>('getInitialSharedText'));
    } on MissingPluginException {
      // Android以外やwidget testでは共有チャネルを持たない。
    }
  }

  void receiveText(String? text) {
    final url = extractUrl(text);
    if (url == null || url == _pendingUrl) return;
    _pendingUrl = url;
    notifyListeners();
  }

  String? take() {
    final url = _pendingUrl;
    _pendingUrl = null;
    return url;
  }

  @visibleForTesting
  static String? extractUrl(String? text) {
    if (text == null) return null;
    final match = RegExp(r'''https?://[^\s<>"']+''').firstMatch(text);
    if (match == null) return null;
    final value = match
        .group(0)!
        .replaceFirst(RegExp(r'''[\)）\]}>、。，．,.;:!?！？」』】]+$'''), '');
    final uri = Uri.tryParse(value);
    return uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty
        ? uri.toString()
        : null;
  }
}
