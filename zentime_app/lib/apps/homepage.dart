import 'dart:convert';
import 'dart:math';
import './shared_imports.dart';
import '../services/app_detection_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:async';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zentime/models/models.dart';
import '../services/database_service.dart';

Future<bool> checkAndRequestPermissions() async {
  // 오버레이 권한 체크
  bool isOverlayGranted = await FlutterOverlayWindow.isPermissionGranted();
  if (!isOverlayGranted) {
    print("❌ 오버레이 권한 없음 -> 설정창으로 이동");
    await FlutterOverlayWindow.requestPermission();
    return false;
  }

  // 접근성 권한 체크
  bool isAccessibilityEnabled = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
  if (!isAccessibilityEnabled) {
    print("❌ 접근성 권한 없음 -> 설정창으로 이동");
    await FlutterAccessibilityService.requestAccessibilityPermission();
    return false;
  }

  // 알림 권한 체크
  NotificationPermission notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission == NotificationPermission.denied) {
    print("❌ 알림 권한 없음 -> 권한 요청 팝업");
    await FlutterForegroundTask.requestNotificationPermission();
    return false;
  }

  return true; // 모든 권한 허용됨
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isRefreshing = false;
  bool isServiceRunning = false;
  final AppDetectionService _detectionService = AppDetectionService();

  // 💡 실시간 스트림 대신 화면 갱신 시점에만 안전하게 데이터를 담아둘 상태 변수들
  UserAccountData? _account;
  List<RawLog> _logs = [];
  DateTime? _lastSyncTime; // 서버 연동 10분 제한용 타임스탬프

  @override
  void initState() {
    super.initState();
    print("initState 호출됨요!!");
    _initData();
  }

  // 💡 초기 진입 시 데이터 통합 정제 및 로드
  Future<void> _initData() async {
    setState(() {
      _isRefreshing = true;
    });

    // 1. 밀린 로그 정제 로직 실행 (내부에서 열고 닫음)
    await DatabaseService.rawLogToUsageData();

    // 2. 화면용 데이터 가져오기
    await _loadDataFromDatabase();

    // 3. 서비스 동작 상태 확인
    bool isServiceRunningTemp = await FlutterForegroundTask.isRunningService;
    print("isServiceRunningTemp 받았음요: $isServiceRunningTemp");

    setState(() {
      isServiceRunning = isServiceRunningTemp;
      _isRefreshing = false;
    });
  }

  // 💡 박스를 안전하게 한 번 열어서 변수에 데이터를 복사한 후 즉시 닫는 핵심 로직
  Future<void> _loadDataFromDatabase() async {
    final userBox = await Hive.openBox<UserAccountData>(DatabaseService.userBoxName);
    final logBox = await Hive.openBox<RawLog>(DatabaseService.rawLogBoxName);

    try {
      _account = userBox.get('profile');
      _logs = logBox.values.toList().reversed.toList();
    } finally {
      // 컴포넌트 렌더링 시 락 걸리지 않게 무조건 닫기 보장
      await userBox.close();
      await logBox.close();
    }
  }

  // 💡 가짜 파일 대신 Hive의 진짜 데이터를 JSON으로 파싱해서 서버에 동기화하는 로직
  Future<void> _sendDataWithCooldown() async {
    final now = DateTime.now();
    
    // 1. 10분 쿨타임 체크 (메모장 요구사항 반영)
    if (_lastSyncTime != null) {
      final difference = now.difference(_lastSyncTime!).inMinutes;
      if (difference < 10) {
        final remaining = 10 - difference;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ 과도한 동기화 방지! $remaining분 후에 다시 시도할 수 있습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() { _isRefreshing = true; });

    // 2. Hive 박스 안전하게 열기
    final userBox = await Hive.openBox<UserAccountData>(DatabaseService.userBoxName);
    final usageBox = await Hive.openBox<List<dynamic>>(DatabaseService.usageBoxName);

    try {
      final profile = userBox.get('profile');
      if (profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ 전송 실패: 유저 프로필 데이터가 없습니다.'), backgroundColor: Colors.red),
        );
        return;
      }

      // 3. usageBox에 쌓인 로컬 정제 데이터를 백엔드 schemas.SyncData 구조에 맞게 변환
      List<Map<String, dynamic>> usageListJson = [];
      
      for (var key in usageBox.keys) {
        final rawList = usageBox.get(key);
        if (rawList != null) {
          for (var item in rawList) {
            if (item is AppUsageData) {
              // 백엔드의 u.usage_data.get(usage_type, 0) 구조 분석 결과:
              // Enum key들을 문자열 인덱스숫자("0", "1" 등)로 매핑해주어야 백엔드가 정상 합산함
              Map<String, int> formattedUsageByType = {};
              item.usageByType.forEach((type, value) {
                formattedUsageByType[type.index.toString()] = value;
              });

              usageListJson.add({
                'appName': item.appName,
                'usageByType': formattedUsageByType,
              });
            }
          }
        }
      }

      // 4. 최종 전송용 통짜 JSON 구조 바디 조립
      final Map<String, dynamic> syncPayload = {
        'userId': profile.id,
        'name': profile.name,
        'email': profile.email,
        'themeModeIndex': profile.themeModeIndex,
        'usageList': usageListJson,
      };

      // 5. 서버 통신 엔드포인트 타격 (`/sync-usage`)
      final String serverIp = "146.56.175.74"; 
      final url = Uri.parse('http://$serverIp:8000/sync-usage');

      print("🚀 [서버 동기화] 진짜 데이터 전송 시작...");
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(syncPayload), // 구조화된 JSON 데이터 주입
      );

      if (response.statusCode == 200) {
        print("🟢 전송 성공: ${response.body}");
        _lastSyncTime = DateTime.now(); // 쿨타임 타임스탬프 기록
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🟢 서버 데이터베이스 동기화 완료!'), backgroundColor: Colors.green),
        );
      } else {
        print("❌ 전송 실패 (상태코드): ${response.statusCode} | 바디: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 동기화 실패 (코드: ${response.statusCode})'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("❌ 전송 중 예외 에러 발생: $e");
    } finally {
      // 6. 자원 반환 및 UI 락 해제
      await userBox.close();
      await usageBox.close();
      setState(() { _isRefreshing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRefreshing) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ZenTime Dashboard')),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text('환영합니다, ${_account?.name ?? '사용자'}님!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _sendDataWithCooldown, 
              child: const Text('서버 데이터베이스 연결 (10분 제한)', style: TextStyle(color: Colors.purple, fontSize: 16))
            ),
            const SizedBox(height: 20),
            const Text('zentime을 원하는대로 On/Off 하세요!'),
            Switch(
              value: isServiceRunning,
              onChanged: (value) async {
                if (value) {
                  bool hasPermission = await checkAndRequestPermissions();
                  if (hasPermission) {
                    _detectionService.startAppDetection();
                    setState(() { isServiceRunning = true; });
                  } else {
                    setState(() { isServiceRunning = false; }); 
                  }
                } else {
                  _detectionService.stopAppDetection();
                  setState(() { isServiceRunning = false; });
                }
              },
              activeColor: Colors.blue,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    setState(() { _isRefreshing = true; });
                    print("db 새로고침중");
                    await _loadDataFromDatabase();
                    print("db 새로고침 완료");
                    setState(() { _isRefreshing = false; });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로컬 로드 완료')));
                  },
                  child: const Text("db 새로고침")
                ),
                const SizedBox(width: 15),
                ElevatedButton(
                  onPressed: () async {
                    setState(() { _isRefreshing = true; });
                    print("db 정리하기");
                    await DatabaseService.rawLogToUsageData();
                    await _loadDataFromDatabase();
                    print("db 정리 완료");
                    setState(() { _isRefreshing = false; });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그 정제 완료 완료')));
                  },
                  child: const Text("db 정리")
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('📋 적치된 최신 로그 내역 (테스트용)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // 💡 락 충돌 우려가 완전히 사라졌으므로 기존 주석을 풀어 안심하고 화면에 로그를 띄워줍니다.
            Expanded(
              child: _logs.isEmpty
                  ? const Center(child: Text('적치된 로그가 없습니다.'))
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                          child: ListTile(
                            leading: Icon(log.logType == LogType.enter ? Icons.login : Icons.logout, color: log.logType == LogType.enter ? Colors.green : Colors.red),
                            title: Text(log.appName.split('.').last), // 가독성을 위해 패키지명 끝자리만 파싱
                            subtitle: Text(log.dateTime.toString().substring(11, 19)), // 시간 정보만 크롭
                            trailing: Text(log.usageType.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}