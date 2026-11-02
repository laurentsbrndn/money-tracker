import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

const String _databaseFileName = 'moneytracker.db';
const String _keyStorageName = 'db_encryption_key';
const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

/// Opens the SQLite3MultipleCiphers-encrypted database. The 32-byte random key
/// lives in the Android Keystore (via `flutter_secure_storage`).
Future<AppDatabase> openAppDatabase() async {
  final key = await _readOrCreateKey();
  final file = await _databaseFile();
  return AppDatabase(
    LazyDatabase(
      () async => NativeDatabase.createInBackground(
        file,
        setup: (rawDb) {
          // Fail closed: never fall back to a plain SQLite build.
          if (rawDb.select('PRAGMA cipher;').isEmpty) {
            throw StateError('Encrypted SQLite build is not available');
          }
          rawDb.execute("PRAGMA key = '$key';");
        },
      ),
    ),
  );
}

/// Logout: close [database], delete the file(s), and delete the key.
Future<void> wipeAppDatabase(AppDatabase database) async {
  await database.close();
  final file = await _databaseFile();
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final target = File('${file.path}$suffix');
    if (target.existsSync()) {
      await target.delete();
    }
  }
  await _secureStorage.delete(key: _keyStorageName);
}

Future<File> _databaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/$_databaseFileName');
}

Future<String> _readOrCreateKey() async {
  final existing = await _secureStorage.read(key: _keyStorageName);
  if (existing != null && existing.isNotEmpty) {
    return existing;
  }
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final key = base64UrlEncode(bytes).replaceAll('=', '');
  await _secureStorage.write(key: _keyStorageName, value: key);
  return key;
}
