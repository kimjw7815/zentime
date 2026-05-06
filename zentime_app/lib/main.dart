import 'package:flutter/material.dart';
import 'package:zentime/framepage.dart';
import 'package:zentime/apps/settingpage.dart';

void main() {
  runApp(const ZenTimeApp());
}

class ZenTimeApp extends StatefulWidget {
  const ZenTimeApp({super.key});

  @override
  State<ZenTimeApp> createState() => _ZenTimeAppState();
}

class _ZenTimeAppState extends State<ZenTimeApp> {
  ThemeMode _themeMode = ThemeMode.system;
  
  void _toggleTheme() {
    setState(() {
      // 현재 테마가 system이면, 실제 기기의 브라이트니스를 가져와서 반대로 바꿈
      if (_themeMode == ThemeMode.system) {
        final brightness = View.of(context).platformDispatcher.platformBrightness;
        _themeMode = (brightness == Brightness.dark) ? ThemeMode.light : ThemeMode.dark;
      } else {
        // 이미 system이 아니라면 단순 토글
        _themeMode = (_themeMode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: .fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: .fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => FramePage(toggleTheme: () => _toggleTheme()),
        '/settings': (context) => SettingPage()
      }
    );
  }

}
