class TranslationRecord {
  const TranslationRecord({
    required this.id,
    required this.text,
    required this.languageCode,
    required this.confidence,
    required this.createdAt,
    this.gestureLabel,
    this.gestureIcon,
  });

  final String id;
  final String text;
  final String? gestureLabel;
  final String? gestureIcon;
  final String languageCode;
  final double confidence;
  final DateTime createdAt;

  bool get isRtl => languageCode.toLowerCase().startsWith('ar');

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'gestureLabel': gestureLabel,
    'gestureIcon': gestureIcon,
    'languageCode': languageCode,
    'confidence': confidence,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TranslationRecord.fromJson(Map<String, Object?> json) {
    return TranslationRecord(
      id: json['id']! as String,
      text: json['text']! as String,
      gestureLabel: json['gestureLabel'] as String?,
      gestureIcon: json['gestureIcon'] as String?,
      languageCode: json['languageCode']! as String,
      confidence: (json['confidence']! as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
  }
}
