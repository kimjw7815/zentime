import '../services/api_service.dart';
import './shared_imports.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
        elevation: 0,
        title: Text('설정',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
            )),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                // 프로필 카드
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFE8E8E8)),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
                      child: Text(
                        (_account != null && _account!.name.isNotEmpty)
                            ? _account!.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFE8E8E8) : const Color(0xFF111111),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(_account?.name ?? '로그인 필요',
                            style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFE8E8E8)
                                  : const Color(0xFF111111),
                            )),
                        const SizedBox(height: 2),
                        Text(_account?.email ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF666666)
                                  : const Color(0xFF999999),
                            )),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // 메뉴 카드
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFE8E8E8)),
                  ),
                  child: Column(children: [
                    if (_account == null)
                      _menuItem(
                        icon: Icons.login_rounded,
                        label: '구글 계정으로 로그인',
                        isDark: isDark,
                        onTap: () async {
                          bool success = await loginWithGoogleAndBackend();
                          if (success) {
                            await _loadUserProfile();
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('로그인 실패!')));
                          }
                        },
                      )
                    else
                      _menuItem(
                        icon: Icons.logout_rounded,
                        label: '로그아웃',
                        isDark: isDark,
                        labelColor: const Color(0xFFDC3C3C),
                        iconColor: const Color(0xFFDC3C3C),
                        onTap: () async {
                          var userBox = await Hive.openBox<UserAccountData>(
                              DatabaseService.userBoxName);
                          await userBox.delete('profile');
                          await userBox.close();
                          var authBox = await Hive.openBox('authBox');
                          await authBox.delete('jwt_token');
                          await authBox.close();
                          await _loadUserProfile();
                        },
                      ),
                    Divider(height: 1, thickness: 0.5,
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFEEEEEE)),
                    _menuItem(
                      icon: Icons.brightness_6_outlined,
                      label: '라이트 / 다크 모드 변경',
                      isDark: isDark,
                      onTap: widget.toggleTheme,
                    ),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required bool isDark,
    Color? iconColor,
    Color? labelColor,
    required VoidCallback onTap,
  }) {
    final defaultIcon = isDark ? const Color(0xFF888888) : const Color(0xFF555555);
    final defaultLabel = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF111111);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor ?? defaultIcon),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: labelColor ?? defaultLabel,
              )),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              size: 16,
              color: isDark ? const Color(0xFF333333) : const Color(0xFFCCCCCC)),
        ]),
      ),
    );
  }
}