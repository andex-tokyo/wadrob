import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'api.dart';
import 'cache.dart';
import 'models.dart';
import 'images.dart';

class Session extends ChangeNotifier {
  final Api api;
  final WardrobeCache cache;
  final SharedPreferences prefs;
  final FlutterSecureStorage secure;
  Session(
    this.api,
    this.cache,
    this.prefs, {
    this.secure = const FlutterSecureStorage(),
  });
  Map<String, dynamic>? user;
  List<WardrobeItem> items = [];
  BrowseOptions browse = BrowseOptions();
  bool initializing = true, busy = false, syncing = false, loaded = false;
  String? error;
  int _epoch = 0;
  bool _googleReady = false;
  final Set<String> _processing = {};
  Future<void> _google() async {
    if (_googleReady) return;
    if (googleClientId.isEmpty) {
      throw Exception('Google OAuth Client IDが設定されていません');
    }
    await GoogleSignIn.instance.initialize(serverClientId: googleClientId);
    _googleReady = true;
  }

  Future<void> restore() async {
    try {
      final stored = await secure.read(key: 'session');
      if (stored != null) {
        final saved = jsonDecode(stored) as Map<String, dynamic>;
        if (DateTime.parse(
          saved['expiresAt'] as String,
        ).isAfter(DateTime.now())) {
          api.token = saved['token'] as String;
          user = Map<String, dynamic>.from(saved['user'] as Map);
          await _loadCache();
          initializing = false;
          notifyListeners();
          try {
            final me = await api.get('/api/auth/me');
            user = Map<String, dynamic>.from(me['user'] as Map);
            await sync();
          } on DioException catch (e) {
            if (e.response?.statusCode == 401) {
              await logout();
              await login(silent: true);
            } else {
              error = '最新情報を取得できませんでした';
            }
          }
        } else {
          await login(silent: true);
        }
      }
    } catch (e) {
      error = errorMessage(e);
    }
    initializing = false;
    notifyListeners();
  }

  Future<void> _loadCache() async {
    final id = user!['id'] as String;
    items = await cache.read(id);
    browse = BrowseOptions.fromJson(
      jsonDecode(prefs.getString('browse.$id') ?? '{}') as Map<String, dynamic>,
    );
    loaded = items.isNotEmpty;
  }

  Future<void> login({bool silent = false}) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _google();
      final account = silent
          ? await GoogleSignIn.instance.attemptLightweightAuthentication()
          : await GoogleSignIn.instance.authenticate();
      if (account == null) return;
      final token = account.authentication.idToken;
      if (token == null) throw Exception('Google認証情報を取得できませんでした');
      final data = await api.post('/api/auth/google', {'idToken': token});
      _epoch++;
      items = [];
      user = Map<String, dynamic>.from(data['user'] as Map);
      api.token = data['token'] as String;
      await secure.write(key: 'session', value: jsonEncode(data));
      await _loadCache();
      notifyListeners();
      await sync();
    } catch (e) {
      if (!silent) error = errorMessage(e);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> sync() async {
    if (user == null) return;
    final epoch = _epoch, id = user!['id'] as String;
    syncing = true;
    notifyListeners();
    try {
      final result = await api.get('/api/items');
      if (epoch != _epoch) return;
      final next = (result['items'] as List)
          .map((e) => WardrobeItem(Map<String, dynamic>.from(e as Map)))
          .toList();
      await cache.replace(id, next);
      if (epoch != _epoch) return;
      items = next;
      loaded = true;
      error = null;
      unawaited(processPending());
    } catch (e) {
      if (epoch == _epoch) {
        error = '最新情報を取得できませんでした';
        if (e is DioException && e.response?.statusCode == 401) {
          await logout();
          await login(silent: true);
        }
      }
    } finally {
      if (epoch == _epoch) {
        syncing = false;
        notifyListeners();
      }
    }
  }

  Future<void> processPending() async {
    final epoch = _epoch;
    final pending = items
        .expand((i) => i.images)
        .where((i) => ['pending', 'processing'].contains(i['processingStatus']))
        .toList();
    for (final image in pending) {
      if (epoch != _epoch) return;
      final id = image['id'] as String;
      if (!_processing.add(id)) continue;
      await ImageService(api).process(image);
      _processing.remove(id);
      if (epoch == _epoch) await sync();
    }
  }

  Future<void> save(Map<String, dynamic> data, {String? id}) async {
    final r = id == null
        ? await api.post('/api/items', data)
        : await api.put('/api/items/$id', data);
    final saved = WardrobeItem(Map<String, dynamic>.from(r['item'] as Map));
    items = [saved, ...items.where((i) => i.id != saved.id)];
    await cache.replace(user!['id'] as String, items);
    browse.clear();
    browse.sort = 'recent';
    await persistBrowse();
    notifyListeners();
    unawaited(sync());
  }

  Future<void> archive(String id) async {
    await api.post('/api/items/$id/archive');
    await sync();
  }

  Future<void> deleteItem(String id) async {
    await api.delete('/api/items/$id');
    items.removeWhere((i) => i.id == id);
    await cache.replace(user!['id'] as String, items);
    notifyListeners();
  }

  Future<void> persistBrowse() async {
    if (user != null) {
      await prefs.setString(
        'browse.${user!['id']}',
        jsonEncode(browse.toJson()),
      );
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _epoch++;
    user = null;
    items = [];
    api.token = null;
    loaded = false;
    syncing = false;
    error = null;
    browse = BrowseOptions();
    await secure.delete(key: 'session');
    await cache.clear();
    await DefaultCacheManager().emptyCache();
    try {
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    notifyListeners();
  }
}
