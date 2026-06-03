// database_service.dart start
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart'; // 하나로 합친 모델 파일

class DatabaseService {
  static const String userBoxName = 'userBox';
  static const String usageBoxName = 'usageBox';
  static const String rawLogBoxName = 'rawLogBox';

  static bool _isInitialized=false;

  static Future<Box<UserAccountData>> _getOpenUserBox() async {
    return Hive.isBoxOpen(userBoxName)
      ? Hive.box<UserAccountData>(userBoxName)
      : await Hive.openBox<UserAccountData>(userBoxName);
  }

  static Future<Box<List<dynamic>>> _getOpenUsageBox() async {
    return Hive.isBoxOpen(usageBoxName)
        ? Hive.box<List<dynamic>>(usageBoxName)
        : await Hive.openBox<List<dynamic>>(usageBoxName);
  }

  static Future<Box<RawLog>> _getOpenRawLogBox() async {
    return Hive.isBoxOpen(rawLogBoxName)
        ? Hive.box<RawLog>(rawLogBoxName)
        : await Hive.openBox<RawLog>(rawLogBoxName);
  }

  // 1. 초기화 및 어댑터 등록
  static Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    
    // 어댑터들 등록 (생성된 .g.dart 파일 내 클래스명 확인)
    Hive.registerAdapter(UserAccountDataAdapter());
    Hive.registerAdapter(UsageTypeAdapter());
    Hive.registerAdapter(AppUsageDataAdapter());
    Hive.registerAdapter(LogTypeAdapter());
    Hive.registerAdapter(RawLogAdapter());

    // 박스 미리 열어두기
    await _getOpenUserBox();
    await _getOpenUsageBox();
    await _getOpenRawLogBox();
    _isInitialized=true;
    print('박스열엇음');
  }

  // 2. 가짜 데이터 주입 (테스트용)
  static Future<void> seedMockData() async {
    var userBox = await _getOpenUserBox();
    var usageBox = await _getOpenUsageBox();

    if (userBox.isEmpty) {
      await userBox.put('profile', UserAccountData(
        id: 'user_123',
        name: '디톡스 장인',
        email: 'test@zentime.com',
        themeModeIndex: 2,
      ));
    }

    if (usageBox.isEmpty) {
      final today=DateTime.now();
      final todayDateKey="${today.year}-${today.month}-${today.day}";
      await usageBox.put(todayDateKey, [
        AppUsageData(
          appName: 'Youtube',
          usageByType: {
            UsageType.etc: Duration(hours: 2).inMicroseconds,
            UsageType.homework: Duration(hours: 3).inMicroseconds
          },
        ),
        AppUsageData(
          appName: 'Instagram',
          usageByType: {
            UsageType.playing: Duration(hours: 1).inMicroseconds,
            UsageType.searching: Duration(hours: 2).inMicroseconds
          }
        ),
      ]);

      final yesterday=DateTime.now().subtract(Duration(days: 1));
      final yesterdayDateKey="${yesterday.year}-${yesterday.month}-${yesterday.day}";
      await usageBox.put(yesterdayDateKey, [
        AppUsageData(
          appName: 'Github',
          usageByType: {
            UsageType.social: Duration(hours: 4).inMicroseconds,
            UsageType.working: Duration(hours: 5).inMicroseconds
          }
        ),
        AppUsageData(
          appName: 'Youtube',
          usageByType: {
            UsageType.playing: Duration(minutes: 30).inMicroseconds,
          }
        ),
      ]);

      // AppUsageData box엔 3개의 데이터 date:AppUsageData
    }
  }

  static Future<void> reset() async {
    try {
      // 박스가 열려 있는지 확인하고 가져오기
      final userBox = await _getOpenUserBox();
      final usageBox = await _getOpenUsageBox();
      final rawLogBox = await _getOpenRawLogBox();

      // 반드시 await를 붙여서 작업 완료를 기다려야 함
      await userBox.clear();
      await usageBox.clear();
      await rawLogBox.clear();
      
      print("Database reset complete.");
    } catch (e) {
      print("Reset failed: $e");
    }
  }

  static Future<void> lake(
    DateTime dateTime, String appName, LogType logType, UsageType usageType
  ) async {
    var rawLogBox = await _getOpenRawLogBox();
    await rawLogBox.add(RawLog(
      dateTime: dateTime,
      appName: appName,
      logType: logType,
      usageType: usageType
    ));
    print("🌊 [데이터 레이크] 로그 적치 완료: $appName | $logType | $usageType");
  }

  static Future<void> updateLastLog(UsageType usageType) async {
    // 오버레이 앱 단계에서 업데이트 하기 전에 하이브를 새로 열어야된대...
    if (Hive.isBoxOpen(rawLogBoxName)) {
      await Hive.box<RawLog>(rawLogBoxName).close();
    }
    var rawLogBox = await Hive.openBox<RawLog>(rawLogBoxName);

    if (rawLogBox.isEmpty) {
      print("뭔가 이상함 박스가 비어있음");
      return;
    }
    final int lastIndex=rawLogBox.length-1;
    final RawLog? lastLog=rawLogBox.getAt(lastIndex);
    if (lastLog==null) {
      print("뭔가 이상함 최신 로그가 null임");
      return;
    }
    final updateLog=RawLog(
      dateTime: lastLog.dateTime,
      appName: lastLog.appName,
      logType: lastLog.logType,
      usageType: usageType,
    );
    await rawLogBox.putAt(lastIndex, updateLog);
    print("버튼 눌려서 목적수정 됐음요");
    print("usageType이 ${lastLog.usageType}에서 ${updateLog.usageType}으로 바뀜");
  }
}

// database_service.dart end