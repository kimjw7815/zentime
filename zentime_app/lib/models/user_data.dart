class UserAccountData {
  final String id;
  final String name;
  final String email;
  
  UserAccountData({
    required this.id,
    required this.name,
    required this.email
  });

  factory UserAccountData.fromJson(Map<String, dynamic> json) {
    return UserAccountData(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}