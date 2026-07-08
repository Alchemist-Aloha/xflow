import 'package:intl/intl.dart';

DateTime? parseTwitterDateTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return null;

  try {
    final format = DateFormat("EEE MMM dd HH:mm:ss Z yyyy", "en_US");
    return format.parse(dateStr);
  } catch (_) {
    return DateTime.tryParse(dateStr);
  }
}
