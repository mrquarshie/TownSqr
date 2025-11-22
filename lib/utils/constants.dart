class Constants {
  // Change this to your server URL
  static const String serverUrl = 'http://10.113.116.65:3000';

  static const List<School> schools = [
    School(
      value: 'central university',
      name: 'Central University',
      emoji: '🏛️',
    ),
    School(
      value: 'ashesi university',
      name: 'Ashesi University',
      emoji: '🎓',
    ),
    School(value: 'knust', name: 'KNUST', emoji: '📚'),
    School(
      value: 'university of ghana',
      name: 'University of Ghana',
      emoji: '🏫',
    ),
    School(value: 'upsa', name: 'UPSA', emoji: '🎯'),
  ];

  static const List<Room> rooms = [
    Room(value: 'general', name: 'General', emoji: '💬'),
    Room(
      value: 'central university',
      name: 'Central University',
      emoji: '🏛️',
    ),
    Room(
      value: 'ashesi university',
      name: 'Ashesi University',
      emoji: '🎓',
    ),
    Room(value: 'knust', name: 'KNUST', emoji: '📚'),
    Room(
      value: 'university of ghana',
      name: 'University of Ghana',
      emoji: '🏫',
    ),
    Room(value: 'upsa', name: 'UPSA', emoji: '🎯'),
  ];

  static String getSchoolEmoji(String school) {
    return schools
        .firstWhere(
          (s) => s.value == school,
          orElse: () =>
              const School(value: '', name: '', emoji: '🏫'),
        )
        .emoji;
  }

  static String getSchoolName(String school) {
    if (school == 'general') return 'General';
    return schools
        .firstWhere(
          (s) => s.value == school,
          orElse: () =>
              School(value: school, name: school, emoji: ''),
        )
        .name;
  }
}

class School {
  final String value;
  final String name;
  final String emoji;

  const School({
    required this.value,
    required this.name,
    required this.emoji,
  });
}

class Room {
  final String value;
  final String name;
  final String emoji;

  const Room({
    required this.value,
    required this.name,
    required this.emoji,
  });
}
