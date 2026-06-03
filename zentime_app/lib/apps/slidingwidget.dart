// slidingwidget.dart start
import './shared_imports.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'dart:isolate';
import 'dart:ui';

class SlidingWidget extends StatefulWidget {
  const SlidingWidget({super.key});

  @override
  State<SlidingWidget> createState() => _SlidingWidgetState();
}

class _SlidingWidgetState extends State<SlidingWidget> {
  double _offsetY = 0.0; // 1.0은 화면 아래 숨겨진 상태, 0.0은 정위치

  @override
  void initState() {
    super.initState();
    // 위젯이 로드되면 0.1초 뒤 바닥에서 부드럽게 업!
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _offsetY = 0.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 6가지 목적을 이쁘게 배치하기 위해 높이를 화면의 45%로 살짝 늘렸어
    final double overlayHeight = MediaQuery.of(context).size.height * 0.45;

    return Stack(
      children: [
        AnimatedSlide(
          offset: Offset(0, _offsetY),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic, // 좀 더 부드러운 슬라이드 애니메이션
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: overlayHeight,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                // 모토에 맞게 너무 험악한 검은색 대신 세련된 다크 블루그레이 톤 적용
                color: const Color(0xFF1E293B).withOpacity(0.95), 
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 인디케이터 바 (바닥 시트 느낌 물씬)
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // 타이틀 메시지
                  const Text(
                    "잠시만요! 🤔",
                    style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "이 앱을 켜신 목적이 무엇인가요?",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w100, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 25),

                  // 💡 6가지 목적 버튼 리스트 (Wrap을 활용한 반응형 그리드 배치)
                  Expanded(
                    child: Wrap(
                      spacing: 12,    // 가로 칩 간격
                      runSpacing: 14, // 세로 줄 간격
                      alignment: WrapAlignment.center,
                      children: UsageType.values.map((type) {
                        final double screenWidth = MediaQuery.of(context).size.width;
                        final double buttonWidth = screenWidth > 0 ? (screenWidth - 52) / 2 : 150.0;
                        return SizedBox(
                          // 화면 너비에 맞춰 칩이 2열로 이쁘게 쪼개지도록 너비 계산
                          width: buttonWidth,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF334155), // 가독성 좋은 차분한 칩 배경색
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: () async {
                              print("🎯 사용자가 선택한 목적: ${type.displayName}");
                              
                              // TODO: 여기에 Hive나 백그라운드 데이터베이스에 사용 기록(AppUsageData) 누적하는 로직을 추가하면 됨!
                              final SendPort? sendPort = IsolateNameServer.lookupPortByName('overlay_to_main_channel');
                              if (sendPort != null) {
                                // 2. Dart VM 내부 메모리를 통해 직접 데이터 송신 (안드로이드 채널 우회)
                                sendPort.send(type.name);
                                print("⚡ IsolateNameServer 송신 성공");
                              } else {
                                print("❌ 메인 아이솔레이트의 송신 포트를 찾을 수 없습니다.");
                              }
                              await FlutterOverlayWindow.closeOverlay();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _getIconForUsageType(type), // 목적별 아이콘 매칭
                                const SizedBox(width: 10),
                                Text(
                                  type.displayName,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w100),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 각 목적 유형에 어울리는 이쁜 아이콘 매칭용 헬퍼 함수
  Widget _getIconForUsageType(UsageType type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case UsageType.playing:
        iconData = Icons.sports_esports_rounded;
        iconColor = Colors.orangeAccent;
        break;
      case UsageType.homework:
        iconData = Icons.menu_book_rounded;
        iconColor = Colors.lightBlueAccent;
        break;
      case UsageType.working:
        iconData = Icons.laptop_mac_rounded;
        iconColor = Colors.greenAccent;
        break;
      case UsageType.social:
        iconData = Icons.forum_rounded;
        iconColor = Colors.pinkAccent;
        break;
      case UsageType.searching:
        iconData = Icons.search_rounded;
        iconColor = Colors.purpleAccent;
        break;
      default:
        iconData = Icons.more_horiz_rounded;
        iconColor = Colors.grey;
    }

    return Icon(iconData, color: iconColor, size: 22);
  }
}
// slidingwidget.dart end