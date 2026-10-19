import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../data/models/weather_place.dart';

export '../data/models/weather_place.dart';

/// Bir anlık hava durumu ve günün özeti.
class WeatherReport {
  const WeatherReport({
    required this.temperature,
    required this.code,
    required this.isDay,
    required this.min,
    required this.max,
    required this.precipitationChance,
    required this.fetchedAt,
  });

  factory WeatherReport.fromJson(Map<String, dynamic> json) => WeatherReport(
        temperature: (json['temperature'] as num).toDouble(),
        code: (json['code'] as num).toInt(),
        isDay: json['isDay'] as bool? ?? true,
        min: (json['min'] as num?)?.toDouble(),
        max: (json['max'] as num?)?.toDouble(),
        precipitationChance: (json['precipitationChance'] as num?)?.toInt(),
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );

  final double temperature;

  /// WMO hava durumu kodu (Open-Meteo).
  final int code;
  final bool isDay;
  final double? min;
  final double? max;
  final int? precipitationChance;
  final DateTime fetchedAt;

  WeatherReport withFetchedAt(DateTime at) => WeatherReport(
        temperature: temperature,
        code: code,
        isDay: isDay,
        min: min,
        max: max,
        precipitationChance: precipitationChance,
        fetchedAt: at,
      );

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'code': code,
        'isDay': isDay,
        'min': min,
        'max': max,
        'precipitationChance': precipitationChance,
        'fetchedAt': fetchedAt.toIso8601String(),
      };
}

/// Hava durumu kaynağı (testlerde sahtesi kullanılır).
abstract interface class WeatherClient {
  Future<List<WeatherPlace>> searchPlaces(String query);
  Future<WeatherReport> fetch(WeatherPlace place);
}

/// Open-Meteo: ücretsiz, anahtarsız (ticari olmayan kullanım), veri CC BY 4.0.
class OpenMeteoClient implements WeatherClient {
  const OpenMeteoClient();

  static const _timeout = Duration(seconds: 10);

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      final body = await response.transform(utf8.decoder).join().timeout(_timeout);
      if (response.statusCode != 200) throw HttpException('Sunucu yanıtı ${response.statusCode}', uri: uri);
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<List<WeatherPlace>> searchPlaces(String query) async {
    final json = await _get(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query,
      'count': '10',
      'language': 'tr',
      'format': 'json',
    }));
    final results = json['results'] as List? ?? const [];
    return [
      for (final r in results.cast<Map<String, dynamic>>())
        if (r['latitude'] is num && r['longitude'] is num)
          WeatherPlace(
            name: r['name'] as String? ?? '',
            region: [
              r['admin1'] as String?,
              if (r['country_code'] != 'TR') r['country'] as String?,
            ].whereType<String>().join(', '),
            latitude: (r['latitude'] as num).toDouble(),
            longitude: (r['longitude'] as num).toDouble(),
          ),
    ];
  }

  @override
  Future<WeatherReport> fetch(WeatherPlace place) async {
    final json = await _get(Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${place.latitude}',
      'longitude': '${place.longitude}',
      'current': 'temperature_2m,weather_code,is_day',
      'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '1',
    }));
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>? ?? const {};
    num? first(String key) => (daily[key] as List?)?.cast<num?>().firstOrNull;
    return WeatherReport(
      temperature: (current['temperature_2m'] as num).toDouble(),
      code: (current['weather_code'] as num).toInt(),
      isDay: current['is_day'] == 1,
      min: first('temperature_2m_min')?.toDouble(),
      max: first('temperature_2m_max')?.toDouble(),
      precipitationChance: first('precipitation_probability_max')?.toInt(),
      fetchedAt: DateTime.now(),
    );
  }
}

/// WMO kodunun Türkçe karşılığı (Open-Meteo belgesindeki gruplar).
String weatherDescription(int code) => switch (code) {
      0 => 'Açık',
      1 => 'Az bulutlu',
      2 => 'Parçalı bulutlu',
      3 => 'Bulutlu',
      45 || 48 => 'Sisli',
      51 || 53 || 55 || 56 || 57 => 'Çiseleyen yağmur',
      61 || 63 || 66 => 'Yağmurlu',
      65 || 67 => 'Kuvvetli yağmur',
      71 || 73 || 77 => 'Karlı',
      75 => 'Yoğun kar',
      80 || 81 => 'Sağanak yağışlı',
      82 => 'Kuvvetli sağanak',
      85 || 86 => 'Kar sağanağı',
      95 => 'Gök gürültülü',
      96 || 99 => 'Dolu ve fırtına',
      _ => 'Bilinmiyor',
    };
