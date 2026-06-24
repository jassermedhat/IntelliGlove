import '../models/translation_record.dart';

class TranslationHistoryGroup {
  const TranslationHistoryGroup({required this.label, required this.records});

  final String label;
  final List<TranslationRecord> records;
}

List<TranslationHistoryGroup> groupTranslationHistory(
  List<TranslationRecord> records, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final todayRecords = <TranslationRecord>[];
  final yesterdayRecords = <TranslationRecord>[];
  final earlierRecords = <TranslationRecord>[];

  for (final record in records) {
    final created = record.createdAt.toLocal();
    final date = DateTime(created.year, created.month, created.day);
    if (date == today) {
      todayRecords.add(record);
    } else if (date == yesterday) {
      yesterdayRecords.add(record);
    } else {
      earlierRecords.add(record);
    }
  }

  return [
    if (todayRecords.isNotEmpty)
      TranslationHistoryGroup(label: 'Today', records: todayRecords),
    if (yesterdayRecords.isNotEmpty)
      TranslationHistoryGroup(label: 'Yesterday', records: yesterdayRecords),
    if (earlierRecords.isNotEmpty)
      TranslationHistoryGroup(label: 'Earlier', records: earlierRecords),
  ];
}

String formatTranslationTime(DateTime createdAt, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = createdAt.toLocal();
  final difference = current.difference(local);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  return '${local.month}/${local.day}/${local.year}';
}
