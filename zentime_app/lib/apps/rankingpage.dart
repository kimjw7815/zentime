// rankingpage.dart start
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../services/api_service.dart';
import '../services/database_service.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  late Future<List<dynamic>> _dataFuture;
  bool _isRefreshing = false;
  DateTime? _lastSyncTime;
  
  // 💡 버튼 텍스트(10분 제한)와 일치하도록 10분으로 수정
  final Duration _cooldownDuration = const Duration(minutes: 10);

  Future<void> handleSyncWithCooldown() async {
    // 💡 이미 동기화 중이면 중복 실행 방지
    if (_isRefreshing) return;

    final now = DateTime.now();

    // 1. 쿨타임 체크 확인
    if (_lastSyncTime != null && now.difference(_lastSyncTime!) < _cooldownDuration) {
      final remainDuration = _cooldownDuration - now.difference(_lastSyncTime!);
      final remainMin = remainDuration.inMinutes;
      final remainSec = remainDuration.inSeconds % 60;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ 너무 자주 새로고침할 수 없습니다. ($remainMin분 $remainSec초 뒤 가능)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. UI 로딩 락 켜기
    setState(() { _isRefreshing = true; });

    try {
      // 3. 비즈니스 로직(공통 API 함수) 호출하기
      await DatabaseService.rawLogToUsageData();
      bool isSuccess = await sendDataToServer();

      // 4. 컨텍스트가 유효한지 체크 (비동기 처리 도중 화면이 꺼졌을 때 방어 코드)
      if (!mounted) return;

      if (isSuccess) {
        _lastSyncTime = DateTime.now(); // 쿨타임 갱신
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🟢 서버 데이터베이스 동기화 완료!'), backgroundColor: Colors.green),
        );

        // 💡 동기화 완료 후 최신 랭킹 데이터 리로드 및 화면 갱신
        setState(() {
          _dataFuture = _loadData(); 
        });
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ 동기화 실패. 다시 시도해 주세요.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("❌ 랭킹 페이지 동기화 에러: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 에러 발생: $e'), backgroundColor: Colors.red),
      );
    } finally {
      // 5. UI 로딩 락 풀기
      if (mounted) {
        setState(() { _isRefreshing = false; });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  // 데이터 로딩: 박스를 안전하게 한 번만 열고 즉시 닫음 (다른 페이지 아키텍처와 통일)
  Future<List<dynamic>> _loadData() async {
    final authBox = await Hive.openBox('authBox');
    String? token;
    try {
      token = authBox.get('jwt_token');
    } finally {
      await authBox.close();
    }

    if (token == null || token.isEmpty) {
      throw Exception('로그인이 필요한 서비스입니다.');
    }

    final String todayDate = DateTime.now().toIso8601String().split('T')[0];

    return Future.wait([
      fetchRanking(todayDate, 0, token),
      fetchComparison(todayDate, 0, token),
    ]);
  }

  // 💡 형변환 안정성 확보 및 가독성 개선
  String _formatSecondsToMinutes(dynamic totalSeconds) {
    if (totalSeconds == null) return '0분 0초';
    final int seconds = (totalSeconds as num).toInt();
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '$minutes분 $remainingSeconds초';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
        elevation: 0,
        title: Text('디톡스 랭킹',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
            )),
      ),
      body: Stack(
        children: [
          FutureBuilder<List<dynamic>>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('에러 발생: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isDark
                                ? const Color(0xFF888888)
                                : const Color(0xFF999999))),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.length < 2) {
                return Center(
                    child: Text('랭킹 데이터를 불러올 수 없습니다.',
                        style: TextStyle(
                            color: isDark
                                ? const Color(0xFF444444)
                                : const Color(0xFFBBBBBB))));
              }

              final rankingData = snapshot.data![0] as List<dynamic>;
              final comparisonData = snapshot.data![1] as List<dynamic>;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // 서버 동기화 버튼
                  GestureDetector(
                    onTap: _isRefreshing ? null : handleSyncWithCooldown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFE0E0E0)),
                      ),
                      child: Center(
                        child: Text(
                          _isRefreshing ? '서버 동기화 중...' : '서버 데이터베이스 연결 (10분 제한)',
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: _isRefreshing
                                ? (isDark ? const Color(0xFF444444) : const Color(0xFFBBBBBB))
                                : (isDark ? const Color(0xFFE8E8E8) : const Color(0xFF111111)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 친구와 비교
                  Text('🔥 친구와 비교',
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFE8E8E8) : const Color(0xFF111111),
                      )),
                  const SizedBox(height: 12),
                  if (comparisonData.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text('비교할 친구 데이터가 없습니다.',
                          style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF444444)
                                  : const Color(0xFFBBBBBB))),
                    )
                  else
                    ...comparisonData.map((item) {
                      if (item['isMe'] == true) return const SizedBox.shrink();
                      final int diffSeconds =
                          (item['diffWithMe'] as num? ?? 0).toInt();
                      final bool isBetter = diffSeconds < 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : const Color(0xFFEBEBEB)),
                        ),
                        child: Row(children: [
                          Icon(
                            isBetter ? Icons.trending_up : Icons.trending_down,
                            color: isBetter
                                ? const Color(0xFF32B464)
                                : const Color(0xFFDC3C3C),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('${item['userName'] ?? '알 수 없는 사용자'}님과의 대결',
                                  style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFE8E8E8)
                                        : const Color(0xFF111111),
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                isBetter
                                    ? '상대보다 ${_formatSecondsToMinutes(diffSeconds.abs())} 더 집중했어요!'
                                    : '상대보다 ${_formatSecondsToMinutes(diffSeconds.abs())} 더 썼네요.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF666666)
                                        : const Color(0xFF999999)),
                              ),
                            ]),
                          ),
                        ]),
                      );
                    }),

                  const SizedBox(height: 20),

                  // 전체 랭킹
                  Text('🏆 전체 랭킹',
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFE8E8E8) : const Color(0xFF111111),
                      )),
                  const SizedBox(height: 12),
                  if (rankingData.isEmpty)
                    Text('등록된 랭킹 데이터가 없습니다.',
                        style: TextStyle(
                            color: isDark
                                ? const Color(0xFF444444)
                                : const Color(0xFFBBBBBB)))
                  else
                    ...rankingData.map((user) {
                      final int rank = (user['rank'] as num? ?? 0).toInt();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : const Color(0xFFEBEBEB)),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: _getRankColor(rank),
                            child: Text('$rank',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(user['userName'] ?? '사용자',
                                  style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFE8E8E8)
                                        : const Color(0xFF111111),
                                  )),
                              const SizedBox(height: 2),
                              Text('낭비한 시간: ${_formatSecondsToMinutes(user['totalTime'])}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFF666666)
                                          : const Color(0xFF999999))),
                            ]),
                          ),
                        ]),
                      );
                    }),
                ],
              );
            },
          ),
          if (_isRefreshing)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // 💡 dynamic 인자를 안전하게 받아서 색상 매핑하도록 수정
  Color _getRankColor(dynamic rank) {
    final int rankInt = (rank as num? ?? 0).toInt();
    if (rankInt == 1) return Colors.amber;
    if (rankInt == 2) return Colors.grey;
    if (rankInt == 3) return Colors.brown;
    return Colors.blueGrey;
  }
}
// rankingpage.dart end