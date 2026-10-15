import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/core/password_hash.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/data/models/lock_settings.dart';

String _hex(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('PBKDF2-HMAC-SHA256 RFC 7914 vektörü (c=1, dkLen=64)', () {
    final dk = PasswordHash.pbkdf2Sha256(utf8.encode('passwd'), utf8.encode('salt'), 1, 64);
    expect(
      _hex(dk),
      '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc4'
      '9ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
    );
  });

  test('create → verify: doğru parola true, yanlış false', () {
    final r = PasswordHash.create('gizli123', iterations: 1000);
    expect(PasswordHash.verify('gizli123', r), isTrue);
    expect(PasswordHash.verify('gizli124', r), isFalse);
    expect(PasswordHash.verify('', r), isFalse);
  });

  test('iki create farklı tuz/hash üretir; iterations kayda yazılır', () {
    final a = PasswordHash.create('aynı', iterations: 1000);
    final b = PasswordHash.create('aynı', iterations: 1000);
    expect(a.salt, isNot(b.salt));
    expect(a.hash, isNot(b.hash));
    expect(a.iterations, 1000);
    expect(base64Decode(a.salt).length, 16);
    expect(base64Decode(a.hash).length, 32);
  });

  test('bozuk kayıt doğrulamada false döner', () {
    expect(PasswordHash.verify('x', const PasswordRecord(salt: '!!', hash: '??', iterations: 1000)), isFalse);
  });

  test('PasswordRecord gidiş-dönüş', () {
    final r = PasswordHash.create('x', iterations: 1000);
    final back = PasswordRecord.fromJson(r.toJson());
    expect(back.salt, r.salt);
    expect(back.hash, r.hash);
    expect(back.iterations, 1000);
  });

  group('AppConfig.lock', () {
    LockSettings makeLock() => LockSettings(
          password: PasswordHash.create('parola-GIZLI', iterations: 1000),
          hint: 'ipucu',
          recovery: PasswordHash.create('KURTARMA-KODU', iterations: 1000),
        );

    test('gidiş-dönüş', () {
      final config = createDefaultConfig().copyWith(lock: () => makeLock());
      final back = AppConfig.fromJson(jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>);
      expect(back.lock, isNotNull);
      expect(back.lock!.hint, 'ipucu');
      expect(PasswordHash.verify('parola-GIZLI', back.lock!.password), isTrue);
      expect(PasswordHash.verify('KURTARMA-KODU', back.lock!.recovery), isTrue);
      expect(PasswordHash.verify('yanlış', back.lock!.password), isFalse);
    });

    test('lock alanı yoksa null; copyWith ile null\'a çekilir', () {
      final base = createDefaultConfig();
      final json = base.toJson();
      expect(json.containsKey('lock'), isFalse);
      expect(AppConfig.fromJson(json).lock, isNull);
      final locked = base.copyWith(lock: () => makeLock());
      expect(locked.copyWith(volumePercent: 50).lock, isNotNull);
      expect(locked.copyWith(lock: () => null).lock, isNull);
    });

    test('bozuk lock → null + uyarı', () {
      final json = createDefaultConfig().toJson();
      json['lock'] = {'password': 'bozuk'};
      final warnings = <String>[];
      final c = AppConfig.fromJson(json, warnings: warnings);
      expect(c.lock, isNull);
      expect(warnings.any((w) => w.contains('Kilit ayarı okunamadı')), isTrue);
    });

    test('düz metin parola JSON\'da geçmez', () {
      final config = createDefaultConfig().copyWith(lock: () => makeLock());
      final text = jsonEncode(config.toJson());
      expect(text.contains('parola-GIZLI'), isFalse);
      expect(text.contains('KURTARMA-KODU'), isFalse);
    });
  });
}
