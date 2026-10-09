import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const EliastectempoApp());
}

const Color neonGreen = Color(0xFF39FF88);
const Color neonBlue = Color(0xFF39D9FF);
const Color darkBackground = Color(0xFF080D1C);
const Color panelColor = Color(0xFF121C32);
const Color neonPink = Color(0xFFFF5EDB);

class EliastectempoApp extends StatelessWidget {
  const EliastectempoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eliastectempo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: neonGreen,
          brightness: Brightness.dark,
        ),
        fontFamily: 'monospace',
      ),
      home: const WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  // Coordenadas padrão de Londrina, Paraná.
  static const double latitude = -23.3045;
  static const double longitude = -51.1696;

  bool loading = true;
  String? errorMessage;

  double temperature = 0;
  double feelsLike = 0;
  double humidity = 0;
  double windSpeed = 0;
  double precipitation = 0;
  int weatherCode = 0;
  bool isDay = true;

  List<Map<String, dynamic>> hourlyForecast = [];

  @override
  void initState() {
    super.initState();
    loadWeather();
  }

  Future<void> loadWeather() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    final client = HttpClient();

    try {
      final uri = Uri.https(
        'api.open-meteo.com',
        '/v1/forecast',
        {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'current':
              'temperature_2m,relative_humidity_2m,apparent_temperature,'
                  'is_day,precipitation,weather_code,wind_speed_10m',
          'hourly': 'temperature_2m,precipitation_probability',
          'forecast_days': '1',
          'timezone': 'America/Sao_Paulo',
        },
      );

      final request = await client.getUrl(uri).timeout(
            const Duration(seconds: 15),
          );

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      final response = await request.close().timeout(
            const Duration(seconds: 15),
          );

      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('O serviço do tempo está indisponível.');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>;
      final hourly = data['hourly'] as Map<String, dynamic>;

      final times = List<String>.from(hourly['time'] as List);
      final temperatures =
          List<num>.from(hourly['temperature_2m'] as List);
      final rainChances =
          List<num>.from(hourly['precipitation_probability'] as List);

      final now = DateTime.now();

      final nextHours = <Map<String, dynamic>>[];

      for (int i = 0; i < times.length; i++) {
        final forecastTime = DateTime.tryParse(times[i]);

        if (forecastTime == null) continue;

        if (!forecastTime.isBefore(now) && nextHours.length < 6) {
          nextHours.add({
            'time': times[i],
            'temperature': temperatures[i],
            'rain': rainChances[i],
          });
        }
      }

      if (!mounted) return;

      setState(() {
        temperature = (current['temperature_2m'] as num).toDouble();
        feelsLike =
            (current['apparent_temperature'] as num).toDouble();
        humidity =
            (current['relative_humidity_2m'] as num).toDouble();
        windSpeed = (current['wind_speed_10m'] as num).toDouble();
        precipitation =
            (current['precipitation'] as num).toDouble();
        weatherCode = (current['weather_code'] as num).toInt();
        isDay = (current['is_day'] as num).toInt() == 1;
        hourlyForecast = nextHours;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'Não consegui acessar a previsão agora. '
            'Confira sua internet e tente novamente.';
      });
    } finally {
      client.close(force: true);
    }
  }

  String get weatherDescription {
    if (weatherCode == 0) return 'CÉU LIMPO';
    if (weatherCode <= 3) return 'PARCIALMENTE NUBLADO';
    if (weatherCode == 45 || weatherCode == 48) return 'NEBLINA';
    if (weatherCode >= 51 && weatherCode <= 57) return 'GAROA';
    if (weatherCode >= 61 && weatherCode <= 67) return 'CHUVA';
    if (weatherCode >= 71 && weatherCode <= 77) return 'NEVE';
    if (weatherCode >= 80 && weatherCode <= 82) return 'PANCADAS';
    if (weatherCode >= 85 && weatherCode <= 86) return 'NEVE';
    if (weatherCode >= 95) return 'TEMPESTADE';
    return 'TEMPO INSTÁVEL';
  }

  String get weatherEmoji {
    if (weatherCode == 0) return isDay ? '☀️' : '🌙';
    if (weatherCode <= 3) return isDay ? '🌤️' : '☁️';
    if (weatherCode == 45 || weatherCode == 48) return '🌫️';
    if (weatherCode >= 51 && weatherCode <= 67) return '🌧️';
    if (weatherCode >= 71 && weatherCode <= 77) return '❄️';
    if (weatherCode >= 80 && weatherCode <= 82) return '🌦️';
    if (weatherCode >= 85 && weatherCode <= 86) return '🌨️';
    if (weatherCode >= 95) return '⛈️';
    return '🌥️';
  }

  String get mascotFace {
    if (weatherCode >= 51 && weatherCode <= 99) return '(>_<)';
    if (temperature <= 15) return '(;_;)';
    if (temperature >= 32) return '(x_x)';
    if (windSpeed >= 30) return '@_@';
    return '(o‿o)';
  }

  String get mascotSpeech {
    if (weatherCode >= 95) {
      return 'EI! TEMPESTADE! PROCURE UM LUGAR SEGURO!';
    }

    if (weatherCode >= 51 && weatherCode <= 82) {
      return 'VAI CHOVER! LEVA O GUARDA-CHUVA, CHEFE!';
    }

    if (temperature <= 15) {
      return 'TÁ FRIO! CADÊ O CASACO, CRIATURA?';
    }

    if (temperature >= 32) {
      return 'TÁ UM FORNO! ÁGUA E PROTETOR SOLAR!';
    }

    if (windSpeed >= 30) {
      return 'O VENTO TÁ FORTE! SEGURA O BONÉ!';
    }

    if (weatherCode == 0 && isDay) {
      return 'SOLZÃO! HOJE O TEMPO TÁ DE BOM HUMOR.';
    }

    return 'PREVISÃO ATUALIZADA. VAMOS VIVER!';
  }

  String get lastUpdated {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: neonGreen,
          backgroundColor: panelColor,
          onRefresh: loadWeather,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _buildHeader(),
              const SizedBox(height: 22),
              _buildWeatherCard(),
              const SizedBox(height: 16),
              _buildMascotCard(),
              const SizedBox(height: 16),
              _buildStats(),
              const SizedBox(height: 22),
              _buildHourlyForecast(),
              const SizedBox(height: 22),
              _buildFooter(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: loading ? null : loadWeather,
        backgroundColor: neonGreen,
        foregroundColor: darkBackground,
        tooltip: 'Atualizar previsão',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: neonGreen.withOpacity(0.12),
            border: Border.all(color: neonGreen, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.wb_twilight,
            color: neonGreen,
            size: 30,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ELIASTEMPO',
                style: TextStyle(
                  color: neonGreen,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'PREVISÃO DO TEMPO // 198X',
                style: TextStyle(
                  color: neonBlue,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: neonGreen),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '● LIVE',
            style: TextStyle(
              color: neonGreen,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF182C4C),
            Color(0xFF10182C),
            Color(0xFF20152F),
          ],
        ),
        border: Border.all(
          color: neonBlue.withOpacity(0.8),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: neonBlue.withOpacity(0.08),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: neonPink, size: 17),
              SizedBox(width: 5),
              Text(
                'LONDRINA, PARANÁ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (loading && errorMessage == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(color: neonGreen),
              ),
            )
          else if (errorMessage != null)
            _buildError()
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${temperature.round()}°',
                        style: const TextStyle(
                          fontSize: 76,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        weatherDescription,
                        style: const TextStyle(
                          color: neonGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sensação ${feelsLike.round()}°',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      weatherEmoji,
                      style: const TextStyle(fontSize: 65),
                    ),
                    const Text(
                      'CLIMA AGORA',
                      style: TextStyle(
                        color: neonBlue,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: neonBlue.withOpacity(0.25)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: neonBlue,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ATUALIZADO ÀS $lastUpdated',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Text(
                  'DADOS REAIS',
                  style: TextStyle(
                    color: neonGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        const Icon(
          Icons.cloud_off,
          size: 48,
          color: neonPink,
        ),
        const SizedBox(height: 12),
        Text(
          errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: loadWeather,
          icon: const Icon(Icons.refresh),
          label: const Text('TENTAR NOVAMENTE'),
        ),
      ],
    );
  }

  Widget _buildMascotCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelColor,
        border: Border.all(
          color: neonPink.withOpacity(0.75),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 95,
            height: 105,
            decoration: BoxDecoration(
              color: const Color(0xFF211735),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'PIXEL BOT',
                  style: TextStyle(
                    color: neonPink,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  mascotFace,
                  style: const TextStyle(
                    color: neonGreen,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  '■ ▪ ■',
                  style: TextStyle(
                    color: neonBlue,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FALA, CHEFE!',
                  style: TextStyle(
                    color: neonPink,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  loading
                      ? 'Tô consultando o clima...'
                      : errorMessage != null
                          ? 'Sem sinal lá fora ou aqui dentro? Tenta de novo!'
                          : mascotSpeech,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '/// CONDIÇÕES ATUAIS',
          style: TextStyle(
            color: neonBlue,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                Icons.water_drop,
                'UMIDADE',
                loading || errorMessage != null
                    ? '--'
                    : '${humidity.round()}%',
                neonBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                Icons.air,
                'VENTO',
                loading || errorMessage != null
                    ? '--'
                    : '${windSpeed.round()} km/h',
                neonGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                Icons.umbrella,
                'PRECIPITAÇÃO',
                loading || errorMessage != null
                    ? '--'
                    : '${precipitation.toStringAsFixed(1)} mm',
                neonPink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                Icons.thermostat,
                'SENSAÇÃO',
                loading || errorMessage != null
                    ? '--'
                    : '${feelsLike.round()}°C',
                const Color(0xFFFFB347),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelColor,
        border: Border.all(color: accent.withOpacity(0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecast() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '/// PRÓXIMAS HORAS',
          style: TextStyle(
            color: neonBlue,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(color: neonGreen),
            ),
          )
        else if (errorMessage != null)
          const Text(
            'Previsão horária indisponível.',
            style: TextStyle(color: Colors.white54),
          )
        else if (hourlyForecast.isEmpty)
          const Text(
            'Não há mais horários disponíveis hoje.',
            style: TextStyle(color: Colors.white54),
          )
        else
          SizedBox(
            height: 125,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hourlyForecast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = hourlyForecast[index];
                final time = DateTime.parse(item['time'] as String);
                final temp = (item['temperature'] as num).round();
                final rain = (item['rain'] as num).round();

                return Container(
                  width: 94,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: panelColor,
                    border: Border.all(
                      color: neonBlue.withOpacity(0.35),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${time.hour.toString().padLeft(2, '0')}:00',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        temp >= 30 ? '☀️' : rain >= 40 ? '🌧️' : '🌤️',
                        style: const TextStyle(fontSize: 23),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '$temp°C',
                        style: const TextStyle(
                          color: neonGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chuva $rain%',
                        style: const TextStyle(
                          color: neonBlue,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: neonGreen.withOpacity(0.3)),
        ),
      ),
      child: const Column(
        children: [
          Text(
            'ELIASTEC // WEATHER SYSTEM',
            style: TextStyle(
              color: neonGreen,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'FEITO COM CAFÉ, PIXELS E PREVISÃO DO TEMPO.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 8,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'DADOS METEOROLÓGICOS: OPEN-METEO',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}
