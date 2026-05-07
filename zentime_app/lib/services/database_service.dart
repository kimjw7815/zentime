import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart'; // 하나로 합친 모델 파일

class DatabaseService {
  static const String userBoxName = 'userBox';
  static const String usageBoxName = 'usageBox';

  // 1. 초기화 및 어댑터 등록
  static Future<void> init() async {
    await Hive.initFlutter();
    
    // 어댑터들 등록 (생성된 .g.dart 파일 내 클래스명 확인)
    Hive.registerAdapter(UserAccountDataAdapter());
    Hive.registerAdapter(UsageTypeAdapter());
    Hive.registerAdapter(AppUsageDataAdapter());

    // 박스 미리 열어두기
    await Hive.openBox<UserAccountData>(userBoxName);
    await Hive.openBox<List<dynamic>>(usageBoxName);
  }

  // 2. 가짜 데이터 주입 (테스트용)
  static Future<void> seedMockData() async {
    var userBox = Hive.box<UserAccountData>(userBoxName);
    var usageBox = Hive.box<List<dynamic>>(usageBoxName);

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
      final userBox = Hive.isBoxOpen(userBoxName) 
          ? Hive.box<UserAccountData>(userBoxName) 
          : await Hive.openBox<UserAccountData>(userBoxName);
          
      final usageBox = Hive.isBoxOpen(usageBoxName) 
          ? Hive.box<List<dynamic>>(usageBoxName) 
          : await Hive.openBox<List<dynamic>>(usageBoxName);

      // 반드시 await를 붙여서 작업 완료를 기다려야 함
      await userBox.clear();
      await usageBox.clear();
      
      print("Database reset complete.");
    } catch (e) {
      print("Reset failed: $e");
    }
  }
}