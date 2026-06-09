// slidingwidget.dart start
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import './shared_imports.dart';

class SlidingWidget extends StatefulWidget {
  const SlidingWidget({super.key});

  @override
  State<SlidingWidget> createState() => _SlidingWidgetState();
}

class _SlidingWidgetState extends State<SlidingWidget> {
  double _offsetY = 1.0; // 1.0은 화면 아래 숨겨진 상태, 0.0은 정위치

  @override
  void initState() {
    super.initState();
    // 위젯이 로드되면 0.4초 뒤 바닥에서 부드럽게 업! (시간을 0.4초로 살짝 당겼어)
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _offsetY = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double overlayHeight = MediaQuery.of(context).size.height * 0.55;

    return Stack(
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedSlide(
            offset: Offset(0, _offsetY),
            duration: const Duration(milliseconds: 300), // 드래그를 놓았을 때 튕겨 제자리로 갈 때의 속도
            curve: Curves.easeOutCubic,
            child: GestureDetector(
              // 💡 1. 사용자가 손가락으로 누르고 아래로 끌 때 실행되는 로직
              onVerticalDragUpdate: (details) {
                // 아래로 드래그할 때 변하는 픽셀(details.delta.dy)을 비율값으로 환산하여 반영
                setState(() {
                  _offsetY += details.delta.dy / overlayHeight;
                  // 위로는 더이상 못 올라가게 0.0 ~ 1.0 사이로 값 제한 (clamp)
                  _offsetY = _offsetY.clamp(0.0, 1.0);
                });
              },
              // 💡 2. 사용자가 손가락을 뗐을 때 실행되는 로직
              onVerticalDragEnd: (details) async {
                // 30% 이상 아래로 쓸어내렸거나, 내리는 속도(Velocity)가 빠르다면 닫기 진행
                if (_offsetY > 0.3 || details.primaryVelocity! > 300) {
                  setState(() {
                    _offsetY = 1.0; // 끝까지 내리기
                  });
                  // 내려가는 애니메이션이 끝날 때까지 0.2초 기다린 후 네이티브 윈도우 종료
                  await Future.delayed(const Duration(milliseconds: 200));
                  await FlutterOverlayWindow.closeOverlay();
                } else {
                  // 조금만 내리다 말았으면 다시 제자리(바닥)로 튕겨 올라옴
                  setState(() {
                    _offsetY = 0.0;
                  });
                }
              },
              child: Container(
                height: overlayHeight,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
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
                    // 상단 인디케이터 바 (유저가 여기를 잡고 내릴 수 있다는 시각적 힌트)
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

                    Expanded(
                      child: Wrap(
                        spacing: 12,    
                        runSpacing: 14, 
                        alignment: WrapAlignment.center,
                        children: UsageType.values.map((type) {
                          final double screenWidth = MediaQuery.of(context).size.width;
                          final double buttonWidth = screenWidth > 0 ? (screenWidth - 52) / 2 : 150.0;
                          return SizedBox(
                            width: buttonWidth,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF334155), 
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onPressed: () async {
                                final SendPort? sendPort = IsolateNameServer.lookupPortByName('overlay_to_foreground_channel');
                                if (sendPort != null) {
                                  sendPort.send(type.name);
                                }
                                await FlutterOverlayWindow.closeOverlay();
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _getIconForUsageType(type), 
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