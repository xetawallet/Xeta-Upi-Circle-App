DateTime? parseLocalTimestamp(String iso) {
  return DateTime.tryParse(iso)?.toLocal();
}

String formatTransactionDate(String iso) {
  final dateTime = parseLocalTimestamp(iso);
  if (dateTime == null) {
    return iso;
  }

  return '${dateTime.day} ${_monthNames[dateTime.month - 1]} ${dateTime.year}';
}

String formatTransactionTime(String iso) {
  final dateTime = parseLocalTimestamp(iso);
  if (dateTime == null) {
    return iso;
  }

  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String formatTransactionTimestamp(String iso) {
  final date = formatTransactionDate(iso);
  final time = formatTransactionTime(iso);
  if (date == iso || time == iso) {
    return iso;
  }
  return '$date, $time';
}

const _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
