import './shared_imports.dart';
import '../services/api_service.dart';

class SettingPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  const SettingPage({super.key, required this.toggleTheme});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _isLoading = true;
  UserAccountData? _account; // 👈 하이브에서 꺼낸 데이터를 담아둘 상태 변수

  @override
  void initState() {
    super.initState();
    _loadUserProfile(); // 화면 켜질 때 로드
  }

  // 💾 [정석 원칙] 열고 ➡️ 읽고 ➡️ 즉시 닫고 ➡️ setState
  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    
    var userBox = await Hive.openBox<UserAccountData>(DatabaseService.userBoxName);
    _account = userBox.get('profile'); // 데이터 복사
    await userBox.close(); // 용무 끝났으니 즉시 닫기 🔒
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('여기는 설정 창입니다', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // 이제 일반 상태 변수(_account)에서 안전하게 데이터를 뿌립니다.
                  Text('이름: ${_account?.name ?? '로그인 필요'}'),
                  Text('등록된 이메일: ${_account?.email ?? '존재하지 않음'}'),
                  const SizedBox(height: 20),

                  if (_account == null) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('구글 계정으로 로그인'),
                      onPressed: () async {
                        // 로그인 함수 내부에서 하이브 박스를 열고 닫는 작업이 완전히 끝난 뒤 돌아옵니다.
                        bool success = await loginWithGoogleAndBackend();

                        if (success) {
                          // 💡 로그인이 성공했다면, 다시 박스를 열어서 새로 바뀐 프로필을 감지해옵니다.
                          await _loadUserProfile();
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('로그인 실패!')),
                          );
                        }
                      },
                    ),
                  ] else ...[
                    TextButton(
                      onPressed: () async {
                        // 로그아웃 시에도 열고 ➡️ 지우고 ➡️ 즉시 닫기
                        var userBox = await Hive.openBox<UserAccountData>(DatabaseService.userBoxName);
                        await userBox.delete('profile');
                        await userBox.close(); // 닫기

                        var authBox = await Hive.openBox('authBox');
                        await authBox.delete('jwt_token');
                        await authBox.close(); // 닫기

                        // 상단 프로필 변수 비우고 UI 갱신
                        await _loadUserProfile();
                      },
                      child: const Text('로그아웃하기', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  TextButton(
                    onPressed: widget.toggleTheme, 
                    child: const Text('라이트모드/다크모드 변경하기'),
                  )
                ],
              ),
            ),
    );
  }
}