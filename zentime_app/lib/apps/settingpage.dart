import './shared_imports.dart';

class SettingPage extends StatelessWidget {
  final VoidCallback toggleTheme;
  const SettingPage({super.key, required this.toggleTheme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:ValueListenableBuilder(
        // 1. 박스 타입을 DatabaseService에서 선언한 것과 동일하게 Box<List<dynamic>> 또는 Box로 맞춥니다.
        valueListenable: Hive.box<UserAccountData>(DatabaseService.userBoxName).listenable(),
        builder: (context, Box<UserAccountData> box, _) {
          final account = box.get('profile');
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Text('여기는 설정 창입니다'),
              Text('이름 ${account?.name ?? '사용자'}'),
              Text('등록된 이메일 ${account?.email ?? '존재하지 않음'}'),
              TextButton(onPressed: () => {}, child: Text('비밀번호 변경하기')),
              TextButton(onPressed: toggleTheme, child: Text('라이트모드/다크모드 변경하기'))
            ],
          );
        }
      )
    );
  }
}