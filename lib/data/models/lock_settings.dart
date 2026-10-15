import '../../core/password_hash.dart';

/// Ayarlar kilidi: parola özeti, isteğe bağlı ipucu ve kurtarma kodu özeti.
class LockSettings {
  const LockSettings({required this.password, this.hint, required this.recovery});

  /// Bozuk/eksik alanda istisna fırlatır (AppConfig yakalar).
  factory LockSettings.fromJson(Map<String, dynamic> json) => LockSettings(
        password: PasswordRecord.fromJson(json['password'] as Map<String, dynamic>),
        hint: json['hint'] is String ? json['hint'] as String : null,
        recovery: PasswordRecord.fromJson(json['recovery'] as Map<String, dynamic>),
      );

  final PasswordRecord password;
  final String? hint;
  final PasswordRecord recovery;

  LockSettings copyWith({PasswordRecord? password, String? Function()? hint, PasswordRecord? recovery}) => LockSettings(
        password: password ?? this.password,
        hint: hint != null ? hint() : this.hint,
        recovery: recovery ?? this.recovery,
      );

  Map<String, dynamic> toJson() => {
        'password': password.toJson(),
        if (hint != null) 'hint': hint,
        'recovery': recovery.toJson(),
      };
}
