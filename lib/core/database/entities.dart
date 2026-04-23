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

class Subscription {
  final String id;
  final String screenName;
  final String name;
  final String? profileImageUrl;
  final String? description;
  final int? followersCount;
  final int? followingCount;

  Subscription({
    required this.id,
    required this.screenName,
    required this.name,
    this.profileImageUrl,
    this.description,
    this.followersCount,
    this.followingCount,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'screen_name': screenName,
    'name': name,
    'profile_image_url': profileImageUrl,
    'description': description,
    'followers_count': followersCount,
    'following_count': followingCount,
  };

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'],
      screenName: map['screen_name'],
      name: map['name'],
      profileImageUrl: map['profile_image_url'],
      description: map['description'],
      followersCount: map['followers_count'],
      followingCount: map['following_count'],
    );
  }
}
