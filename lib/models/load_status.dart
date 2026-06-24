// lib/models/load_status.dart
// Standardized async load state used across all backend-facing screens.

enum LoadStatus {
  /// Not yet started — initial widget build before any async call.
  initial,

  /// Async call in progress.
  loading,

  /// Data loaded successfully; content is valid.
  success,

  /// Call succeeded but returned zero items.
  empty,

  /// Call failed; an error message should be shown.
  error,
}
