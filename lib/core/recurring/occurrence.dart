import 'package:coinly/core/constants/enums.dart';

String recurringOccurrenceKey(int ruleId, DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return '$ruleId:${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

DateTime nextRecurringOccurrence(DateTime date, RecurrenceType recurrence) {
  switch (recurrence) {
    case RecurrenceType.daily:
      return date.add(const Duration(days: 1));
    case RecurrenceType.weekly:
      return date.add(const Duration(days: 7));
    case RecurrenceType.biweekly:
      return date.add(const Duration(days: 14));
    case RecurrenceType.monthly:
      final nextMonth = DateTime(date.year, date.month + 1, 1);
      final maxDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      return DateTime(
        nextMonth.year,
        nextMonth.month,
        date.day.clamp(1, maxDay),
      );
    case RecurrenceType.yearly:
      final maxDay = DateTime(date.year + 1, date.month + 1, 0).day;
      return DateTime(date.year + 1, date.month, date.day.clamp(1, maxDay));
  }
}

Iterable<DateTime> recurringOccurrencesBetween({
  required DateTime startDate,
  required RecurrenceType recurrence,
  required DateTime endDate,
  DateTime? after,
  bool includeStart = true,
}) sync* {
  var occurrence = startDate;
  if (!includeStart) {
    occurrence = nextRecurringOccurrence(occurrence, recurrence);
  }
  while (after != null && !occurrence.isAfter(after)) {
    occurrence = nextRecurringOccurrence(occurrence, recurrence);
  }
  while (!occurrence.isAfter(endDate)) {
    yield occurrence;
    occurrence = nextRecurringOccurrence(occurrence, recurrence);
  }
}
