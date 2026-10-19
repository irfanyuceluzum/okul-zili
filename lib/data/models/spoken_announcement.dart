/// Anonsun nereden geldiği.
enum AnnouncementSource {
  file('Ses dosyası'),
  recording('Mikrofon kaydı'),
  speech('Yazıdan okuma');

  const AnnouncementSource(this.label);

  final String label;
}

/// Hoparlörden yapılan sesli anons. Ses dosyası ya da mikrofon kaydıysa
/// [path] (ayar klasöründeki `sesler/` altında) doludur; yazıdan okumaysa
/// [text] Windows'un konuşma sesiyle okunur. Panodaki yazılı duyurulardan
/// (Announcement) ayrıdır.
class SpokenAnnouncement {
  const SpokenAnnouncement({
    required this.id,
    required this.name,
    required this.source,
    this.path,
    this.text,
    this.chime = true,
  });

  factory SpokenAnnouncement.fromJson(Map<String, dynamic> json) {
    final source = AnnouncementSource.values.byName(json['source'] as String);
    final path = json['path'] as String?;
    final text = json['text'] as String?;
    if (source == AnnouncementSource.speech ? (text ?? '').trim().isEmpty : (path ?? '').isEmpty) {
      throw const FormatException('anons içeriği eksik');
    }
    return SpokenAnnouncement(
      id: json['id'] as String,
      name: json['name'] as String,
      source: source,
      path: path,
      text: text,
      chime: json['chime'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final AnnouncementSource source;

  /// Ses dosyası ya da kayıt için dosya yolu.
  final String? path;

  /// Yazıdan okuma için metin.
  final String? text;

  /// Anonstan önce dikkat sesi (ding-dong) çalsın mı.
  final bool chime;

  bool get isAudio => source != AnnouncementSource.speech;

  SpokenAnnouncement copyWith({String? name, String? path, String? text, bool? chime}) => SpokenAnnouncement(
        id: id,
        name: name ?? this.name,
        source: source,
        path: path ?? this.path,
        text: text ?? this.text,
        chime: chime ?? this.chime,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.name,
        if (path != null) 'path': path,
        if (text != null) 'text': text,
        'chime': chime,
      };
}
