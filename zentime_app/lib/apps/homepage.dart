import './shared_imports.dart';

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
            child: Text('환영합니다, ${account?.name ?? '사용자'}님!'),
          );
        },
      )
    );
  }
}