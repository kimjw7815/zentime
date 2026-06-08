// app_detection_service.dart start
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import '../apps/shared_imports.dart';

import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SecureDetectionHandler());
}

// 💡 2. 절대 JNI가 끊어지지 않는 포그라운드 태스크 핸들러
class SecureDetectionHandler extends TaskHandler {
  StreamSubscription<AccessibilityEvent>? _sub;
  String? lastPackage;
  bool _isBlocking = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print("🚀 [foreground isolate] 백그라운드 감시 리스너 가동");
    await DatabaseService.init(); // 별도 isolate이므로 Hive 재초기화 필수
    AppDetectionService().initIsolatePortListener();
    
    // 원래 AppDetectionService에 있던 리스너 로직을 이 안으로 이사 시킵니다.
    _sub = FlutterAccessibilityService.accessStream.listen((event) async {
      if (event.packageName == null) return;
      if (lastPackage == event.packageName) return;
      
      if (lastPackage != null && lastPackage != event.packageName) {
        await DatabaseService.lake(DateTime.now(), lastPackage!, LogType.leave, UsageType.etc);
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
        }
        lastPackage = null;
      }

      if (event.packageName == "com.google.android.youtube" || 
          event.packageName == "com.zhiliaoapp.musically" ||
          event.packageName == "com.android.settings") {
          
        if (_isBlocking) return;
        _isBlocking = true;
        
        await DatabaseService.lake(DateTime.now(), event.packageName!, LogType.enter, UsageType.etc);
        
        await FlutterOverlayWindow.showOverlay(
          alignment: OverlayAlignment.center,
          height: WindowSize.matchParent,
          width: WindowSize.matchParent
        );
        
        _isBlocking = false;
        lastPackage = event.packageName; 
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _sub?.cancel();
    IsolateNameServer.removePortNameMapping('overlay_to_foreground_channel');
    print("🛑 [foreground isolate] 백그라운드 감시 리스너 종료");
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}
}

class AppDetectionService {
  // 싱글톤 패턴 적용 (앱 전체에서 하나의 인스턴스만 공유하도록 설정)
  static final AppDetectionService _instance = AppDetectionService._internal();
  factory AppDetectionService() => _instance;
  AppDetectionService._internal();


  /// 포트 리스너 초기화 (앱 시작 시 최초 1회 호출)
  void initIsolatePortListener() {
    print("[foreground isolate] 포트 리스너 시작");
    final ReceivePort receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping('overlay_to_foreground_channel');
    IsolateNameServer.registerPortWithName(receivePort.sendPort, 'overlay_to_foreground_channel');
    
    receivePort.listen((dynamic message) async {
      print("🚀 [foreground isolate] IsolateNameServer 수신 데이터: $message");
      if (message is String) {
        try {
          final usageType = UsageType.values.byName(message);
          await DatabaseService.updateLastEnterLog(usageType);
        } catch (e) {
          print("[foreground isolate] ❌ 백그라운드 DB 업데이트 중 에러: $e");
        }
      }
    });
  }

  void initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'zentime_foreground',
        channelName: 'ZenTime 앱 실행 유지',
        channelDescription: '앱의 사용 시간을 기록하고 목적을 확인하기 위한 서비스입니다.',
        channelImportance: NotificationChannelImportance.LOW, // 알림 소리 없음
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.once(),
      ),
    );
  }

  /// 감시 시작 스위치 타워
  void startAppDetection() async {
    initForegroundTask(); // 포그라운드 서비스 실행
    if (await FlutterForegroundTask.isRunningService) {
      print("[main isolate] foreground task가 이미 구동 중");
    } else {
      print("[main isolate] foreground task 서비스 시작");
      await FlutterForegroundTask.startService(
        notificationTitle: 'ZenTime 작동 중',
        notificationText: '현재 앱 사용 목적을 모니터링하고 있습니다.',
        callback: startCallback, // 💡 요기에 콜백을 태워 보냅니다!
      );
    }
  }

  /// 감시 중지
  void stopAppDetection() async {
    print("[main isolate] 🛑 디톡스 감시 중지");
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
// app_detection_service.dart end