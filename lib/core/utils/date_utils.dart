import 'package:intl/intl.dart';
import 'app_logger.dart';

DateTime? parseTwitterDateTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return null;

  try {
    // Standard format: "Thu Apr 23 09:33:51 +0000 2026"
    // Using a more lenient parsing if standard fails
    final format = DateFormat("EEE MMM dd HH:mm:ss Z yyyy", "en_US");
    return format.parse(dateStr);
  } catch (e) {
    AppLogger.log('XFLOW: intl parsing failed, trying manual: $e');
    try {
      // Manual parse as fallback
      // Thu Apr 23 09:33:51 +0000 2026
      final parts = dateStr.split(' ');
      if (parts.length < 6) return null;

      final months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
      };

      final month = months[parts[1]] ?? 1;
      final day = int.parse(parts[2]);
      final timeParts = parts[3].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = int.parse(timeParts[2]);
      final year = int.parse(parts[5]);

      return DateTime.utc(year, month, day, hour, minute, second);
    } catch (e2) {
      AppLogger.log('XFLOW: Manual parsing also failed for $dateStr: $e2');
      return null;
    }
  }
}
