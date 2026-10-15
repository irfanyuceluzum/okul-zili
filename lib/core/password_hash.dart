import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Saklanan parola özeti: tuz + PBKDF2 çıktısı + iterasyon sayısı.
/// Parolanın kendisi hiçbir yerde tutulmaz.
class PasswordRecord {
  const PasswordRecord({required this.salt, required this.hash, required this.iterations});

  /// Bozuk/eksik alanda [FormatException] fırlatır.
  factory PasswordRecord.fromJson(Map<String, dynamic> json) {
    final salt = json['salt'];
    final hash = json['hash'];
    final iterations = json['iterations'];
    if (salt is! String || hash is! String || iterations is! num || iterations < 1) {
      throw const FormatException('Parola kaydı okunamadı');
    }
    // Base64 geçerli mi (bozuksa burada FormatException fırlar).
    base64Decode(salt);
    base64Decode(hash);
    return PasswordRecord(salt: salt, hash: hash, iterations: iterations.toInt());
  }

  /// Base64.
  final String salt;

  /// Base64.
  final String hash;
  final int iterations;

  Map<String, dynamic> toJson() => {'salt': salt, 'hash': hash, 'iterations': iterations};
}

/// Parola özeti üretimi ve doğrulaması (PBKDF2-HMAC-SHA256, RFC 8018).
/// Saf fonksiyonlar; yavaştır (varsayılan 120000 iterasyon), gerekirse
/// `Isolate.run` ile çağrılmalıdır.
class PasswordHash {
  PasswordHash._();

  static const saltLength = 16;
  static const hashLength = 32;

  static PasswordRecord create(String secret, {int iterations = 120000}) {
    final rnd = Random.secure();
    final salt = Uint8List.fromList(List<int>.generate(saltLength, (_) => rnd.nextInt(256)));
    final key = pbkdf2Sha256(utf8.encode(secret), salt, iterations, hashLength);
    return PasswordRecord(salt: base64Encode(salt), hash: base64Encode(key), iterations: iterations);
  }

  static bool verify(String secret, PasswordRecord record) {
    try {
      final expected = base64Decode(record.hash);
      final salt = base64Decode(record.salt);
      if (record.iterations < 1 || expected.isEmpty) return false;
      final actual = pbkdf2Sha256(utf8.encode(secret), salt, record.iterations, expected.length);
      return _constantTimeEquals(actual, expected);
    } catch (_) {
      return false;
    }
  }

  /// PBKDF2 (RFC 8018 §5.2), PRF = HMAC-SHA256.
  static Uint8List pbkdf2Sha256(List<int> password, List<int> salt, int iterations, int dkLen) {
    final hmac = Hmac(sha256, password);
    const hLen = 32;
    final blocks = (dkLen + hLen - 1) ~/ hLen;
    final out = Uint8List(blocks * hLen);
    for (var i = 1; i <= blocks; i++) {
      final intBlock = [(i >> 24) & 0xff, (i >> 16) & 0xff, (i >> 8) & 0xff, i & 0xff];
      var u = hmac.convert([...salt, ...intBlock]).bytes;
      final t = List<int>.from(u);
      for (var c = 1; c < iterations; c++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < hLen; k++) {
          t[k] ^= u[k];
        }
      }
      out.setRange((i - 1) * hLen, i * hLen, t);
    }
    return Uint8List.sublistView(out, 0, dkLen);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    final n = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Parola özeti hesabı; arayüzü dondurmamak için yavaş işi dışarı alan bir
/// arayüz. Testlerde hızlı sahtesi verilir.
abstract interface class PasswordHasher {
  Future<PasswordRecord> create(String secret);
  Future<bool> verify(String secret, PasswordRecord record);
}

/// PBKDF2'yi ayrı bir isolate'ta (120000 iterasyon) çalıştırır.
class IsolatePasswordHasher implements PasswordHasher {
  const IsolatePasswordHasher();

  static const iterations = 120000;

  @override
  Future<PasswordRecord> create(String secret) =>
      Isolate.run(() => PasswordHash.create(secret, iterations: iterations));

  @override
  Future<bool> verify(String secret, PasswordRecord record) => Isolate.run(() => PasswordHash.verify(secret, record));
}
