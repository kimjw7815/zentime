//homepage.dart start

import './shared_imports.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:async';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';

StreamSubscription<AccessibilityEvent>? _accessibilitySubscription;

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
// 1. [1단계] 오버레이 권한 먼저 체크
  bool isOverlayGranted = await FlutterOverlayWindow.isPermissionGranted();
  if (!isOverlayGranted) {
    print("❌ 오버레이 권한 없음 -> 설정창으로 이동");
    await FlutterOverlayWindow.requestPermission();
    return; // 💡 중요: 설정창을 열었으므로 일단 함수를 종료하고, 사용자가 허용한 뒤 다시 버튼을 누르게 유도해!
  }

  // 2. [2단계] 오버레이 권한이 있다면, 앱 사용 기록 권한 체크
  bool isAccessibilityEnabled = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
  if (!isAccessibilityEnabled) {
    await FlutterAccessibilityService.requestAccessibilityPermission();
    return;
  }
  _accessibilitySubscription?.cancel();
  _accessibilitySubscription = FlutterAccessibilityService.accessStream.listen((event) async {
  // 사용자가 새로운 화면을 완전히 켰을 때 패키지명 검사
  if (event.packageName != null) {
    print("📱 [시스템 신호] 현재 전면 앱: ${event.packageName}");

    // 타겟 앱 감지
    if (event.packageName == "com.google.android.youtube" || 
        event.packageName == "com.zhiliaoapp.musically" ||
        event.packageName == "com.android.settings") {
      
      if (!await FlutterOverlayWindow.isActive()) {
        print("🚨 딴짓 즉시 차단!");
        await FlutterOverlayWindow.showOverlay(
          alignment: OverlayAlignment.center,
          height: WindowSize.matchParent,
          width: WindowSize.matchParent,
        );
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
      body: ValueListenableBuilder(
        valueListenable: Hive.box<UserAccountData>(DatabaseService.userBoxName).listenable(),
        builder: (context, Box<UserAccountData> box, _) {
          final account = box.get('profile');
          
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