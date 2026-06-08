// homepage.dart start
import './shared_imports.dart';
import '../services/app_detection_service.dart';
import '../services/util_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:async';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';


Future<bool> checkAndRequestPermissions() async {
  // 오버레이 권한 체크
  bool isOverlayGranted = await FlutterOverlayWindow.isPermissionGranted();
  if (!isOverlayGranted) {
    print("❌ [main isolate] 오버레이 권한 없음 -> 설정창으로 이동");
    await FlutterOverlayWindow.requestPermission();
    return false;
  }

  // 접근성 권한 체크
  bool isAccessibilityEnabled = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
  if (!isAccessibilityEnabled) {
    print("❌ [main isolate] 접근성 권한 없음 -> 설정창으로 이동");
    await FlutterAccessibilityService.requestAccessibilityPermission();
    return false;
  }

  // 알림 권한 체크
  NotificationPermission notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission == NotificationPermission.denied) {
    print("❌ [main isolate] 알림 권한 없음 -> 권한 요청 팝업");
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
  int? _wastedTime;
  List<RawLog> _logs = [];

  @override
  void initState() {
    super.initState();
    print("[main isolate] initState 호출됨요!!");
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
    print("[main isolate] isServiceRunningTemp 받았음요: $isServiceRunningTemp");

    setState(() {
      isServiceRunning = isServiceRunningTemp;
      _isRefreshing = false;
    });
  }

  // 💡 박스를 안전하게 한 번 열어서 변수에 데이터를 복사한 후 즉시 닫는 핵심 로직
  Future<void> _loadDataFromDatabase() async {
    int tempWastedTime=await DatabaseService.getWastedTimeByDate(DateTime.now());
    _wastedTime=Duration(seconds: tempWastedTime).inSeconds;
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
            Text('오늘은 ${Util.formatDuration(_wastedTime ?? 0)}만큼 시간을 낭비하셨어요!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${Util.calculateWastedMoney(_wastedTime ?? 0)}원 만큼 돈을 낭비하셨네요!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
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

// homepage.dart end