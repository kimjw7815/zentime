// detailpage.dart start
import '../services/util_service.dart';
import './shared_imports.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool _isLoading = true;
  
  // 💡 날짜별(Key) 정제된 AppUsageData 리스트를 담아둘 로컬 상태 변수
  Map<String, List<AppUsageData>> _usageDataMap = {};

  @override
  void initState() {
    super.initState();
    _loadDetailData();
  }

  // 💡 안전하게 박스를 열어 로컬 변수에 데이터를 복사한 후 즉시 닫는 메서드
  Future<void> _loadDetailData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final usageBox = await Hive.openBox(DatabaseService.usageBoxName);
    
    try {
      print("📦 현재 박스에 저장된 총 데이터 개수: ${usageBox.length}");
      
      for (var key in usageBox.keys) {
        final rawData = usageBox.get(key);
        
        print("----------------------------------------------------------------");
        print("🔑 [Key]: $key");
        // ⭐ 이 부분이 핵심입니다. Dart가 실시간으로 인식하는 진짜 타입을 출력합니다.
        print("🧪 [Actual Runtime Type]: ${rawData.runtimeType}"); 
        print("📦 [Value]: $rawData");
      }
    } catch (e) {
      print("❌ 디버그 출력 중 에러 발생: $e");
    }

    try {
      final Map<String, List<AppUsageData>> tempMap = {};
      
      for (var key in usageBox.keys) {
        final rawList = usageBox.get(key);
        print(rawList);
        if (rawList is List) {
          // 데이터 유효성 검사 및 명시적 캐스팅 파싱
          final List<AppUsageData> typedList = rawList
              .whereType<AppUsageData>()
              .toList();
          
          tempMap[key.toString()] = typedList;
        }
      }

      setState(() {_usageDataMap = tempMap;});
    } catch (e) {
      print("❌ [main isolate] 데이터 로드 중 에러 발생: $e");
    } finally {
      // 💡 어떤 예외가 터져도 하이브 박스는 무조건 안전하게 닫히도록 보장
      await usageBox.close();
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 💡 날짜(Key)들을 역순(최신순) 정렬
    final sortedKeys = _usageDataMap.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('사용 기록 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            // 로딩 중일 때는 버튼을 비활성화하여 중복 터치 방지
            onPressed: _isLoading ? null : _loadDetailData, 
          ),
        ],
      ),
      // 💡 수동 데이터 동기화를 보완하기 위한 당겨서 새로고침 위젯 도입
      body: RefreshIndicator(
        onRefresh: _loadDetailData,
        child: sortedKeys.isEmpty
            ? const Center(child: Text('기록이 없습니다.\n(아래로 당겨서 새로고침)', textAlign: TextAlign.center))
            : ListView.builder(
                itemCount: sortedKeys.length,
                itemBuilder: (context, dateIndex) {
                  final dateKey = sortedKeys[dateIndex];
                  final appList = _usageDataMap[dateKey] ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- 날짜 헤더 ---
                      Container(
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          '📅 날짜: $dateKey',
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary
                          ),
                        ),
                      ),

                      // --- 해당 날짜의 앱 리스트 ---
                      if (appList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('해당 날짜에 기록된 정제 데이터가 없습니다.', style: TextStyle(color: Colors.grey)),
                        ),

                      ...appList.map((appData) {
                        return Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.apps, color: Colors.indigo),
                              title: Text(
                                appData.appName.split('.').last, // 패키지명 가독성 처리
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            // --- 앱 내부의 목적 타입별 사용량 ---
                            ...appData.usageByType.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 72, right: 24, bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      entry.key.displayName,
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                    Text(
                                      Util.formatDuration(entry.value),
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        );
                      }),
                      const Divider(height: 1, thickness: 1),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
// detailpage.dart end