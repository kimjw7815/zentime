//homepage.dart start

import 'dart:math';

import './shared_imports.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:async';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'dart:isolate';
import 'dart:ui';

// 접근성서비스 구독(리스닝)
StreamSubscription<AccessibilityEvent>? _accessibilitySubscription;
// 접근성서비스에서 같은 신호 2번 연속으로 줄 때, 같은 앱에서 신호를 또 줄 때 대비
// 대증요법임. 추후 Java나 Kotlin에서 직접 접근성 서비스로 접근해야 해결 가능한 문제임.
bool _isBlocking=false;

Future<void> sendTestFile() async {
  // OCI 서버의 공인 IP로 교체하세요
  final String serverIp = "146.56.175.74"; 
  final url = Uri.parse('http://$serverIp:8000/test-upload');

  try {
    // 1. Multipart 요청 생성
    var request = http.MultipartRequest('POST', url);

    // 2. 가상의 temp.txt 파일 생성 및 첨부
    request.files.add(
      http.MultipartFile.fromString(
        'file', 
        'Hello, world!', 
        filename: 'temp.txt',
      ),
    );

    print("전송 시작...");
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      print("전송 성공: ${response.body}");
    } else {
      print("전송 실패: ${response.statusCode}");
    }
  } catch (e) {
    print("에러 발생: $e");
  }
}

void startAppDetection() async {
  String? lastPackage;
  // 오버레이 권한 체크
  bool isOverlayGranted = await FlutterOverlayWindow.isPermissionGranted();
  if (!isOverlayGranted) {
    print("❌ 오버레이 권한 없음 -> 설정창으로 이동");
    await FlutterOverlayWindow.requestPermission();
    return; // 💡 중요: 설정창을 열었으므로 일단 함수를 종료하고, 사용자가 허용한 뒤 다시 버튼을 누르게 유도해!
  }

  // 접근성 권한 체크
  bool isAccessibilityEnabled = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
  if (!isAccessibilityEnabled) {
    await FlutterAccessibilityService.requestAccessibilityPermission();
    return;
  }
  // 알람 권한 체크
  NotificationPermission notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission == NotificationPermission.denied) {
    print("❌ 알림 권한 없음 -> 권한 요청 팝업");
    await FlutterForegroundTask.requestNotificationPermission();
    return; // 허용하고 다시 버튼 누르도록 유도
  }

  // Foreground 태스크 서비스
  initForegroundTask();

  // 포트리스너
  final ReceivePort receivePort = ReceivePort();
  IsolateNameServer.removePortNameMapping('overlay_to_main_channel');
  IsolateNameServer.registerPortWithName(receivePort.sendPort, 'overlay_to_main_channel');
  receivePort.listen((dynamic message) async {
    print("🚀 [메인 아이솔레이트] IsolateNameServer 수신 데이터: $message");
    
    if (message is String) {
      try {
        final usageType = UsageType.values.byName(message);
        await DatabaseService.updateLastLog(usageType);
        print("📝 백그라운드 DB 업데이트 완료");
      } catch (e) {
        print("❌ 백그라운드 DB 업데이트 중 에러: $e");
      }
    }
  });
  // 이건 접근성서비스 리스너
  _accessibilitySubscription?.cancel();
  _accessibilitySubscription = FlutterAccessibilityService.accessStream.listen((event) async {
    // 사용자가 새로운 화면을 완전히 켰을 때 패키지명 검사
    if (event.packageName != null) {
      print("_lastPackage${lastPackage}");
      print("event.packageName${event.packageName}");
      print("📱 [시스템 신호] 현재 전면 앱: ${event.packageName}");
      if (lastPackage==event.packageName) {
        print("같은 앱이십니다 선생님");
        return;
      }
      if (lastPackage!=null && lastPackage!=event.packageName) {
        print("다른 앱으로 옮겨가셨네요");
        await DatabaseService.lake(
          DateTime.now(),
          lastPackage!,
          LogType.leave,
          UsageType.etc
        );
        lastPackage=null;
      }

      // 타겟 앱 감지
      if (event.packageName == "com.google.android.youtube" || 
          event.packageName == "com.zhiliaoapp.musically" ||
          event.packageName == "com.android.settings") {
        if (_isBlocking) {
          print("선신호가 있습니다 선생님");
          return;
        }
        //   print("오버레이가 이미 열려있습니다 선생님");
        //   return;
        // }
        // 일단 적치, 후 오버레이 단계에서 updateLastLog(usageType)
        _isBlocking=true;
        print("🚨 딴짓 즉시 차단!");
        await DatabaseService.lake(
          DateTime.now(), event.packageName!,
          LogType.enter, UsageType.etc
        );
        await FlutterOverlayWindow.showOverlay(
          alignment: OverlayAlignment.center,
          height: WindowSize.matchParent,
          width: WindowSize.matchParent
        );
        // await으로 오버레이 보여주기 끝나면 다시 자물쇠 풀기
        // lastPackage를 오버레이 다 끝나고 나서 관리하니까 lastPackage는 오버레이 대상
        // 즉 디톡스 관리 대상 앱으로 제한됨.
        _isBlocking=false;
        lastPackage=event.packageName;
        print("_isBlocking${_isBlocking}");
        print("_lastPackage${lastPackage}");
      }
    }
  });
}
// 포그라운드 서비스 (알람)
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
  if (await FlutterForegroundTask.isRunningService) {
    print("이미 ForegroundTask가 서비스를하고 있음요");
  } else {
    print("ForegroundTask의 서비스를 시작하고 있음요");
    await FlutterForegroundTask.startService(
      notificationTitle: 'ZenTime 작동 중',
      notificationText: '현재 앱 사용 목적을 모니터링하고 있습니다.',
    );
    print("ForegroundTask의 서비스를 시작했음요");
  }
}

rawLogToUsageData() async {
  // db 새로고침
  await Hive.box<RawLog>(DatabaseService.rawLogBoxName).close();
  await Hive.openBox<RawLog>(DatabaseService.rawLogBoxName);
  final rawLogBox=Hive.box<RawLog>(DatabaseService.rawLogBoxName);
  await Hive.openBox<List<dynamic>>(DatabaseService.usageBoxName);
  final usageBox=Hive.box<List<dynamic>>(DatabaseService.usageBoxName);

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
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    return _isRefreshing? const Center(child: CircularProgressIndicator()):Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          Hive.box<UserAccountData>(DatabaseService.userBoxName).listenable(),
          Hive.box<RawLog>(DatabaseService.rawLogBoxName).listenable(),
        ]),
        builder: (context, _) {
          final userBox = Hive.box<UserAccountData>(DatabaseService.userBoxName);
          final logBox = Hive.box<RawLog>(DatabaseService.rawLogBoxName);

          final account = userBox.get('profile');
          final logs = logBox.values.toList().reversed.toList();
          
          return Center(
            child: Column(
              children: [
                Text('환영합니다, ${account?.name ?? '사용자'}님!'),
                TextButton(onPressed: sendTestFile, child: Text('data 보내기')),
                ElevatedButton(
                  onPressed: startAppDetection,
                  child: const Text("디톡스 감시 시작")
                ),
                ElevatedButton(
                  onPressed: _isRefreshing?null:() async {
                    setState(() { _isRefreshing=true;});
                    print("db 새로고침중");
                    await Hive.box<RawLog>(DatabaseService.rawLogBoxName).close();
                    await Hive.openBox<RawLog>(DatabaseService.rawLogBoxName);
                    print("db 새로고침 완료");
                    setState(() { _isRefreshing=false;});
                  },
                  child: const Text("db 새로고침")
                ),
                Expanded(
                  child: logs.isEmpty? const Center(child: Text('적치된 로그가 없습니다.'),):
                    ListView(children: [for (var log in logs) ...[
                      Row(children: [
                        Text(log.appName),
                        const SizedBox(width: 10),
                        Text(log.dateTime.toString()),
                      ]),
                      Row(children: [
                        Text(log.logType.name),
                        const SizedBox(width: 10),
                        Text(log.usageType.displayName),
                      ]),
                    ],
                    ElevatedButton(
                      onPressed: _isRefreshing?null:() async {
                        setState(() { _isRefreshing=true;});
                        print("db 정리하기");
                        await rawLogToUsageData();
                        print("db 정리 완료");
                        setState(() { _isRefreshing=false;});
                      },
                      child: const Text("db 정리")
                    ),
                    ],
                  ),
                )
              ],
            )
          );
        },
      )
    );
  }
}
//homepage.dart end