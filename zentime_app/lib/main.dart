// main.dart. start
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:zentime/models/models.dart';
import 'services/database_service.dart';
import 'services/app_detection_service.dart';

import 'package:zentime/framepage.dart';
import 'package:zentime/apps/slidingwidget.dart';

@pragma("vm:entry-point")
void overlayMain() async {
  print("[overlay isolate] 엔트리포인트 호출");
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.init();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent, 
        body: SlidingWidget(),
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await DatabaseService.init();

  // 필요 시 주석 해제하여 테스트
  // await DatabaseService.reset(); 
  // await DatabaseService.seedMockData();

  runApp(const ZenTimeApp());
}

class ZenTimeApp extends StatefulWidget {
  const ZenTimeApp({super.key});

  @override State<ZenTimeApp> createState() => _ZenTimeAppState();
}

class _ZenTimeAppState extends State<ZenTimeApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true; // DB에서 테마 읽어올 때까지 빌드 방지 플래그

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
  }

  // 💡 모델 참조: profile의 Getter인 themeMode를 호출하여 안전하게 초기 세팅 후 닫음
  Future<void> _loadSavedTheme() async {
    final userBox = await Hive.openBox<UserAccountData>(DatabaseService.userBoxName);
    try {
      final profile = userBox.get('profile');
      setState(() {
        // 모델 내부의 getter 안전하게 작동
        _themeMode = profile?.themeMode ?? ThemeMode.system;
        _isLoading = false;
      });
    } finally {
      await userBox.close();
    }
  }
  
  // 💡 모델 참조: final 구조에 맞게 복사 생성(Re-instantiation) 방식으로 테마 교체
  void _toggleTheme() async {
    ThemeMode nextMode;
    
    if (_themeMode == ThemeMode.system) {
      final brightness = View.of(context).platformDispatcher.platformBrightness;
      nextMode = (brightness == Brightness.dark) ? ThemeMode.light : ThemeMode.dark;
    } else {
      nextMode = (_themeMode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
    }

    setState(() {
      _themeMode = nextMode;
    });

    final userBox = await Hive.openBox<UserAccountData>(DatabaseService.userBoxName);
    try {
      final profile = userBox.get('profile');
      
      if (profile != null) {
        // 💡 중요: final 필드이므로 기존 데이터를 기반으로 themeModeIndex만 새로 넣어 인스턴스 생성
        final updatedProfile = UserAccountData(
          id: profile.id,
          name: profile.name,
          email: profile.email,
          themeModeIndex: nextMode.index, // Enum 값을 int index로 변환하여 매핑
        );
        await userBox.put('profile', updatedProfile);
      } else {
        // 혹시 모를 Null 에러 방지용 기본 프로필 생성 대피소
        final defaultProfile = UserAccountData(
          id: 'user_default',
          name: '사용자',
          email: 'user@zentime.com',
          themeModeIndex: nextMode.index,
        );
        await userBox.put('profile', defaultProfile);
      }
    } finally {
      await userBox.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        print("미니마이즈앱");
        FlutterForegroundTask.minimizeApp();
      },
      child: MaterialApp(
        title: 'ZenTime',
        themeMode: _themeMode,
        theme: ThemeData(
          brightness: Brightness.light,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        ),
        home: FramePage(toggleTheme: () => _toggleTheme()),
      ),
    );
  }
}
// main.dart end