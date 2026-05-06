import 'package:flutter/material.dart';
import 'package:zentime/apps/homepage.dart';
import 'package:zentime/apps/detailpage.dart';
import 'package:zentime/apps/rankingpage.dart';
import 'package:zentime/apps/settingpage.dart';

class FramePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  const FramePage({super.key, required this.toggleTheme});

  @override
  State<FramePage> createState() => _FramePageState();
}
class _FramePageState extends State<FramePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      const HomePage(),    // 0번: 홈 페이지
      const DetailPage(),    // 1번: 상세 페이지
      const RankingPage(),    // 0번: 랭킹 페이지
      const SettingPage(),    // 2번: 설정 페이지
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('ZenTIme'),
      ),
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: widget.toggleTheme,
        tooltip: '라이트/다크 모드 변경',
        child: const Icon(Icons.sunny),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: '상세',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: '랭킹',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index; // 사용자가 누른 번호로 업데이트!
          });
        },
      )
    );
  }
}