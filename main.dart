import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() => runApp(const EliastectempoApp());

const bg = Color(0xFF101326);
const panel = Color(0xFF202744);
const neon = Color(0xFF72F1B8);
const cream = Color(0xFFFFE8A3);
const pink = Color(0xFFFF79B8);
const blue = Color(0xFF78C9FF);

class EliastectempoApp extends StatelessWidget {
  const EliastectempoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Eliastectempo',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: neon, brightness: Brightness.dark),
      fontFamily: 'monospace',
      useMaterial3: true,
    ),
    home: const WeatherHome(),
  );
}

class WeatherData {
  final double temp, feels, wind;
  final int humidity, code, isDay;
  final DateTime time;
  final List<Map<String, dynamic>> hourly, daily;
  final double uv;
  const WeatherData({required this.temp, required this.feels, required this.wind,
    required this.humidity, required this.code, required this.isDay, required this.time,
    required this.hourly, required this.daily, required this.uv});

  factory WeatherData.fromJson(Map<String, dynamic> j) {
    final c = j['current'] as Map<String, dynamic>;
    final h = j['hourly'] as Map<String, dynamic>;
    final d = j['daily'] as Map<String, dynamic>;
    final now = DateTime.parse(c['time'] as String);
    final ht = List<String>.from(h['time'] as List);
    final temps = List<num>.from(h['temperature_2m'] as List);
    final codes = List<num>.from(h['weather_code'] as List);
    final hs = <Map<String,dynamic>>[];
    for (int i=0; i<ht.length; i++) {
      final dt = DateTime.parse(ht[i]);
      if (!dt.isBefore(now) && hs.length < 8) {
        hs.add({'time':dt, 'temp':temps[i].toDouble(), 'code':codes[i].toInt()});
      }
    }
    final dates = List<String>.from(d['time'] as List);
    final maxes = List<num>.from(d['temperature_2m_max'] as List);
    final mins = List<num>.from(d['temperature_2m_min'] as List);
    final dcodes = List<num>.from(d['weather_code'] as List);
    final uvList = List<num>.from(d['uv_index_max'] as List);
    final ds = <Map<String,dynamic>>[];
    for (int i=0; i<dates.length; i++) {
      ds.add({'date':DateTime.parse(dates[i]), 'max':maxes[i].toDouble(),
        'min':mins[i].toDouble(), 'code':dcodes[i].toInt(), 'uv':uvList[i].toDouble()});
    }
    return WeatherData(
      temp:(c['temperature_2m'] as num).toDouble(),
      feels:(c['apparent_temperature'] as num).toDouble(),
      humidity:(c['relative_humidity_2m'] as num).toInt(),
      wind:(c['wind_speed_10m'] as num).toDouble(),
      code:(c['weather_code'] as num).toInt(),
      isDay:(c['is_day'] as num).toInt(),
      time:now, hourly:hs, daily:ds,
      uv: ds.isNotEmpty ? ds.first['uv'] as double : 0,
    );
  }
}

class WeatherService {
  Future<WeatherData> fetch(double lat, double lon) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude':'$lat','longitude':'$lon',
      'current':'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m',
      'hourly':'temperature_2m,weather_code',
      'daily':'weather_code,temperature_2m_max,temperature_2m_min,uv_index_max',
      'forecast_days':'7','timezone':'auto',
    });
    final r = await http.get(uri).timeout(const Duration(seconds:15));
    if (r.statusCode != 200) throw Exception('O serviço do tempo respondeu ${r.statusCode}.');
    return WeatherData.fromJson(jsonDecode(r.body) as Map<String,dynamic>);
  }
}

class WeatherHome extends StatefulWidget {
  const WeatherHome({super.key});
  @override State<WeatherHome> createState() => _WeatherHomeState();
}
class _WeatherHomeState extends State<WeatherHome> with TickerProviderStateMixin {
  final service = WeatherService();
  late final AnimationController bounce = AnimationController(vsync:this, duration:const Duration(milliseconds:700))..repeat(reverse:true);
  WeatherData? data;
  bool loading = true;
  String place = 'Londrina, PR';
  String? error;
  double lat = -23.3045, lon = -51.1696;

  @override void initState() { super.initState(); load(useLocation:false); }
  @override void dispose() { bounce.dispose(); super.dispose(); }

  Future<void> load({required bool useLocation}) async {
    setState(() { loading=true; error=null; });
    try {
      if (useLocation) {
        if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Ative a localização do aparelho.');
        var p = await Geolocator.checkPermission();
        if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
        if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
          throw Exception('Permissão de localização negada. Mostrando a previsão de Londrina.');
        }
        final pos = await Geolocator.getCurrentPosition();
        lat=pos.latitude; lon=pos.longitude; place='Minha localização';
      }
      final result = await service.fetch(lat,lon);
      if (!mounted) return;
      setState(() { data=result; loading=false; });
    } catch(e) {
      if (!mounted) return;
      setState(() { loading=false; error=e.toString().replaceFirst('Exception: ',''); });
    }
  }

  bool isRain(int c) => [51,53,55,56,57,61,63,65,66,67,80,81,82].contains(c);
  bool isStorm(int c) => [95,96,99].contains(c);
  bool isFog(int c) => [45,48].contains(c);
  bool isSnow(int c) => [71,73,75,77,85,86].contains(c);
  bool isCloud(int c) => [1,2,3].contains(c);

  String condition(int c) {
    if (isStorm(c)) return 'TEMPESTADE';
    if (isRain(c)) return 'CHUVA';
    if (isFog(c)) return 'NEBLINA';
    if (isSnow(c)) return 'NEVE';
    if (c==0) return 'CÉU LIMPO';
    if (isCloud(c)) return 'NUBLADO';
    return 'TEMPO INSTÁVEL';
  }
  IconData iconFor(int c, [int day=1]) {
    if (isStorm(c)) return Icons.thunderstorm;
    if (isRain(c)) return Icons.umbrella;
    if (isFog(c)) return Icons.foggy;
    if (isSnow(c)) return Icons.ac_unit;
    if (c==0) return day==1 ? Icons.wb_sunny : Icons.nightlight_round;
    if (isCloud(c)) return Icons.cloud;
    return Icons.cloud_queue;
  }
  String message(WeatherData w) {
    if (isStorm(w.code)) return 'O céu ativou o modo chefão final. Vai pra um lugar seguro e nada de bancar o herói em área aberta.';
    if (isRain(w.code)) return 'Guarda-chuva, criatura. A nuvem não aceita negociação e seu cabelo não tem seguro.';
    if (isFog(w.code)) return 'Neblina no mapa! Vai com calma no trânsito. Need for Speed fica pra dentro de casa.';
    if (isSnow(w.code)) return 'Tá nevando! Se agasalha bem e não tenta virar pinguim profissional.';
    if (w.temp <= 10) return 'Bota uma blusa, criatura. O look “picolé humano” não favorece ninguém.';
    if (w.temp <= 17) return 'Friozinho detectado. Uma jaqueta não vai deletar seu estilo, prometo.';
    if (w.temp >= 34) return 'Calor nível air fryer. Água, sombra e protetor solar. Sem bancar o lagarto.';
    if (w.temp >= 28) return 'Tá quente! Passa protetor e bebe água. Sua pele não tem botão de desfazer.';
    if (w.wind >= 35) return 'Segura o boné! O vento tá tentando roubar seus pertences e sua dignidade.';
    if (w.uv >= 8) return 'Índice UV muito alto. Protetor, sombra e chapéu: não é hora de virar tomate.';
    if (w.humidity >= 85) return 'Umidade lá em cima. Seu cabelo pode decidir seguir carreira solo hoje.';
    if (w.code==0) return 'Céu limpo! Aproveita, mas passa protetor. O sol não é seu amigo íntimo.';
    if (isCloud(w.code)) return 'Nublado. O sol foi ali resolver uns negócios, aparentemente.';
    return 'Tempo indeciso, igual quem abre a geladeira sem saber o que quer. Confere antes de sair.';
  }

  @override Widget build(BuildContext context) {
    final w=data;
    return Scaffold(
      appBar: AppBar(backgroundColor:bg, title:const Text('ELIASTECTEMPO',style:TextStyle(color:neon,fontWeight:FontWeight.w900,letterSpacing:1.2)),
        actions:[
          IconButton(tooltip:'Atualizar previsão',onPressed:()=>load(useLocation:false),icon:const Icon(Icons.refresh,color:neon)),
          IconButton(tooltip:'Usar minha localização',onPressed:()=>load(useLocation:true),icon:const Icon(Icons.my_location,color:neon)),
        ]),
      body:RefreshIndicator(onRefresh:()=>load(useLocation:false),child:ListView(padding:const EdgeInsets.fromLTRB(16,6,16,28),children:[
        Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:panel,border:Border.all(color:neon,width:2),borderRadius:BorderRadius.circular(6),boxShadow:const [BoxShadow(color:Color(0x3372F1B8),blurRadius:16)]),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(place.toUpperCase(),style:const TextStyle(color:cream,fontWeight:FontWeight.bold,fontSize:12,letterSpacing:1.2)),
            const SizedBox(height:8),
            if (loading) const Center(child:Padding(padding:EdgeInsets.all(25),child:CircularProgressIndicator(color:neon)))
            else if (error!=null) Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Icon(Icons.warning_amber_rounded,color:pink,size:36),const SizedBox(height:8),Text(error!),
              const SizedBox(height:8),FilledButton(onPressed:()=>load(useLocation:false),child:const Text('TENTAR DE NOVO')),
            ]) else if (w!=null) ...[
              Row(children:[
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('${w.temp.round()}°',style:const TextStyle(fontSize:64,height:1,fontWeight:FontWeight.w900)),
                  const SizedBox(height:7),Text(condition(w.code),style:const TextStyle(color:neon,fontWeight:FontWeight.bold,letterSpacing:1.4)),
                  Text('Sensação ${w.feels.round()}°',style:const TextStyle(color:Colors.white70)),
                ])),
                AnimatedBuilder(animation:bounce,builder:(context,child)=>Transform.translate(
                  offset:Offset(0,math.sin(bounce.value*math.pi)*5),
                  child:PixelMascot(code:w.code,temp:w.temp,accent:(isRain(w.code)||isStorm(w.code))?blue:(w.temp<=17?blue:cream)),
                )),
              ]),
              const SizedBox(height:15),
              Container(width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:bg,border:Border.all(color:pink,width:1.5)),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const Text('> RECADO_DO_MASCOTE.exe',style:TextStyle(color:pink,fontWeight:FontWeight.bold,fontSize:11)),
                  const SizedBox(height:7),Text(message(w),style:const TextStyle(fontSize:13,height:1.5)),
                ])),
              const SizedBox(height:13),
              Row(children:[
                Expanded(child:StatTile(icon:Icons.water_drop,label:'UMIDADE',value:'${w.humidity}%')),
                const SizedBox(width:8),Expanded(child:StatTile(icon:Icons.air,label:'VENTO',value:'${w.wind.round()} km/h')),
                const SizedBox(width:8),Expanded(child:StatTile(icon:Icons.wb_sunny,label:'UV MÁX.',value:w.uv.toStringAsFixed(1))),
              ]),
              const SizedBox(height:10),
              Text('ATUALIZADO ${DateFormat('HH:mm').format(w.time)} · OPEN-METEO',style:const TextStyle(color:Colors.white54,fontSize:10)),
            ],
          ]),
        ),
        const SizedBox(height:19),
        const Text('PRÓXIMAS HORAS',style:TextStyle(color:cream,fontWeight:FontWeight.w900,letterSpacing:1.3)),
        const SizedBox(height:9),
        if(w!=null) SizedBox(height:105,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:w.hourly.length,
          separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(context,i){
            final h=w.hourly[i];
            return Container(width:76,padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:panel,border:Border.all(color:const Color(0xFF414B70))),
              child:Column(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
                Text(DateFormat('HH:mm').format(h['time'] as DateTime),style:const TextStyle(fontSize:10,color:Colors.white70)),
                Icon(iconFor(h['code'] as int),color:neon,size:21),
                Text('${(h['temp'] as double).round()}°',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
              ]));
          })),
        const SizedBox(height:20),
        const Text('PRÓXIMOS 7 DIAS',style:TextStyle(color:cream,fontWeight:FontWeight.w900,letterSpacing:1.3)),
        const SizedBox(height:9),
        if(w!=null) ...w.daily.map((d)=>Container(
          margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(horizontal:12,vertical:11),
          decoration:BoxDecoration(color:panel,border:Border.all(color:const Color(0xFF414B70))),
          child:Row(children:[
            SizedBox(width:54,child:Text(DateFormat('EEE', 'pt_BR').format(d['date'] as DateTime).toUpperCase(),style:const TextStyle(color:Colors.white70,fontSize:11))),
            Icon(iconFor(d['code'] as int),color:neon,size:21),
            const Spacer(),
            Text('UV ${(d['uv'] as double).toStringAsFixed(0)}',style:const TextStyle(color:cream,fontSize:11)),
            const SizedBox(width:12),
            Text('${(d['min'] as double).round()}°',style:const TextStyle(color:Colors.white60)),
            const SizedBox(width:9),
            SizedBox(width:31,child:Text('${(d['max'] as double).round()}°',textAlign:TextAlign.end,style:const TextStyle(fontWeight:FontWeight.bold))),
          ]),
        )),
        const SizedBox(height:14),
        const Text('BUILD 0.2 · PIXEL WEATHER SYSTEM',textAlign:TextAlign.center,style:TextStyle(color:Colors.white30,fontSize:10,letterSpacing:1.1)),
      ])),
    );
  }
}

class StatTile extends StatelessWidget {
  final IconData icon; final String label,value;
  const StatTile({super.key,required this.icon,required this.label,required this.value});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:bg,border:Border.all(color:const Color(0xFF414B70))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:neon,size:18),const SizedBox(height:6),
      Text(label,style:const TextStyle(fontSize:8,color:Colors.white60)),const SizedBox(height:3),
      FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(value,style:const TextStyle(fontSize:13,fontWeight:FontWeight.bold))),
    ]));
}

class PixelMascot extends StatelessWidget {
  final int code; final double temp; final Color accent;
  const PixelMascot({super.key,required this.code,required this.temp,required this.accent});
  @override Widget build(BuildContext context)=>SizedBox(width:112,height:126,child:CustomPaint(painter:SpritePainter(code:code,temp:temp,accent:accent),
    child:Center(child:Padding(padding:const EdgeInsets.only(top:24),child:Icon(
      [95,96,99].contains(code)?Icons.bolt:[51,53,55,61,63,65,80,81,82].contains(code)?Icons.umbrella:
      temp<=17?Icons.ac_unit:temp>=28?Icons.wb_sunny:code==0?Icons.sentiment_satisfied_alt:Icons.cloud,
      size:29,color:accent,
    )))));
}
class SpritePainter extends CustomPainter {
  final int code; final double temp; final Color accent;
  SpritePainter({required this.code,required this.temp,required this.accent});
  @override void paint(Canvas canvas,Size size) {
    final p=Paint()..isAntiAlias=false;
    void r(int x,int y,int w,int h,Color c){p.color=c;canvas.drawRect(Rect.fromLTWH(x.toDouble(),y.toDouble(),w.toDouble(),h.toDouble()),p);}
    // Chunky 8-bit sprite: outline, face, cheeks, jacket and shoes.
    r(34,5,44,9,const Color(0xFF080A14)); r(26,14,60,43,const Color(0xFF080A14));
    r(30,17,52,34,const Color(0xFFFFD7A8)); r(23,29,8,12,const Color(0xFFFFD7A8)); r(81,29,8,12,const Color(0xFFFFD7A8));
    r(36,29,8,8,const Color(0xFF101326)); r(63,29,8,8,const Color(0xFF101326));
    r(43,43,20,4,const Color(0xFFB94B6A)); r(30,52,52,37,accent);
    r(22,57,8,23,accent); r(82,57,8,23,accent);
    if(temp<=17){ r(27,51,58,8,blue); r(43,57,23,25,Color(0xFF355B9A)); }
    if(temp>=28){ r(29,15,52,5,cream); r(33,17,8,8,Color(0xFF101326)); r(61,17,8,8,Color(0xFF101326)); }
    if([61,63,65,80,81,82,95,96,99].contains(code)){ r(19,25,7,4,blue); r(87,37,7,4,blue); r(17,43,5,5,blue); r(89,51,5,5,blue); }
    if([95,96,99].contains(code)){ r(14,13,6,12,cream); r(18,20,8,5,cream); }
    r(32,89,17,13,const Color(0xFF080A14)); r(63,89,17,13,const Color(0xFF080A14));
    r(27,100,24,7,const Color(0xFF080A14)); r(60,100,24,7,const Color(0xFF080A14));
    r(20,11,8,4,pink); r(83,11,8,4,neon);
  }
  @override bool shouldRepaint(covariant SpritePainter old)=>old.code!=code||old.temp!=temp||old.accent!=accent;
}
