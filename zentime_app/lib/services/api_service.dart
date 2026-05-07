import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List<dynamic>> fetchRanking(String date, int usageType) async {
  final response = await http.get(
    Uri.parse('http://146.56.175.74:8000/ranking?target_date=$date&usage_type=$usageType'),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('랭킹 로드 실패');
  }
}

Future<List<dynamic>> fetchComparison(String user_id, String date, int usageType) async {
  final response = await http.get(
    Uri.parse('http://146.56.175.74:8000/compare-friends?user_id=$user_id&target_date=$date&usage_type=$usageType'),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('비교 로드 실패');
  }
}