import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';

import 'support/app_harness.dart';

void main() {
  late Directory tmp;
  late ConfigRepository repo;
  late AppController c;
  late RecordingPlayer player;
  var now = DateTime(2026, 3, 4, 10, 0);

  setUp(() async {
    now = DateTime(2026, 3, 4, 10, 0);
    tmp = Directory.systemTemp.createTempSync('okul_zili_kilit');
    repo = ConfigRepository(File('${tmp.path}${Platform.pathSeparator}config.json'));
    final config = createDefaultConfig().copyWith(schoolName: 'Mevcut Okul');
    await repo.save(config);
    player = RecordingPlayer();
    c = AppController(
      config: config,
      repository: repo,
      player: player,
      now: () => now,
      passwordHasher: const FastPasswordHasher(),
    );
  });
  tearDown(() {
    c.dispose();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  test('şifre belirlenince kurtarma kodu 1234-5678 biçiminde, config\'te düz metin yok, oturum açık', () async {
    expect(c.isLockEnabled, isFalse);
    expect(c.isLocked, isFalse);
    final code = await c.setPassword(newPassword: 'gizli1', hint: ' ilk evcil hayvan ');
    expect(code, matches(RegExp(r'^\d{4}-\d{4}$')));
    expect(c.isLockEnabled, isTrue);
    expect(c.isLocked, isFalse);
    expect(c.config.lock!.hint, 'ilk evcil hayvan');
    final onDisk = repo.file.readAsStringSync();
    expect(onDisk.contains('gizli1'), isFalse);
    expect(onDisk.contains(code), isFalse);
    expect(onDisk.contains(code.replaceAll('-', '')), isFalse);
    expect(c.config.lock!.password.iterations, 1000);
  });

  test('4 karakterden kısa parola reddedilir', () async {
    await expectLater(c.setPassword(newPassword: 'abc'), throwsArgumentError);
    expect(c.isLockEnabled, isFalse);
  });

  test('kilitliyken updateConfig false, config aynı, lastError null, lockRefused işaretli', () async {
    await c.setPassword(newPassword: 'gizli1');
    c.lock();
    expect(c.isLocked, isTrue);
    final before = c.config;
    final saved = await c.updateConfig(before.copyWith(schoolName: 'Değişti'));
    expect(saved, isFalse);
    expect(identical(c.config, before), isTrue);
    expect(c.config.schoolName, 'Mevcut Okul');
    expect(c.lastError, isNull);
    expect(c.lockRefused, isTrue);
    expect(repo.readConfigFile(repo.file).$1.schoolName, 'Mevcut Okul');
  });

  test('unlock: yanlış parola açmaz, doğru parola açar ve yazmaya izin verir', () async {
    await c.setPassword(newPassword: 'gizli1');
    c.lock();
    expect(await c.unlock('yanlis'), isFalse);
    expect(c.isLocked, isTrue);
    expect(await c.unlock('gizli1'), isTrue);
    expect(c.isLocked, isFalse);
    expect(await c.updateConfig(c.config.copyWith(schoolName: 'Yeni')), isTrue);
    expect(c.config.schoolName, 'Yeni');
  });

  test('kurtarma koduyla (tire/boşluklu ya da yazımsız) kilit açılır', () async {
    final code = await c.setPassword(newPassword: 'gizli1');
    c.lock();
    expect(await c.unlock(code), isTrue);
    c.lock();
    expect(await c.unlock(code.replaceAll('-', ' ')), isTrue);
    c.lock();
    expect(await c.unlock(code.replaceAll('-', '')), isTrue);
    c.lock();
    final wrong = code.startsWith('0') ? '1111-1111' : '0000-0000';
    expect(await c.unlock(wrong), isFalse);
  });

  test('15 dakika sonra tekrar kilitlenir; başarılı kayıt süreyi uzatır', () async {
    await c.setPassword(newPassword: 'gizli1');
    now = now.add(const Duration(minutes: 14));
    expect(c.isLocked, isFalse);
    expect(await c.updateConfig(c.config.copyWith(schoolName: 'A')), isTrue);
    now = now.add(const Duration(minutes: 14));
    expect(c.isLocked, isFalse);
    now = now.add(const Duration(minutes: 1));
    expect(c.isLocked, isTrue);
    expect(await c.updateConfig(c.config.copyWith(schoolName: 'B')), isFalse);
    expect(c.config.schoolName, 'A');
  });

  test('açılışta (hiç açılmamış) kilitli başlar', () async {
    await c.setPassword(newPassword: 'gizli1');
    final c2 = AppController(
      config: c.config,
      repository: repo,
      player: SilentPlayer(),
      now: () => now,
      passwordHasher: const FastPasswordHasher(),
    );
    addTearDown(c2.dispose);
    expect(c2.isLocked, isTrue);
  });

  test('kilitliyken setPassword mevcut parolasız reddedilir; doğru parola/kodla değişir', () async {
    final code = await c.setPassword(newPassword: 'gizli1');
    c.lock();
    await expectLater(c.setPassword(newPassword: 'hacker'), throwsStateError);
    await expectLater(c.setPassword(current: 'yanlis', newPassword: 'hacker'), throwsStateError);
    expect(await c.unlock('gizli1'), isTrue);
    c.lock();
    final code2 = await c.setPassword(current: code, newPassword: 'yeni77');
    expect(code2, isNot(code));
    expect(c.isLocked, isFalse);
    c.lock();
    expect(await c.unlock('gizli1'), isFalse);
    expect(await c.unlock('yeni77'), isTrue);
    c.lock();
    expect(await c.unlock(code), isFalse); // eski kod geçersiz
  });

  test('removeLock: yanlışta kalır, doğruda kilit kalkar ve kalıcı yazılır', () async {
    await c.setPassword(newPassword: 'gizli1');
    c.lock();
    expect(await c.removeLock('yanlis'), isFalse);
    expect(c.isLockEnabled, isTrue);
    expect(await c.removeLock('gizli1'), isTrue);
    expect(c.isLockEnabled, isFalse);
    expect(c.isLocked, isFalse);
    expect(repo.readConfigFile(repo.file).$1.lock, isNull);
    expect(await c.updateConfig(c.config.copyWith(schoolName: 'Serbest')), isTrue);
  });

  test('kilitliyken restoreBackup/importConfigFile/undoReplace/saveScheduleDraft yan etkisiz reddedilir', () async {
    final other = File('${tmp.path}${Platform.pathSeparator}diger.json')
      ..writeAsStringSync(repo.exportJson(createDefaultConfig().copyWith(schoolName: 'Başka')));
    // Kilitsizken bir değişiklik yapıp geri alınabilir hale getir.
    expect((await c.importConfigFile(other.path)).ok, isTrue);
    expect(c.canUndoReplace, isTrue);
    await c.setPassword(newPassword: 'gizli1');
    final draft = c.editSchedule();
    draft.dirty = true;
    c.lock();

    final backups = repo.listBackups().length;
    final r1 = await c.restoreBackup(BackupInfo(other, 'x'));
    final r2 = await c.importConfigFile(other.path);
    for (final r in [r1, r2]) {
      expect(r.ok, isFalse);
      expect(r.error, contains('kilitli'));
    }
    expect(repo.listBackups().length, backups); // snapshot alınmadı
    expect(c.scheduleDraft, same(draft)); // taslak atılmadı
    expect(c.config.schoolName, 'Başka');

    expect(await c.undoReplace(), isFalse);
    expect(c.canUndoReplace, isTrue);
    expect(c.config.schoolName, 'Başka');
    expect(c.scheduleDraft, same(draft));

    final errors = await c.saveScheduleDraft();
    expect(errors, isNotEmpty);
    expect(c.scheduleDraft, same(draft));
    expect(draft.dirty, isTrue);
    expect(c.lastError, isNull);
  });

  test('kilitliyken zil, susturma, acil durum ve durdurma çalışmaya devam eder', () async {
    await c.setPassword(newPassword: 'gizli1');
    c.lock();
    expect(c.isLocked, isTrue);

    await c.ringNow();
    expect(player.plays, isNotEmpty);

    c.muteForToday();
    expect(c.isMuted, isTrue);
    c.unmute();
    expect(c.isMuted, isFalse);
    c.muteUntil(now.add(const Duration(minutes: 10)));
    expect(c.isMuted, isTrue);
    c.unmute();
    c.muteUntilPeriodEnd();
    expect(c.isMuted, isTrue);
    c.unmute();
    expect(c.isMuted, isFalse);

    await c.startEmergency();
    expect(c.emergencyActive, isTrue);
    final stopsBefore = player.stops;
    await c.stopSound();
    expect(c.emergencyActive, isFalse);
    expect(player.stops, greaterThan(stopsBefore));
    expect(c.isLocked, isTrue);
  });
}
