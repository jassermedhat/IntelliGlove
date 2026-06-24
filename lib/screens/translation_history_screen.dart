import 'package:flutter/material.dart';

import '../components/app_async_state.dart';
import '../components/app_layout.dart';
import '../components/app_top_bar.dart';
import '../components/inputs.dart';
import '../components/toast.dart';
import '../components/translation_history_presenter.dart';
import '../models/load_status.dart';
import '../models/translation_record.dart';
import '../services/translation_controller.dart';
import '../theme/theme_provider.dart';

class TranslationHistoryScreen extends StatefulWidget {
  const TranslationHistoryScreen({super.key});

  @override
  State<TranslationHistoryScreen> createState() =>
      _TranslationHistoryScreenState();
}

class _TranslationHistoryScreenState extends State<TranslationHistoryScreen> {
  final _searchController = TextEditingController();
  TranslationController? _controller;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = TranslationControllerScope.of(context);
    if (_controller == controller) return;
    _controller?.removeListener(_refresh);
    _controller = controller..addListener(_refresh);
    // Always refetch when the screen is opened. The TranslationController is an
    // app-lifetime singleton, so gating on `LoadStatus.initial` would skip every
    // reload after the first open — meaning data added/seeded since (e.g. from the
    // admin panel) would never appear without an app restart. The early-return above
    // guarantees this runs once per mount, i.e. once per navigation to History.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.loadHistory();
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  List<TranslationRecord> get _filteredHistory {
    final history = _controller?.history ?? const [];
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return history;
    return history.where((record) {
      return record.text.toLowerCase().contains(query) ||
          (record.gestureLabel?.toLowerCase().contains(query) ?? false) ||
          record.languageCode.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Clear translation history?'),
        content: const Text('This removes every saved translation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final cleared = await _controller!.clearHistory();
    if (!mounted) return;
    if (cleared) {
      toast.success(
        title: 'History cleared',
        description: 'All translation history has been removed.',
      );
    } else {
      toast.error(
        title: 'Could not clear history',
        description: _controller!.historyError,
      );
    }
  }

  Future<void> _deleteRecord(TranslationRecord record) async {
    final deleted = await _controller!.deleteRecord(record.id);
    if (!mounted || deleted) return;
    toast.error(
      title: 'Could not delete translation',
      description: _controller!.historyError,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final controller = _controller!;
    final filtered = _filteredHistory;

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(title: 'Translation History', showBackButton: true),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppLayout.horizontalPadding(context),
                  24,
                  AppLayout.horizontalPadding(context),
                  AppLayout.bottomNavClearance(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Translations',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: t.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your complete gesture translation log',
                      style: TextStyle(color: t.mutedForeground),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppInput(
                            controller: _searchController,
                            hintText: 'Search translations...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 16,
                              color: t.mutedForeground,
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          tooltip: 'Clear history',
                          onPressed: controller.history.isEmpty
                              ? null
                              : _confirmClear,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: t.destructive,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (controller.historyStatus == LoadStatus.loading)
                      const AppLoadingState(
                        message: 'Loading translation history...',
                      )
                    else if (controller.historyStatus == LoadStatus.error)
                      AppErrorState(
                        message:
                            controller.historyError ??
                            'Translation history could not be loaded.',
                        onAction: controller.retryHistory,
                      )
                    else if (filtered.isEmpty)
                      AppEmptyState(
                        icon: Icons.access_time_rounded,
                        title: 'No translations found',
                        message: _query.isEmpty
                            ? 'Your translation history will appear here.'
                            : 'Try a different search term.',
                      )
                    else
                      ...groupTranslationHistory(filtered).map(
                        (group) => _HistoryGroup(
                          group: group,
                          onDelete: _deleteRecord,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryGroup extends StatelessWidget {
  const _HistoryGroup({required this.group, required this.onDelete});

  final TranslationHistoryGroup group;
  final ValueChanged<TranslationRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.mutedForeground,
                  letterSpacing: 1.8,
                ),
              ),
            ),
            Text(
              '${group.records.length} items',
              style: TextStyle(fontSize: 10, color: t.mutedForeground),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...group.records.map(
          (record) =>
              _HistoryRecord(record: record, onDelete: () => onDelete(record)),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _HistoryRecord extends StatelessWidget {
  const _HistoryRecord({required this.record, required this.onDelete});

  final TranslationRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: t.card,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Text(
              record.gestureIcon ?? '•',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Directionality(
                textDirection: record.isRtl
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: Column(
                  crossAxisAlignment: record.isRtl
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: t.foreground,
                      ),
                    ),
                    Text(
                      '${formatTranslationTime(record.createdAt)} • '
                      '${record.languageCode} • '
                      '${(record.confidence * 100).round()}%',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: t.mutedForeground),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Delete translation',
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: t.destructive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
