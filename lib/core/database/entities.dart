class Account {
  final String id;
  final String screenName;
  final String authHeader;

  Account({
    required this.id,
    required this.screenName,
    required this.authHeader,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'screen_name': screenName,
    'auth_header': authHeader,
  };

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      screenName: map['screen_name'],
      authHeader: map['auth_header'],
    );
  }
}
