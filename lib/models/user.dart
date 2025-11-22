class User {
  final String username;
  final String displayName;
  final String? avatar;
  final String school;

  User({
    required this.username,
    required this.displayName,
    this.avatar,
    required this.school,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      avatar: json['avatar'] as String?,
      school: json['school'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'displayName': displayName,
      'avatar': avatar,
      'school': school,
    };
  }
}

class Post {
  final String id;
  final String sender;
  final String displayName;
  final String? avatar;
  final String content;
  final String? imageUrl;
  final String room;
  final int timestamp;
  final List<Reply> replies;

  Post({
    required this.id,
    required this.sender,
    required this.displayName,
    this.avatar,
    required this.content,
    this.imageUrl,
    required this.room,
    required this.timestamp,
    this.replies = const [],
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      sender: json['sender'] as String,
      displayName: json['displayName'] as String,
      avatar: json['avatar'] as String?,
      content: json['content'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      room: json['room'] as String,
      timestamp: json['timestamp'] as int,
      replies:
          (json['replies'] as List?)
              ?.map((r) => Reply.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Reply {
  final String id;
  final String sender;
  final String displayName;
  final String? avatar;
  final String content;
  final String? imageUrl;
  final int timestamp;

  Reply({
    required this.id,
    required this.sender,
    required this.displayName,
    this.avatar,
    required this.content,
    this.imageUrl,
    required this.timestamp,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      id: json['id'] as String,
      sender: json['sender'] as String,
      displayName: json['displayName'] as String,
      avatar: json['avatar'] as String?,
      content: json['content'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      timestamp: json['timestamp'] as int,
    );
  }
}
