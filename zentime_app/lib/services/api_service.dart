// api_service.dart start
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import 'database_service.dart';

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

Future<bool> loginWithGoogleAndBackend() async {
  try {
    // 1. 구글 로그인 요청
    // iOS의 경우 별도 설정 없이 작동하지만, 웹/기타 환경에선 clientId를 지정해야 할 수 있습니다.
    await GoogleSignIn.instance.initialize(
      serverClientId: '1021352283625-i9bb25dovfalon0024rvk14b33uqah2h.apps.googleusercontent.com',
    );
    
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      print("[main isolate] 이 플랫폼에서는 구글 인증을 지원하지 않습니다.");
      return false;
    }
    // 1021352283625-i9bb25dovfalon0024rvk14b33uqah2h.apps.googleusercontent.com
    
    final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate(
      scopeHint: ['email', 'profile'],
    );

    if (googleUser == null) {
      print("[main isolate] 사용자가 로그인을 취소함");
      return false;
    }

    // 2. 구글 인증 정보에서 idToken 가져오기
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final String? idToken = googleAuth.idToken; // 🔑 이게 핵심입니다.

    if (idToken == null) {
      print("[main isolate] idToken을 가져오는데 실패했습니다.");
      return false;
    }

    // 3. OCI 백엔드 서버로 idToken 전송하기
    final url = Uri.parse('http://146.56.175.74:8000/api/v1/auth/google');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      String jwtToken = responseData['access_token'];
      var authBox = await Hive.openBox('authBox');
      await authBox.put('jwt_token', jwtToken);
      await authBox.close();

      final userMap = responseData['user'];
      final userAccount = UserAccountData(
        id: userMap['id'],
        name: userMap['name'],
        email: userMap['email'],
        themeModeIndex: 1, // 기본값 설정 (추후 테마 변경 시 업데이트)
      );
      var userBox = await Hive.openBox<UserAccountData>(DatabaseService.userBoxName);
      await userBox.put('profile', userAccount);
      await userBox.close();
      
      print("[main isolate] 백엔드 로그인 성공! JWT 토큰: ${responseData['access_token']}, id: ${userMap['id']}");
      
      return true;
    } else {
      print("[main isolate] 백엔드 인증 실패: ${response.statusCode}");
      return false;
    }

  } catch (error) {
    print("[main isolate] 구글 로그인 에러: $error");
    return false;
  }
}
// api_service.dart end