import 'package:flutter/material.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:zentime/models/models.dart';
import 'services/database_service.dart';

import 'package:zentime/framepage.dart';
import 'package:zentime/apps/homepage.dart';
import 'package:zentime/apps/detailpage.dart';
import 'package:zentime/apps/rankingpage.dart';
import 'package:zentime/apps/settingpage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await DatabaseService.init();

  await DatabaseService.reset(); 

  await DatabaseService.seedMockData();

  runApp(const ZenTimeApp());
}

class ZenTimeApp extends StatefulWidget {
  const ZenTimeApp({super.key});

  @override
  State<ZenTimeApp> createState() => _ZenTimeAppState();
}

class _ZenTimeAppState extends State<ZenTimeApp> {
  ThemeMode? _themeMode;
  
  void _toggleTheme() {
    setState(() {
      // 현재 테마가 system이면, 실제 기기의 브라이트니스를 가져와서 반대로 바꿈
      final userBox = Hive.box<UserAccountData>('userBox');
      final currentMode = _themeMode ?? userBox.get('profile')?.themeMode ?? ThemeMode.system;

      if (currentMode == ThemeMode.system) {
        final brightness = View.of(context).platformDispatcher.platformBrightness;
        _themeMode = (brightness == Brightness.dark) ? ThemeMode.light : ThemeMode.dark;
      } else {
        _themeMode = (currentMode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userBox = Hive.box<UserAccountData>('userBox');
    final savedTheme = userBox.get('profile')?.themeMode ?? ThemeMode.system;
    return MaterialApp(
      title: 'Flutter Demo',
      themeMode: _themeMode ?? savedTheme,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => FramePage(toggleTheme: () => _toggleTheme(),),
        '/home': (context) => HomePage(),
        '/detail': (context) => DetailPage(),
        '/ranking': (context) => RankingPage(),
        '/settings': (context) => SettingPage(toggleTheme: () => _toggleTheme(),),
      }
    );
  }

}
