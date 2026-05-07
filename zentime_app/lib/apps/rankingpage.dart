import './shared_imports.dart';
import '../services/api_service.dart';

class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('디톡스 랭킹 (놀이/기타 시간)')),
      body: FutureBuilder<List<dynamic>>(
        // 1. 데이터를 가져올 Future 연결
        future: Future.wait([
          fetchRanking('2026-05-08', 0),
          fetchComparison('user_A', '2026-05-08', 0),
        ]),
          builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('에러: ${snapshot.error}'));
          }

          // snapshot.data![0] -> 랭킹 데이터
          // snapshot.data![1] -> 비교 데이터
          final rankingData = snapshot.data![0];
          final comparisonData = snapshot.data![1];

          return CustomScrollView( // 여러 리스트를 겹치지 않게 보여주기 좋음
            slivers: [
              // 섹션 1: 친구 비교 (상단)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('🔥 친구와 비교', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = comparisonData[index];
                    if (item['isMe']) return const SizedBox.shrink(); // 나 자신은 제외

                    final diffMinutes = (item['diffWithMe']).abs().toStringAsFixed(1);
                    final isBetter = item['diffWithMe'] < 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text('${item['userName']}님과의 대결'),
                        subtitle: Text(isBetter ? '상대보다 $diffMinutes분 더 집중했어요! 스타벅스 커피 n컵이에요.' : '상대보다 $diffMinutes분 더 썼네요. 분발합시다!'),
                        leading: Icon(isBetter ? Icons.trending_up : Icons.trending_down, color: isBetter ? Colors.green : Colors.red),
                      ),
                    );
                  },
                  childCount: comparisonData.length,
                ),
              ),

              // 섹션 2: 전체 랭킹 (하단)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('🏆 전체 랭킹', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = rankingData[index];
                    final minutes = (user['totalTime']).toStringAsFixed(1);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getRankColor(user['rank']),
                        child: Text('${user['rank']}'),
                      ),
                      title: Text(user['userName']),
                      subtitle: Text('낭비한 시간: $minutes분'),
                    );
                  },
                  childCount: rankingData.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber; // 금
    if (rank == 2) return Colors.grey;  // 은
    if (rank == 3) return Colors.brown; // 동
    return Colors.blueGrey;
  }
}