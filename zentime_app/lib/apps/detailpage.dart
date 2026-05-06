import './shared_imports.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용 기록 상세')),
      body: ValueListenableBuilder(
        // 1. 박스 타입을 DatabaseService에서 선언한 것과 동일하게 Box<List<dynamic>> 또는 Box로 맞춥니다.
        valueListenable: Hive.box<List<dynamic>>(DatabaseService.usageBoxName).listenable(),
        builder: (context, Box<List<dynamic>> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('기록이 없습니다.'));
          }

          // 2. 날짜(Key)들을 정렬해서 보여주고 싶다면 아래처럼 정렬할 수 있습니다.
          final sortedKeys = box.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView(
            children: [
              for (var dateKey in sortedKeys) ...[
                // --- 날짜 헤더 ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    '날짜: $dateKey',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                // --- 해당 날짜의 앱 리스트 ---
                for (var appData in (box.get(dateKey) ?? [])) ...[
                  // appData를 명시적으로 캐스팅 (AppUsageData로 인식시키기)
                  if (appData is AppUsageData) ...[
                    ListTile(
                      leading: const Icon(Icons.apps, color: Colors.indigo),
                      title: Text(
                        appData.appName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    // --- 앱 내부의 타입별 사용량 ---
                    for (var entry in appData.usageByType.entries)
                      Padding(
                        padding: const EdgeInsets.only(left: 72, right: 24, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Enum의 displayName 사용 (만약 int라면 '타입 ${entry.key}')
                            Text(entry.key is UsageType 
                                ? (entry.key as UsageType).displayName 
                                : '타입 ${entry.key}'),
                            // 마이크로초를 분/시간 단위로 변환해서 출력
                            Text(_formatDuration(entry.value)),
                          ],
                        ),
                      ),
                  ],
                ],
                const Divider(height: 1, thickness: 1),
              ]
            ],
          );
        },
      ),
    );
  }

  // 시간 포맷팅 헬퍼 함수 (선택 사항)
  String _formatDuration(int microseconds) {
    final minutes = (microseconds / 1000000 / 60).round();
    if (minutes >= 60) {
      return '${minutes ~/ 60}시간 ${minutes % 60}분';
    }
    return '$minutes분';
  }
}