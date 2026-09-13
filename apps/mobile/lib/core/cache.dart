import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class WardrobeCache extends GeneratedDatabase {
  WardrobeCache(super.e);
  static Future<WardrobeCache> open() async {
    final dir = await getApplicationSupportDirectory();
    return WardrobeCache(
      NativeDatabase.createInBackground(File('${dir.path}/wardrobe.sqlite')),
    );
  }

  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE cache_items(user_id TEXT NOT NULL,id TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(user_id,id))',
      );
    },
  );
  Future<List<WardrobeItem>> read(String user) async =>
      (await customSelect(
            'SELECT payload FROM cache_items WHERE user_id=?',
            variables: [Variable.withString(user)],
          ).get())
          .map(
            (r) => WardrobeItem(
              jsonDecode(r.read<String>('payload')) as Map<String, dynamic>,
            ),
          )
          .toList();
  Future<void> replace(String user, List<WardrobeItem> items) => transaction(
    () async {
      await customStatement('DELETE FROM cache_items WHERE user_id=?', [user]);
      for (final i in items) {
        await customStatement('INSERT INTO cache_items VALUES(?,?,?)', [
          user,
          i.id,
          jsonEncode(i.data),
        ]);
      }
    },
  );
  Future<void> clear() => customStatement('DELETE FROM cache_items');
}
