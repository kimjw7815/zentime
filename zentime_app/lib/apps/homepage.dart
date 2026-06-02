//homepage.dart start

import 'dart:math';

import './shared_imports.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:async';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';

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
        // 일단 적치, 후 오버레이 단계에서 updateLastLog(usageType)
        if (!await FlutterOverlayWindow.isActive()) {
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
    }
  });
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200,50),
                  ),
                  onPressed: startAppDetection,
                  child: const Text("디톡스 감시 시작")
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
                  ]],),
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