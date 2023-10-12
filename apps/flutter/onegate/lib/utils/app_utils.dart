import 'package:intl/intl.dart';

class Utils {
  static String convertDateTimeFormat(DateTime inputDateTime) {
    DateTime today = DateTime.now();
    DateTime yesterday = DateTime.now().subtract(Duration(days: 1));

    String formattedDateTime;

    if (inputDateTime.year == today.year &&
        inputDateTime.month == today.month &&
        inputDateTime.day == today.day) {
      // Today's date
      formattedDateTime = DateFormat('HH:mm a').format(inputDateTime);
    } else if (inputDateTime.year == yesterday.year &&
        inputDateTime.month == yesterday.month &&
        inputDateTime.day == yesterday.day) {
      // Yesterday's date
      formattedDateTime = DateFormat('HH:mm a').format(inputDateTime) +
          ' ' +
          DateFormat('dd-MM').format(inputDateTime);
    } else {
      // Any other date
      formattedDateTime = DateFormat('HH:mm a dd-MM').format(inputDateTime);
    }

    return formattedDateTime;
  }
}
