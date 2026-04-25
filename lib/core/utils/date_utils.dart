import 'package:intl/intl.dart';

DateTime? parseTwitterDateTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return null;

  try {
    // Manual parse as primary (more reliable for Twitter legacy format)
    // Example: "Thu Apr 23 09:33:51 +0000 2026"
    final parts = dateStr.split(' ');
    if (parts.length >= 6) {
      final months = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12
      };

      final month = months[parts[1]];
      final day = int.tryParse(parts[2]);
      final timeParts = parts[3].split(':');
      final year = int.tryParse(parts[5]);

      if (month != null &&
          day != null &&
          year != null &&
          timeParts.length == 3) {
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        final second = int.tryParse(timeParts[2]) ?? 0;
        return DateTime.utc(year, month, day, hour, minute, second);
      }
    }
  } catch (_) {
    // Silently fall through to intl
  }

  try {
    // Fallback: Standard intl parsing
    final format = DateFormat("EEE MMM dd HH:mm:ss Z yyyy", "en_US");
    return format.parse(dateStr);
  } catch (_) {
    // Final fallback: try native parse
    return DateTime.tryParse(dateStr);
  }
}
