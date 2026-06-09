// homepage.dart start
import 'dart:async';

import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../services/app_detection_service.dart';
import '../services/util_service.dart';
import './shared_imports.dart';


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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isRefreshing) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final wastedSecs = _wastedTime ?? 0;
    final wastedMoney = Util.calculateWastedMoney(wastedSecs);
    final mins = wastedSecs ~/ 60;
    final secs = wastedSecs % 60;
    final timeStr = mins > 0 ? '$mins분 $secs초' : '$secs초';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
        elevation: 0,
        title: Text('ZenTime',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3,
              color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
            )),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          // ── 인사 + 통계 카드 ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('안녕하세요, ${_account?.name ?? '사용자'}님 👋',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFE8E8E8) : const Color(0xFF111111),
                  )),
              const SizedBox(height: 12),
              Row(children: [
                _statChip('오늘 낭비', timeStr, isDark),
                const SizedBox(width: 8),
                _statChip('금전 낭비', '₩$wastedMoney', isDark),
              ]),
            ]),
          ),
          const SizedBox(height: 12),

          // ── ZenTime 토글 ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0)),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isServiceRunning ? Icons.self_improvement : Icons.bedtime_outlined,
                  size: 18,
                  color: isDark ? const Color(0xFF888888) : const Color(0xFF555555),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ZenTime',
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE8E8E8) : const Color(0xFF111111),
                      )),
                  Text(isServiceRunning ? '추적 중' : '일시 정지됨',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF777777) : const Color(0xFF888888),
                      )),
                ]),
              ),
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
                activeColor: isDark ? const Color(0xFFE8E8E8) : const Color(0xFF111111),
                activeTrackColor: isDark
                    ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
              ),
            ]),
          ),
          const SizedBox(height: 22),

          // ── DEV TOOLS ──
          ...[
            Text('DEV TOOLS',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2,
                  color: isDark ? const Color(0xFF555555) : const Color(0xFFAAAAAA),
                )),
            const SizedBox(height: 8),
            Row(children: [
              _devButton('DB 새로고침', Icons.refresh, isDark, onTap: () async {
                setState(() { _isRefreshing = true; });
                await _loadDataFromDatabase();
                setState(() { _isRefreshing = false; });
                if (mounted) ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('로컬 로드 완료')));
              }),
              const SizedBox(width: 8),
              _devButton('DB 정리', Icons.delete_sweep_outlined, isDark, onTap: () async {
                setState(() { _isRefreshing = true; });
                await DatabaseService.rawLogToUsageData();
                await _loadDataFromDatabase();
                setState(() { _isRefreshing = false; });
                if (mounted) ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('로그 정제 완료')));
              }),
            ]),
            const SizedBox(height: 22),
          ],

          // ── 최신 로그 ──
          Text('최신 로그',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2,
                color: isDark ? const Color(0xFF555555) : const Color(0xFFAAAAAA),
              )),
          const SizedBox(height: 10),
          _logs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('적치된 로그가 없습니다.',
                        style: TextStyle(
                            color: isDark
                                ? const Color(0xFF444444)
                                : const Color(0xFFBBBBBB))),
                  ))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isEnter = log.logType == LogType.enter;
                    final borderColor = isEnter
                        ? const Color(0xFF32B464)
                        : const Color(0xFFDC3C3C);
                    final iconBg = isEnter
                        ? const Color(0xFF32B464).withOpacity(0.12)
                        : const Color(0xFFDC3C3C).withOpacity(0.12);

                    final tagColors = {
                      '놀이': isEnter ? const Color(0xFF32B464) : const Color(0xFFDC3C3C),
                      '공부': const Color(0xFF32B464),
                    };
                    final tagColor = tagColors[log.usageType.displayName]
                        ?? (isDark ? const Color(0xFF666666) : const Color(0xFF999999));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
                      ),
                      child: Row(children: [
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            isEnter ? Icons.login_rounded : Icons.logout_rounded,
                            size: 14,
                            color: borderColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(log.appName.split('.').last,
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFE8E8E8)
                                      : const Color(0xFF111111),
                                )),
                            Text(log.dateTime.toString().substring(11, 19),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF444444)
                                      : const Color(0xFFBBBBBB),
                                )),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: tagColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(log.usageType.displayName,
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: tagColor)),
                        ),
                      ]),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF666666) : const Color(0xFF999999),
              )),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
              )),
        ]),
      ),
    );
  }

  Widget _devButton(String label, IconData icon, bool isDark,
      {required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14,
                color: isDark ? const Color(0xFF555555) : const Color(0xFFAAAAAA)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF888888) : const Color(0xFF777777),
                )),
          ]),
        ),
      ),
    );
  }
}

// homepage.dart end