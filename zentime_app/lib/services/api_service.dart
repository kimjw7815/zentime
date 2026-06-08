// api_service.dart start
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zentime/apps/shared_imports.dart';
import '../models/models.dart';
import 'database_service.dart';

// 박스를 열지 않고 토큰을 직접 받아 호출
Future<List<dynamic>> fetchRanking(String date, int usageType, String? token) async {
  print("[main isolate] fetchRanking 호출");
  final response = await http.get(
    Uri.parse('http://146.56.175.74:8000/ranking?target_date=$date&usage_type=$usageType'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    print("[main isolate] fetchRanking 성공, ${response.body}");
    return jsonDecode(response.body);
  } else {
    print("[main isolate] fetchRanking 실패");
    throw Exception('랭킹 로드 실패: ${response.statusCode}');
  }
}

Future<List<dynamic>> fetchComparison(String date, int usageType, String? token) async {
  final response = await http.get(
    Uri.parse('http://146.56.175.74:8000/compare-friends?target_date=$date&usage_type=$usageType'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    print("에러 바디: ${response.body}");
    throw Exception('비교 로드 실패: ${response.statusCode}');
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
        themeModeIndex: userMap['theme_mode'] ?? 0, // 기본값 설정 (추후 테마 변경 시 업데이트)
      );
      var userBox = await Hive.openBox<UserAccountData>(DatabaseService.userBoxName);
      await userBox.put('profile', userAccount);
      await userBox.close();

      print("[main isolate] [api service] 백엔드 로그인 성공! JWT 토큰: ${responseData['access_token']}, id: ${userMap['id']}");
      
      try {
        print("[main isolate] [api service] get-user-usage 접근 시도 1");
        final userUsageGetUrl = Uri.parse('http://146.56.175.74:8000/get-user-usage');
        final userUsageGetResponse = await http.get(
          userUsageGetUrl,
          headers: {'Authorization': 'Bearer $jwtToken'},
        );
        print("[main isolate] [api service] get-user-usage 접근 시도 2");

        if (userUsageGetResponse.statusCode == 200) {
          final List<dynamic> serverUsages = jsonDecode(userUsageGetResponse.body);
          
          var usageBox = await Hive.openBox(DatabaseService.usageBoxName);
          await usageBox.clear(); // 기존 로컬 데이터 초기화

          // 💡 1. 날짜별로 데이터를 분류하기 위한 Map 생성 (Key: 날짜 문자열, Value: AppUsageData 리스트)
          final Map<String, List<AppUsageData>> groupedUsages = {};

          for (var item in serverUsages) {
            // 💡 2. 서버 백엔드 API가 주는 날짜 키값을 확인하세요. (예: 'target_date' 또는 'targetDate')
            // 테이블 컬럼명이 target_date이므로 JSON도 target_date일 확률이 높습니다.
            final String dateKey = item['target_date'] ?? item['targetDate'] ?? DateTime.now().toIso8601String().split('T')[0];
            
            final String appName = item['appName'] ?? item['app_name'];
            
            // 백엔드 JSON 필드명 확인 필요 ('usageByType' 또는 'usage_data')
            final Map<String, dynamic> serverUsageByType = Map<String, dynamic>.from(item['usageByType'] ?? item['usage_data']);

            // Enum 역변환 로직
            final Map<UsageType, int> usageByType = {};
            serverUsageByType.forEach((key, value) {
              final int index = int.parse(key);
              if (index >= 0 && index < UsageType.values.length) {
                usageByType[UsageType.values[index]] = (value as num).toInt();
              }
            });

            final appUsageData = AppUsageData(appName: appName, usageByType: usageByType);
            
            // 💡 3. 해당 날짜(dateKey)의 리스트가 없으면 만들고, 있으면 기존 리스트에 추가
            groupedUsages.putIfAbsent(dateKey, () => []).add(appUsageData);
          }

          // 💡 4. 날짜별로 이쁘게 모인 그룹들을 Hive에 각각의 날짜 키값으로 주입!
          for (var entry in groupedUsages.entries) {
            await usageBox.put(entry.key, entry.value);
            print("[main isolate] [Hive 저장] 날짜: ${entry.key} -> 데이터 ${entry.value.length}개 주입 완료");
          }

          await usageBox.close();
          print("[main isolate] [api service] OCI 서버 사용량 데이터 로컬 복원 완료!");
        }
      } catch (syncError) {
        print("[main isolate] [api service] 서버 데이터 복원 중 에러 발생 (로그인은 유지): $syncError");
      }
      
      return true;
    } else {
      print("[main isolate] [api service] 백엔드 인증 실패: ${response.statusCode}");
      return false;
    }

  } catch (error) {
    print("[main isolate] [api service] 구글 로그인 에러: $error");
    return false;
  }
}

Future<bool> sendDataToServer() async {
  // 1. Hive 박스 안전하게 열기
  final userBox = await Hive.openBox<UserAccountData>(DatabaseService.userBoxName);
  final usageBox = await Hive.openBox<List<dynamic>>(DatabaseService.usageBoxName);

  try {
    final profile = userBox.get('profile');
    if (profile == null) {
      print("❌ 전송 실패: 유저 프로필 데이터가 없습니다.");
      return false;
    }

    // 2. usageBox에 쌓인 로컬 정제 데이터를 백엔드 구조에 맞게 변환
    List<Map<String, dynamic>> usageListJson = [];
    
    for (var key in usageBox.keys) {
      final rawList = usageBox.get(key);
      if (rawList != null) {
        for (var item in rawList) {
          if (item is AppUsageData) {
            Map<String, int> formattedUsageByType = {};
            item.usageByType.forEach((type, value) {
              formattedUsageByType[type.index.toString()] = value;
            });

            usageListJson.add({
              'appName': item.appName,
              'usageByType': formattedUsageByType,
            });
          }
        }
      }
    }

    // 3. 최종 전송용 JSON 구조 조립
    final Map<String, dynamic> syncPayload = {
      'userId': profile.id,
      'name': profile.name,
      'email': profile.email,
      'themeModeIndex': profile.themeModeIndex,
      'usageList': usageListJson,
    };

    // 4. 서버 통신 엔드포인트 타격
    final String serverIp = "146.56.175.74"; 
    final url = Uri.parse('http://$serverIp:8000/sync-usage');

    print("🚀 [api_service] 진짜 데이터 전송 시작...");
    
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(syncPayload),
    );

    if (response.statusCode == 200) {
      print("🟢 [api_service] 전송 성공: ${response.body}");
      return true; // 👈 성공 시 true 반환
    } else {
      print("❌ [api_service] 전송 실패 (상태코드): ${response.statusCode} | 바디: ${response.body}");
      return false; // 👈 실패 시 false 반환
    }
  } catch (e) {
    print("❌ [api_service] 전송 중 예외 에러 발생: $e");
    return false;
  } finally {
    // 5. 자원 반환
    await userBox.close();
    await usageBox.close();
  }
}

// api_service.dart end