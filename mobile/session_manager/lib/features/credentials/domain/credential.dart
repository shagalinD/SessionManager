/// Saved credential (password may be absent when listing).
class Credential {
  const Credential({
    required this.id,
    required this.url,
    required this.login,
    this.password,
  });

  final String id;
  final String url;
  final String login;
  final String? password;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'login': login,
        if (password != null) 'password': password,
      };

  factory Credential.fromJson(Map<String, dynamic> json) {
    return Credential(
      id: json['id'] as String,
      url: json['url'] as String,
      login: json['login'] as String,
      password: json['password'] as String?,
    );
  }
}
