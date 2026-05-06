import 'package:hive/hive.dart';
part 'models.g.dart';

@HiveType(typeId: 0)
class UserAccountData {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String email;

  UserAccountData({
    required this.id,
    required this.name,
    required this.email
  });

  factory UserAccountData.fromJson(Map<String, dynamic> json) {
    return UserAccountData(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}

@HiveType(typeId: 1)
enum UsageType {
  @HiveField(0)
  playing,    // 유희
  @HiveField(1)
  homework,   // 과제/공부
  @HiveField(2)
  working,    // 업무
  @HiveField(3)
  social,     // 소셜/소통
  @HiveField(4)
  searching,  // 검색
  @HiveField(5)
  etc         // 기타
}

@HiveType(typeId: 2)
class AppUsageData {
  @HiveField(0)
  final String appName;
  @HiveField(1)
  final Map<UsageType, int> usageByType;
  // { 1: 1시간, 2: 30분 }

  AppUsageData({
    required this.appName,
    required this.usageByType,
  });
}

extension AppGoalExtension on UsageType {
  String get displayName {
    switch (this) {
      case UsageType.playing: return "놀이";
      case UsageType.homework: return "과제";
      case UsageType.working: return "업무";
      case UsageType.social: return "연락";
      case UsageType.searching: return "검색";
      default: return "기타";
    }
  }
}