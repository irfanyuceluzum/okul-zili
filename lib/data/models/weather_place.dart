/// Hava durumu konumu (Ayarlar'dan aranıp seçilir).
class WeatherPlace {
  const WeatherPlace({required this.name, required this.region, required this.latitude, required this.longitude});

  factory WeatherPlace.fromJson(Map<String, dynamic> json) => WeatherPlace(
        name: json['name'] as String,
        region: json['region'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  final String name;

  /// "Hatay" gibi; listede ve ayarlarda ayırt etmek için.
  final String region;
  final double latitude;
  final double longitude;

  String get label => region.isEmpty || region == name ? name : '$name, $region';

  Map<String, dynamic> toJson() => {'name': name, 'region': region, 'latitude': latitude, 'longitude': longitude};
}
