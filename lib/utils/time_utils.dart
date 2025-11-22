import 'package:intl/intl.dart';

class TimeUtils {
  static String formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      if (date.year == now.year) {
        return DateFormat('MMM d').format(date);
      } else {
        return DateFormat('MMM d, y').format(date);
      }
    }
  }
}
