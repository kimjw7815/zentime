class Util {
    static String formatDuration(int seconds) {
    if (seconds <= 0) return '0초';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours시간 $minutes분 $remainingSeconds초';
    } else if (minutes > 0) {
      return '$minutes분 $remainingSeconds초';
    } else {
      return '$remainingSeconds초';
    }
  }

  static int calculateWastedMoney(int seconds) {
  if (seconds <= 0) return 0;

  // 2026년 최저시급: 10,300원
  const int minimumWagePerHour = 10300; 

  // 초 ➡️ 시간 환산 (seconds / 3600) 후 최저시급 곱하기
  double wastedHours = seconds / (60 * 60);
  
  // 원 단위로 깔끔하게 반올림
  return (wastedHours * minimumWagePerHour).round();
}
}