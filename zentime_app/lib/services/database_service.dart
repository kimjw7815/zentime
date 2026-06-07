// database_service.dart start
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart'; // 하나로 합친 모델 파일

class DatabaseService {
  static const String userBoxName = 'userBox';
  static const String usageBoxName = 'usageBox';
  static const String rawLogBoxName = 'rawLogBox';

  static bool _isInitialized=false;

  // 1. 초기화 및 어댑터 등록
  static Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    
    // 어댑터들 등록 (생성된 .g.dart 파일 내 클래스명 확인)
    if (!Hive.isAdapterRegistered(UserAccountDataAdapter().typeId)) {
      Hive.registerAdapter(UserAccountDataAdapter());
    }
    if (!Hive.isAdapterRegistered(UsageTypeAdapter().typeId)) {
      Hive.registerAdapter(UsageTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(AppUsageDataAdapter().typeId)) {
      Hive.registerAdapter(AppUsageDataAdapter());
    }
    if (!Hive.isAdapterRegistered(LogTypeAdapter().typeId)) {
      Hive.registerAdapter(LogTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(RawLogAdapter().typeId)) {
      Hive.registerAdapter(RawLogAdapter());
    }

    _isInitialized=true;
    print('[main isolate] or [overlay isolate] 박스열엇음');
  }

  // 2. 가짜 데이터 주입 (테스트용)
  static Future<void> seedMockData() async {
    final userBox = await Hive.openBox<UserAccountData>(userBoxName);
    final usageBox = await Hive.openBox<List<dynamic>>(usageBoxName);

    try {
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
    } finally {
      await userBox.close();
      await usageBox.close();
    }

  }

  static Future<void> reset() async {
    final userBox = await Hive.openBox<UserAccountData>(userBoxName);
    final usageBox = await Hive.openBox<List<dynamic>>(usageBoxName);
    final rawLogBox = await Hive.openBox<RawLog>(rawLogBoxName);
    try {
      await userBox.clear();
      await usageBox.clear();
      await rawLogBox.clear();
      print("Database reset complete.");
    } catch (e) {
      print("Reset failed: $e");
    } finally {
      await userBox.close();
      await usageBox.close();
      await rawLogBox.close();
    }
  }

  static Future<void> lake(
    DateTime dateTime, String appName, LogType logType, UsageType usageType
  ) async {
    final rawLogBox = await Hive.openBox<RawLog>(rawLogBoxName);
    try {
      await rawLogBox.add(RawLog(
        dateTime: dateTime,
        appName: appName,
        logType: logType,
        usageType: usageType
      ));
      print("🌊 [foreground isolate] lake: $appName | $logType | $usageType");

    } finally {
      await rawLogBox.close();
    }
  }

  static Future<void> updateLastEnterLog(UsageType usageType) async {
    // 오버레이 앱 단계에서 업데이트 하기 전에 하이브를 새로 열어야된대...
    final rawLogBox = await Hive.openBox<RawLog>(rawLogBoxName);
    try {
      if (rawLogBox.isEmpty) {
        print("[foreground isolate] 뭔가 이상함 박스가 비어있음");
        return;
      }
      int targetIndex = -1;
      for (int i = rawLogBox.length - 1; i >= 0; i--) {
        final log = rawLogBox.getAt(i);
        if (log != null && log.logType == LogType.enter) {
          targetIndex = i;
          break; // 가장 최신 enter 로그를 찾았으므로 탈출!
        }
      }
      if (targetIndex == -1) {
        print("❌ [foreground isolate]]B 업데이트 오류: 업데이트할 대상을 찾지 못했습니다. (LogType.enter 가 없음)");
        return;
      }
      final RawLog lastEnterLog = rawLogBox.getAt(targetIndex)!;
      final updateLog=RawLog(
        dateTime: lastEnterLog.dateTime,
        appName: lastEnterLog.appName,
        logType: lastEnterLog.logType,
        usageType: usageType,
      );
      await rawLogBox.putAt(targetIndex, updateLog);
      print("[foreground isolate] 버튼 눌려서 목적수정 됐음요");
      print("[foreground isolate] usageType이 ${lastEnterLog.usageType}에서 ${updateLog.usageType}으로 바뀜");
    } finally {
      await rawLogBox.close();
    }
  }

  static rawLogToUsageData() async {
    final rawLogBox = await Hive.openBox<RawLog>(rawLogBoxName);
    final usageBox = await Hive.openBox<List<dynamic>>(usageBoxName);
    try {

      if (rawLogBox.isEmpty) return;

      final Map<String, Map<String, Map<UsageType, int>>> temporaryData = {};

      final logs=rawLogBox.values.toList();
      for (int i=0;i<logs.length-1;i++) {
        RawLog rawLog=logs[i];
        if (rawLog.logType==LogType.leave) continue;
        else if (rawLog.logType==LogType.enter && logs[i+1].logType!=LogType.leave) continue;
        else if (rawLog.logType==LogType.enter && logs[i+1].logType==LogType.leave) {
          final logDay=rawLog.dateTime;
          final logDayDateKey="${logDay.year}-${logDay.month}-${logDay.day}";
          final int usageMicros = logs[i+1].dateTime.difference(rawLog.dateTime).inMicroseconds;
          temporaryData.putIfAbsent(logDayDateKey, () => {});
          temporaryData[logDayDateKey]!.putIfAbsent(rawLog.appName, () => {});
          final currentUsageType = rawLog.usageType;
          final previousDuration = temporaryData[logDayDateKey]![rawLog.appName]![currentUsageType] ?? 0;

          temporaryData[logDayDateKey]![rawLog.appName]![currentUsageType] = previousDuration + usageMicros;
        }
      }
      for (final dateEntry in temporaryData.entries) {
        final String dateKey = dateEntry.key;
        final Map<String, Map<UsageType, int>> appsMap = dateEntry.value;

        // 해당 날짜에 포함될 AppUsageData 리스트 생성
        final List<AppUsageData> dailyList = appsMap.entries.map((appEntry) {
          return AppUsageData(
            appName: appEntry.key,
            usageByType: appEntry.value, // { UsageType.etc: 12345, ... }
          );
        }).toList();

        // Hive에 최종 저장
        await usageBox.put(dateKey, dailyList);
      }
    } finally {
      await rawLogBox.close();
      await usageBox.close();
    }
  }

  static Future<void> getWastedTime() async {
    
  }
}

// database_service.dart end