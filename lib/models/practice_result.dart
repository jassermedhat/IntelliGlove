class PracticeSessionInput {
  const PracticeSessionInput({
    required this.signId,
    required this.signName,
    required this.languageCode,
  });

  final String signId;
  final String signName;
  final String languageCode;
}

class PracticeResult {
  const PracticeResult({
    required this.id,
    required this.signId,
    required this.signName,
    required this.accuracy,
    required this.correct,
    required this.suggestion,
    required this.languageCode,
    required this.createdAt,
  });

  final String id;
  final String signId;
  final String signName;
  final int accuracy;
  final bool correct;
  final String suggestion;
  final String languageCode;
  final DateTime createdAt;
}

class PracticeStats {
  const PracticeStats({
    required this.totalPracticed,
    required this.averageAccuracy,
    required this.streak,
  });

  final int totalPracticed;
  final int averageAccuracy;
  final int streak;
}
