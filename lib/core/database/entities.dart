class Account {
  final String id;
  final String screenName;
  final String restId;
  final String authHeader;

  Account({
    required this.id,
    required this.screenName,
    required this.restId,
    required this.authHeader,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'screen_name': screenName,
    'rest_id': restId,
    'auth_header': authHeader,
  };

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      screenName: map['screen_name'],
      restId: map['rest_id'] ?? '',
      authHeader: map['auth_header'],
    );
  }
}
