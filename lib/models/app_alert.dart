enum AppAlertType { info, success, warning, error }

class AppAlert {
  final String id;
  final String title;
  final String message;
  final AppAlertType type;
  final DateTime createdAt;
  final bool isRead;

  const AppAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  AppAlert copyWith({bool? isRead}) => AppAlert(
    id: id,
    title: title,
    message: message,
    type: type,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
  );
}
