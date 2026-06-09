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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sortedKeys = _usageDataMap.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
        elevation: 0,
        title: Text('사용 기록 상세',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111),
            )),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh,
                color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF111111)),
            onPressed: _isLoading ? null : _loadDetailData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetailData,
        child: sortedKeys.isEmpty
            ? Center(
                child: Text('기록이 없습니다.\n아래로 당겨서 새로고침',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isDark
                            ? const Color(0xFF444444)
                            : const Color(0xFFBBBBBB))))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: sortedKeys.length,
                itemBuilder: (context, dateIndex) {
                  final dateKey = sortedKeys[dateIndex];
                  final appList = _usageDataMap[dateKey] ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 4),
                        child: Text('📅  날짜: $dateKey',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF888888)
                                  : const Color(0xFF999999),
                            )),
                      ),
                      if (appList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text('해당 날짜에 기록된 데이터가 없습니다.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFF444444)
                                      : const Color(0xFFBBBBBB))),
                        ),
                      ...appList.map((appData) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF141414)
                                  : const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF1E1E1E)
                                      : const Color(0xFFEBEBEB)),
                            ),
                            child: Column(children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                                child: Row(children: [
                                  Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF222222)
                                          : const Color(0xFFF0F0F0),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Icon(Icons.apps_rounded,
                                        size: 15,
                                        color: isDark
                                            ? const Color(0xFF888888)
                                            : const Color(0xFF555555)),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(appData.appName.split('.').last,
                                      style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFFE8E8E8)
                                            : const Color(0xFF111111),
                                      )),
                                ]),
                              ),
                              ...appData.usageByType.entries.map((entry) =>
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(entry.key.displayName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? const Color(0xFF666666)
                                                : const Color(0xFF999999),
                                          )),
                                      Text(Util.formatDuration(entry.value),
                                          style: TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? const Color(0xFFE8E8E8)
                                                : const Color(0xFF111111),
                                          )),
                                    ],
                                  ),
                                )),
                            ]),
                          )),
                      const SizedBox(height: 6),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
// detailpage.dart end