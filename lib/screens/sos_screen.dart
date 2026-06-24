// sos_screen.dart

import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/overlays.dart';
import '../models/sos_models.dart';
import '../repositories/emergency_repository.dart';
import '../services/location_services.dart';
import '../components/toast.dart';
import '../services/emergency_contacts_controller.dart';
import '../services/sos_controller.dart';
import '../services/preferences_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Contact model
// ─────────────────────────────────────────────────────────────────────────────

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  late final EmergencyRepository _emergencyRepository;
  late final DeviceLocationPermissionService _locationPermission;
  late final EmergencyContactsController _contactsController;
  late final SosController _sosController;
  // Hold-for-3-seconds state

  // Mutable contact list — structured so persistence can be added to a
  // provider or local database without changing the UI logic.

  @override
  void initState() {
    super.initState();
    _emergencyRepository = LocalEmergencyRepository();
    _locationPermission = DeviceLocationPermissionService();
    _contactsController = EmergencyContactsController(
      repository: _emergencyRepository,
    )..addListener(_refresh);
    _sosController = SosController(
      emergencyRepository: _emergencyRepository,
      locationPermissionService: _locationPermission,
      locationRepository: const DeviceLocationRepository(),
      contactsController: _contactsController,
    )..addListener(_refresh);
    _contactsController.load();
  }

  @override
  void dispose() {
    _sosController
      ..removeListener(_refresh)
      ..dispose();
    _contactsController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  static const _howItems = [
    'Prepares your location locally for your emergency contacts',
    'Shares a current location snapshot for this SOS request',
    'Triggers vibration and visual alerts on your glove',
    'Can be activated via gesture or voice command',
  ];

  Future<void> _handleSOSPress() async {
    final allowed = await _showLocationExplanationOnce();
    if (!mounted) return;
    await _sosController.send(locationExplanationAccepted: allowed);
    _showSettingsActionIfNeeded();
  }

  Future<void> _retryPreparedRequest() async {
    await _sosController.retry();
    _showSettingsActionIfNeeded();
  }

  Future<bool> _showLocationExplanationOnce() async {
    final preferences = PreferencesScope.of(context);
    if (!await preferences.shouldShowLocationExplanation()) return true;
    if (!mounted) return false;
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: const Text('Location during SOS'),
            content: const Text(
              'IntelliGlove requests your current location only when you send an SOS, so it can be included for your emergency contacts.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (accepted) {
      final saved = await preferences.markLocationExplanationShown();
      if (!saved) {
        toast.warning(
          title: 'Preference not saved',
          description: 'This explanation may appear again next time.',
        );
      }
    }
    return accepted;
  }

  void _showSettingsActionIfNeeded() {
    if (!_sosController.requiresSettings || !mounted) return;
    toast.action(
      message:
          _sosController.failureReason ??
          'Open Settings to allow SOS location.',
      actionLabel: 'Open Settings',
      onAction: _locationPermission.openSettings,
    );
    _sosController.clearSettingsRequest();
  }

  // ── Hold-for-3-seconds SOS ─────────────────────────────────────────────────

  void _onHoldStart(PointerDownEvent _) {
    _sosController.startHold(onCompleted: _handleSOSPress);
  }

  void _onHoldEnd(PointerEvent _) {
    _sosController.releaseHold();
  }

  void _showGestureHelpDialog(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    showAppDialog(
      context: context,
      builder: (ctx) => AppDialogContent(
        onClose: () => Navigator.of(ctx).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppDialogHeader(
              title: const AppDialogTitle('SOS Gesture Sequence'),
              description: const AppDialogDescription(
                'Perform this gesture to trigger emergency mode',
              ),
            ),
            const SizedBox(height: 16),
            ...[
              (step: '1', title: 'Close Fist', desc: 'Hold for 1 second'),
              (step: '2', title: 'Open Palm', desc: 'Hold for 3 seconds'),
              (step: '3', title: 'Repeat 3 Times', desc: 'SOS will activate'),
            ].map(
              (g) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.destructive.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: t.destructive.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: t.destructive.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          g.step,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: t.destructive,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          g.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.foreground,
                          ),
                        ),
                        Text(
                          g.desc,
                          style: TextStyle(
                            fontSize: 11,
                            color: t.mutedForeground,
                          ),
                        ),
                      ],
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

  // ── Edit contacts bottom sheet ──────────────────────────────────────────────

  void _showEditContactsSheet(BuildContext context) {
    _contactsController.beginEditing();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditContactsSheet(controller: _contactsController),
    ).whenComplete(() {
      if (_contactsController.isEditing) {
        _contactsController.cancelEditing();
      }
    });
  }

  // ── Phone call stub ─────────────────────────────────────────────────────────

  Future<void> _onCallContact(BuildContext context, EmergencyContact c) async {
    final uri = Uri(scheme: 'tel', path: c.phone);
    final supported = await canLaunchUrl(uri);
    if (supported &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (!context.mounted) return;
    toast.error(
      title: 'Call unavailable',
      description: 'This device cannot open the phone dialer.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: _Orb(
              color: t.destructive.withValues(alpha: 0.05),
              size: 320,
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.33,
            left: -100,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 240),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Container(
                  constraints: BoxConstraints(
                    minHeight: AppLayout.topBarHeight(context),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: t.background.withValues(alpha: 0.75),
                    border: Border(
                      bottom: BorderSide(
                        color: t.border.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.destructive.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: t.destructive,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SOS',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: t.foreground,
                            ),
                          ),
                          Text(
                            'Emergency',
                            style: TextStyle(
                              fontSize: 10,
                              color: t.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      AppButton.icon(
                        icon: const Icon(Icons.back_hand_outlined, size: 18),
                        variant: AppButtonVariant.ghost,
                        onPressed: () => _showGestureHelpDialog(context),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      AppLayout.bottomNavClearance(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 4,
                              decoration: BoxDecoration(
                                color: t.destructive,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'EMERGENCY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: t.destructive,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: t.foreground,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                            children: [
                              const TextSpan(text: 'Quick\n'),
                              TextSpan(
                                text: 'Assistance',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: t.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the SOS button or use the configured gesture to prepare a local emergency record.',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.mutedForeground,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SOS button card
                        _SOSButtonCard(
                          t: t,
                          isDark: isDark,
                          isActive: _sosController.state == SosState.sending,
                          holdProgress: _sosController.holdProgress,
                          onPress: _handleSOSPress,
                          onHoldStart: _onHoldStart,
                          onHoldEnd: _onHoldEnd,
                        ),
                        if (_sosController.state == SosState.success) ...[
                          const SizedBox(height: 12),
                          Text(
                            'SOS prepared locally.',
                            style: TextStyle(
                              color: t.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: _sosController.cancel,
                            child: const Text('Done'),
                          ),
                        ],
                        if (_sosController.state == SosState.failed) ...[
                          const SizedBox(height: 12),
                          Text(
                            _sosController.failureReason ??
                                'SOS could not be sent.',
                            style: TextStyle(color: t.destructive),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  onPressed: _sosController.isRetrying
                                      ? null
                                      : _retryPreparedRequest,
                                  child: const Text('Retry'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppButton(
                                  variant: AppButtonVariant.outline,
                                  onPressed: _sosController.cancel,
                                  child: const Text('Cancel'),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Location card
                        _LocationCard(
                          t: t,
                          latitude: _sosController.latitude,
                          longitude: _sosController.longitude,
                        ),
                        const SizedBox(height: 20),

                        // Emergency contacts header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: t.accent.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'EMERGENCY CONTACTS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: t.mutedForeground,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                            // Functional Edit button — opens management bottom sheet
                            GestureDetector(
                              onTap: () => _showEditContactsSheet(context),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: t.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 12,
                                    color: t.accent,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Contact cards with phone icon on the LEFT
                        ..._contactsController.contacts.map(
                          (c) => _ContactCard(
                            t: t,
                            contact: c,
                            onCall: () => _onCallContact(context, c),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // How it works
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: t.destructive.withValues(alpha: 0.2),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                t.destructive.withValues(
                                  alpha: isDark ? 0.08 : 0.04,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: t.destructive,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'How SOS Works',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: t.foreground,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ..._howItems.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.only(top: 5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: t.destructive,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: t.mutedForeground,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Contact Card — phone button on the LEFT
// ─────────────────────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final AppColorTokens t;
  final EmergencyContact contact;
  final VoidCallback onCall;
  const _ContactCard({
    required this.t,
    required this.contact,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 4, color: t.destructive.withValues(alpha: 0.4)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Phone button — LEFT side
                  AppButton.icon(
                    icon: Icon(
                      Icons.phone_rounded,
                      size: 14,
                      color: t.foreground,
                    ),
                    variant: AppButtonVariant.outline,
                    onPressed: onCall,
                  ),
                  const SizedBox(width: 12),
                  // Contact info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          contact.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.foreground,
                          ),
                        ),
                        Text(
                          contact.phone,
                          style: TextStyle(
                            fontSize: 11,
                            color: t.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Edit contacts bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditContactsSheet extends StatefulWidget {
  final EmergencyContactsController controller;

  const _EditContactsSheet({required this.controller});

  @override
  State<_EditContactsSheet> createState() => _EditContactsSheetState();
}

class _EditContactsSheetState extends State<_EditContactsSheet> {
  final Map<int, TextEditingController> _nameControllers = {};
  final Map<int, TextEditingController> _phoneControllers = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _syncTextControllers();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final controller in _phoneControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(_syncTextControllers);
  }

  void _syncTextControllers() {
    final ids = widget.controller.draftContacts
        .map((contact) => contact.id)
        .toSet();
    for (final contact in widget.controller.draftContacts) {
      _nameControllers.putIfAbsent(
        contact.id,
        () => TextEditingController(text: contact.name),
      );
      _phoneControllers.putIfAbsent(
        contact.id,
        () => TextEditingController(text: contact.phone),
      );
    }
    for (final id
        in _nameControllers.keys.where((id) => !ids.contains(id)).toList()) {
      _nameControllers.remove(id)?.dispose();
      _phoneControllers.remove(id)?.dispose();
    }
  }

  void _addContact() {
    widget.controller.addDraft();
  }

  void _removeContact(int id) {
    widget.controller.removeDraft(id);
  }

  Future<void> _save() async {
    for (final contact in widget.controller.draftContacts) {
      widget.controller.updateDraft(
        contact.id,
        name: _nameControllers[contact.id]!.text,
        phone: _phoneControllers[contact.id]!.text,
        relationship: contact.relationship,
      );
    }
    final saved = await widget.controller.saveEdits();
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      toast.error(
        title: 'Contacts not saved',
        description: widget.controller.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: t.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: t.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stackHeader =
                          constraints.maxWidth < 420 ||
                          MediaQuery.textScalerOf(context).scale(16) > 24;
                      final title = Text(
                        'Emergency Contacts',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: t.foreground,
                        ),
                      );
                      final actions = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              widget.controller.cancelEditing();
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: t.mutedForeground),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: _save,
                            child: Text(
                              'Save',
                              style: TextStyle(
                                color: t.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      );
                      if (stackHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            title,
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: actions,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: title),
                          actions,
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // Contact list
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: widget.controller.draftContacts.length + 1,
                    itemBuilder: (_, i) {
                      final contacts = widget.controller.draftContacts;
                      if (i == contacts.length) {
                        // Add contact row
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: _addContact,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: t.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: t.accent.withValues(alpha: 0.3),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: t.accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Add Contact',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: t.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      final contact = contacts[i];
                      return _ContactEditorRow(
                        t: t,
                        nameCtrl: _nameControllers[contact.id]!,
                        phoneCtrl: _phoneControllers[contact.id]!,
                        onDelete: () => _removeContact(contact.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContactEditorRow extends StatelessWidget {
  final AppColorTokens t;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final VoidCallback onDelete;
  const _ContactEditorRow({
    required this.t,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  style: TextStyle(fontSize: 13, color: t.foreground),
                  decoration: InputDecoration(
                    hintText: 'Name',
                    hintStyle: TextStyle(color: t.mutedForeground),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: t.border.withValues(alpha: 0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: t.border.withValues(alpha: 0.4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.accent, width: 1.5),
                    ),
                    fillColor: t.background,
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: t.destructive,
                ),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(fontSize: 13, color: t.foreground),
            decoration: InputDecoration(
              hintText: 'Phone number',
              hintStyle: TextStyle(color: t.mutedForeground),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              prefixIcon: Icon(
                Icons.phone_outlined,
                size: 14,
                color: t.mutedForeground,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 36),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.border.withValues(alpha: 0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.border.withValues(alpha: 0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.accent, width: 1.5),
              ),
              fillColor: t.background,
              filled: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SOS button card
// ─────────────────────────────────────────────────────────────────────────────

class _SOSButtonCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final bool isActive;
  final double holdProgress; // 0.0 → 1.0
  final VoidCallback onPress;
  final void Function(PointerDownEvent) onHoldStart;
  final void Function(PointerEvent) onHoldEnd;
  const _SOSButtonCard({
    required this.t,
    required this.isDark,
    required this.isActive,
    required this.holdProgress,
    required this.onPress,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.destructive.withValues(alpha: 0.2)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.destructive.withValues(alpha: isDark ? 0.12 : 0.06),
            t.destructive.withValues(alpha: isDark ? 0.08 : 0.04),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: MediaQuery.sizeOf(context).height < 680 ? 20 : 40,
            horizontal: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Listener(
                onPointerDown: isActive ? null : onHoldStart,
                onPointerUp: onHoldEnd,
                onPointerCancel: onHoldEnd,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress ring — visible while holding
                    if (holdProgress > 0)
                      SizedBox(
                        width: 156,
                        height: 156,
                        child: CircularProgressIndicator(
                          value: holdProgress,
                          strokeWidth: 5,
                          color: t.destructive,
                          backgroundColor: t.destructive.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.destructive,
                        boxShadow: [
                          BoxShadow(
                            color: t.destructive.withValues(
                              alpha: isActive
                                  ? 0.5
                                  : holdProgress > 0
                                  ? 0.4
                                  : 0.3,
                            ),
                            blurRadius: isActive ? 32 : 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive
                                  ? Icons.phone_in_talk_rounded
                                  : Icons.phone_rounded,
                              size: 44,
                              color: AppColors.white,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              () {
                                if (isActive) return 'Sending...';
                                if (holdProgress <= 0) return 'SOS';
                                final sec = (holdProgress * 3).ceil().clamp(
                                  1,
                                  3,
                                );
                                return 'Hold $sec';
                              }(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Hold the SOS button for 3 seconds to activate emergency mode',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: t.mutedForeground,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Location card
// ─────────────────────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final AppColorTokens t;
  final double? latitude;
  final double? longitude;
  const _LocationCard({
    required this.t,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation = latitude != null && longitude != null;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 4, color: t.accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.location_pin,
                        size: 22,
                        color: t.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Current Location',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: t.foreground,
                          ),
                        ),
                        Text(
                          hasLocation
                              ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
                              : 'Location is fetched only when SOS is sent',
                          style: TextStyle(
                            fontSize: 11,
                            color: t.mutedForeground,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.accent.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              hasLocation
                                  ? 'Location prepared'
                                  : 'Not requested',
                              style: TextStyle(
                                fontSize: 10,
                                color: t.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
