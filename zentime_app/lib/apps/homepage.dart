import './shared_imports.dart';
import 'package:http/http.dart' as http;

Future<void> sendTestFile() async {
  // OCI 서버의 공인 IP로 교체하세요
  final String serverIp = "146.56.175.74"; 
  final url = Uri.parse('http://$serverIp:8000/test-upload');

  try {
    // 1. Multipart 요청 생성
    var request = http.MultipartRequest('POST', url);

    // 2. 가상의 temp.txt 파일 생성 및 첨부
    request.files.add(
      http.MultipartFile.fromString(
        'file', 
        'Hello, world!', 
        filename: 'temp.txt',
      ),
    );

    print("전송 시작...");
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      print("전송 성공: ${response.body}");
    } else {
      print("전송 실패: ${response.statusCode}");
    }
  } catch (e) {
    print("에러 발생: $e");
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: Hive.box<UserAccountData>(DatabaseService.userBoxName).listenable(),
        builder: (context, Box<UserAccountData> box, _) {
          final account = box.get('profile');
          
          return Center(
            child: Column(
              children: [
                Text('환영합니다, ${account?.name ?? '사용자'}님!'),
                TextButton(onPressed: sendTestFile, child: Text('data 보내기'))
              ],
            )
          );
        },
      )
    );
  }
}