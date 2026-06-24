//
// // ── App Card Section (The Shadcn-style UI) ──
// // Text('Project Overview',
// //     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.foreground)),
// // const SizedBox(height: 16),
//
// // AppCard(
// //   child: Column(
// //     children: [
// //       AppCardHeader(
// //         title: const AppCardTitle('Analytics Dashboard'),
// //         description: const AppCardDescription('Visualizing user retention and growth.'),
// //         trailing: Icon(Icons.insights, color: t.primary),
// //       ),
// //       AppCardContent(
// //         child: Container(
// //           height: 100,
// //           width: double.infinity,
// //           decoration: BoxDecoration(
// //             color: t.muted.withValues(alpha: 0.2),
// //             borderRadius: BorderRadius.circular(12),
// //             border: Border.all(color: t.border.withValues(alpha: 0.5)),
// //           ),
// //           child: Center(child: Text('Chart Placeholder', style: TextStyle(color: t.mutedForeground))),
// //         ),
// //       ),
// //       AppCardFooter(
// //         mainAxisAlignment: MainAxisAlignment.end,
// //         children: [
// //           OutlinedButton(onPressed: () {}, child: const Text('Export')),
// //           const SizedBox(width: 8),
// //           ElevatedButton(onPressed: () {}, child: const Text('Details')),
// //         ],
// //       ),
// //     ],
// //   ),
// // ),
// //
// // const SizedBox(height: 16),
//
// // // Example of a simple clickable AppCard
// // AppCard(
// //   onTap: () {},
// //   padding: const EdgeInsets.all(20),
// //   child: Row(
// //     children: [
// //       Icon(Icons.info_outline, color: t.mutedForeground),
// //       const SizedBox(width: 12),
// //       const Expanded(child: AppCardDescription('New updates are available for your system components.')),
// //     ],
// //   ),
// // ),
// // const SizedBox(height: 16),
//
// // Small
// // GloveVisualization(size: GloveSize.sm),
// // const SizedBox(height: 16),
// //
// //         // Medium (default), active with animation
// //         GloveVisualization(isActive: true),
// //         const SizedBox(height: 16),
// //         //
// //         // // Large — full width, 16:9
// //         GloveVisualization(size: GloveSize.lg, isActive: true),
// //         const SizedBox(height: 16),
// // // // Large — full width, 16:9
// //         GloveVisualization(size: GloveSize.square, isActive: true),
// //         const SizedBox(height: 16),
//
// // GloveStatus(
// //   gloveName: 'IntelliGlove Pro',
// //   batteryLevel: 85,
// //   isConnected: true,
// //   signalStrength: 4,
// //   onTap: () {
// //     // navigate to glove details
// //   },
// // ),
// // Badge
// //         AppBadge(label: 'Active', variant: AppBadgeVariant.primary),
// //         const SizedBox(height: 32),
// //
// //         AppBadge(label: 'Warning', variant: AppBadgeVariant.destructive),
// //         const SizedBox(height: 32),
// //
// // // Alert
// //         AppAlert(
// //           icon: Icon(Icons.info_outline_rounded),
// //           title: AppAlertTitle('Heads up!'),
// //           description: AppAlertDescription('You can add components.'),
// //         ),
// //         const SizedBox(height: 32),
// //
// // // Avatar
// //         AppAvatar(imageUrl: 'https://...', fallbackText: 'JD', size: 40),
// //         const SizedBox(height: 32),
// //
// // // Progress
// //         AppProgress(value: 0.65, height: 8),
// //         const SizedBox(height: 32),
// //
// // // Skeleton
// //         AppSkeleton(width: double.infinity, height: 20),
// //         AppSkeleton.circle(size: 40),
// //         const SizedBox(height: 32),
// //
// // // Separator
// //         AppSeparator(),
// //         AppSeparator(isVertical: true),
// //         const SizedBox(height: 32),
//
// // Tabs
// //         AppTabs(tabs: [
// //           AppTabItem(label: 'Overview', content: Text('Overview content')),
// //           AppTabItem(label: 'Settings', content: Text('Settings content')),
// //         ]),
// //         const SizedBox(height: 32),
// //
// // // Accordion
// //         AppAccordion(items: [
// //           AppAccordionItem(title: Text('Section 1'), content: Text('Content 1')),
// //           AppAccordionItem(title: Text('Section 2'), content: Text('Content 2')),
// //         ]),
// //         const SizedBox(height: 32),
// //
// //       // Breadcrumb
// //         AppBreadcrumb(items: [
// //           AppBreadcrumbItem(label: 'Home', onTap: () {}),
// //           AppBreadcrumbItem(label: 'Services', onTap: () {}),
// //           AppBreadcrumbItem(label: 'Internet'),
// //         ]),
// //         const SizedBox(height: 32),
// // ── Button variants ──
//
//
//
// //         AppButton(
// //           child: Text('Get Started'),
// //           variant: AppButtonVariant.hero,
// //           size: AppButtonSize.lg,
// //           onPressed: () {},
// //         ),
// //         const SizedBox(height: 16),
// //
// //         AppButton(
// //           child: Text('Delete'),
// //           variant: AppButtonVariant.destructive,
// //           icon: Icon(Icons.delete_outline),
// //           onPressed: () {},
// //         ),
// //         const SizedBox(height: 16),
// //
// //         AppButton.icon(
// //           icon: Icon(Icons.add),
// //           variant: AppButtonVariant.accent,
// //           onPressed: () {},
// //         ),
// //         const SizedBox(height: 16),
// //
// // // ── Form field with input ──
// //         AppFormField(
// //           label: 'Email',
// //           description: 'We will never share your email.',
// //           errorMessage: null, // or 'Invalid email'
// //           child: AppInput(hintText: 'Enter email...'),
// //         ),
// //         const SizedBox(height: 16),
// //
// // // ── Textarea ──
// //         AppTextarea(hintText: 'Write your message...', minLines: 4),
// //         const SizedBox(height: 16),
// //
// // // ── Checkbox ──
// //         AppCheckbox(value: true, label: 'I agree', onChanged: (v) {}),
// //         const SizedBox(height: 16),
// //
// // // ── Switch ──
// //         AppSwitch(value: true, label: 'Notifications', onChanged: (v) {}),
// //         const SizedBox(height: 16),
// //
// // // ── Radio ──
// //         AppRadioGroup<String>(
// //           value: 'a',
// //           items: [
// //             AppRadioItem(value: 'a', label: 'Option A'),
// //             AppRadioItem(value: 'b', label: 'Option B'),
// //           ],
// //           onChanged: (v) {},
// //         ),
// //         const SizedBox(height: 16),
// //
// // // ── Slider ──
// //         AppSlider(value: 0.5, label: 'Volume', onChanged: (v) {}),
// //         const SizedBox(height: 16),
// //
// // // ── Toggle ──
// //         AppToggle(isSelected: true, child: Text('Bold'), onPressed: () {}),
// //         const SizedBox(height: 16),
// //
// // // ── Toggle Group ──
// //         AppToggleGroup<String>(
// //           items: [
// //             AppToggleGroupItem(value: 'left', child: Icon(Icons.format_align_left)),
// //             AppToggleGroupItem(value: 'center', child: Icon(Icons.format_align_center)),
// //             AppToggleGroupItem(value: 'right', child: Icon(Icons.format_align_right)),
// //           ],
// //           selected: {'left'},
// //           onToggle: (v) {},
// //         ),
// //         const SizedBox(height: 16),
// //
// // // ── Select ──
// //         AppSelect<String>(
// //           value: 'usd',
// //           hintText: 'Select currency',
// //           items: [
// //             AppSelectItem(value: 'usd', label: 'US Dollar'),
// //             AppSelectItem(value: 'eur', label: 'Euro'),
// //             AppSelectItem.separator(),
// //             AppSelectItem.group('Crypto'),
// //             AppSelectItem(value: 'btc', label: 'Bitcoin'),
// //           ],
// //           onChanged: (v) {},
// //         ),
// //         const SizedBox(height: 16),
// //
// //
// // // 2. Show toasts from anywhere
// //         // 1. Default Toast
// //         AppButton(
// //           child: const Text('Save Settings'),
// //           onPressed: () {
// //             toast.show(
// //               title: 'Settings saved',
// //               description: 'Your preferences have been updated.',
// //             );
// //           },
// //         ),
// //         const SizedBox(height: 16),
// //
// // // 2. Success Toast
// //         AppButton(
// //           child: const Text('Upload File'),
// //           variant: AppButtonVariant.accent, // Optional: makes the button stand out
// //           onPressed: () {
// //             toast.success(
// //               title: 'Success!',
// //               description: 'File uploaded successfully.',
// //             );
// //           },
// //         ),
// //         const SizedBox(height: 16),
// //
// // // 3. Error Toast
// //         AppButton(
// //           child: const Text('Trigger Error'),
// //           variant: AppButtonVariant.destructive, // Makes the button look like a dangerous action
// //           onPressed: () {
// //             toast.error(
// //               title: 'Error',
// //               description: 'Something went wrong.',
// //             );
// //           },
// //         ),
// //         const SizedBox(height: 16),
// //
// // // 4. Action/Undo Toast
// //         AppButton(
// //           child: const Text('Delete Item'),
// //           onPressed: () {
// //             toast.show(
// //               title: 'Undo?',
// //               description: 'Item deleted.',
// //               variant: AppToastVariant.defaultVariant,
// //               actionLabel: 'Undo',
// //               onAction: () => print('Undo tapped'),
// //             );
// //           },
// //         ),
// //         const SizedBox(height: 16),
// //         // Config (define once, reuse)
// //
// //         const SizedBox(height: 16),
// //
// // // Line chart
// //         AppChartContainer(
// //           config: chartConfig,
// //           aspectRatio: 16 / 9,
// //           child: AppLineChart(
// //             lines: [
// //               AppLineChartData(
// //                 key: 'revenue',
// //                 spots: const [
// //                   FlSpot(0, 3),
// //                   FlSpot(1, 4),
// //                   FlSpot(2, 3.5),
// //                   FlSpot(3, 5),
// //                   FlSpot(4, 4),
// //                   FlSpot(5, 6),
// //                 ],
// //               ),
// //             ],
// //             bottomLabels: const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
// //           ),
// //         ),
// //         const SizedBox(height: 16),
// //
// // // Bar chart
// //         AppChartContainer(
// //           config: chartConfig,
// //           aspectRatio: 16 / 9,
// //           child: AppBarChart(
// //             groups: const [
// //               AppBarChartGroup(x: 0, values: {'revenue': 40, 'expenses': 24}, label: 'Jan'),
// //               AppBarChartGroup(x: 1, values: {'revenue': 55, 'expenses': 30}, label: 'Feb'),
// //               AppBarChartGroup(x: 2, values: {'revenue': 47, 'expenses': 28}, label: 'Mar'),
// //             ],
// //           ),
// //         ),
// //         const SizedBox(height: 16),
// //
// // // Pie chart
// //         AppChartContainer(
// //           config: chartConfig,
// //           aspectRatio: 1,
// //           child: AppPieChart(
// //             sections: const [
// //               AppPieChartSection(key: 'revenue', value: 65),
// //               AppPieChartSection(key: 'expenses', value: 35),
// //             ],
// //           ),
// //         ),
// //         const SizedBox(height: 16),
// // Legend (place below any chart)
// // AppChartContainer(
// // config: chartConfig,
// // aspectRatio: 16 / 1,
// // child: AppChartLegend(
// // keys: const ['revenue', 'expenses'],
// // ),
// // ),
// //
// // ── Carousel ──
// //
// // AppCarousel(
// //
// // height: 200,
// //
// // showArrows: true,
// //
// // showDots: true,
// //
// // items: [
// //
// // Container(
// //
// // decoration: BoxDecoration(
// //
// // color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
// //
// // borderRadius: BorderRadius.circular(16),
// //
// // ),
// //
// // child: const Center(child: Text('Slide 1')),
// //
// // ),
// //
// // Container(
// //
// // decoration: BoxDecoration(
// //
// // color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
// //
// // borderRadius: BorderRadius.circular(16),
// //
// // ),
// //
// // child: const Center(child: Text('Slide 2')),
// //
// // ),
// //
// // Container(
// //
// // decoration: BoxDecoration(
// //
// // color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
// //
// // borderRadius: BorderRadius.circular(16),
// //
// // ),
// //
// // child: const Center(child: Text('Slide 3')),
// //
// // ),
// //
// // ],
// //
// // onPageChanged: (i) => debugPrint('Page: $i'),
// //
// // ),
// //
// // const SizedBox(height: 16),
// //
// //
// // // ── Carousel with auto-play + partial viewport ──
// //
// // AppCarousel(
// //
// // height: 160,
// //
// // autoPlay: true,
// //
// // autoPlayInterval: const Duration(seconds: 3),
// //
// // viewportFraction: 0.85,
// //
// // showArrows: false,
// //
// // items: List.generate(5, (i) {
// //
// // return Container(
// //
// // decoration: BoxDecoration(
// //
// // color: Colors.primaries[i % Colors.primaries.length].withValues(alpha: 0.15),
// //
// // borderRadius: BorderRadius.circular(12),
// //
// // ),
// //
// // child: Center(child: Text('Card ${i + 1}')),
// //
// // );
// //
// // }),
// //
// // ),
// //
// // const SizedBox(height: 16),
// //
// //
// // // ── Collapsible ──
// //
// // AppCollapsible(
// //
// // trigger: Padding(
// //
// // padding: const EdgeInsets.symmetric(vertical: 12),
// //
// // child: Row(
// //
// // children: [
// //
// // const Expanded(
// //
// // child: Text(
// //
// // 'Show more details',
// //
// // style: TextStyle(fontWeight: FontWeight.w500),
// //
// // ),
// //
// // ),
// //
// // Icon(Icons.keyboard_arrow_down_rounded, size: 20),
// //
// // ],
// //
// // ),
// //
// // ),
// //
// // content: const Padding(
// //
// // padding: EdgeInsets.only(bottom: 12),
// //
// // child: Text('Here are the extra details that were hidden.'),
// //
// // ),
// //
// // ),
// //
// // const SizedBox(height: 16),
// //
// //
// // // ── Pagination ──
// //
// // AppPagination(
// //
// // currentPage: 3,
// //
// // totalPages: 10,
// //
// // onPageChanged: (page) => debugPrint('Page: $page'),
// //
// // ),
// //
// // const SizedBox(height: 16),
// //
// //
// // // ── OTP Input (6 digits, separator after 3rd) ──
// //
// // AppInputOTP(
// //
// // length: 6,
// //
// // separatorPositions: const [3],
// //
// // onCompleted: (code) => debugPrint('OTP: $code'),
// //
// // onChanged: (value) => debugPrint('Current: $value'),
// //
// // ),
// //
// // const SizedBox(height: 16),
// //
// //
// // // ── OTP Input (4 digits, obscured) ──
// //
// // AppInputOTP(
// //
// // length: 4,
// //
// // obscureText: true,
// //
// // keyboardType: TextInputType.number,
// //
// // onCompleted: (pin) => debugPrint('PIN: $pin'),
// //
// // ),
// // const SizedBox(height: 32),
//
// import 'package:flutter/material.dart';
// import 'theme/theme_provider.dart';
// import 'theme/app_colors.dart';
// import 'dart:ui';
// import 'package:fl_chart/fl_chart.dart';
//
// // Components
// import 'components/bottom_nav.dart';
// import 'components/feature_card.dart';
// import 'components/display.dart';
// import 'components/glove_visualization.dart';
// import 'components/glove_status.dart';
// import 'components/inputs.tsx.dart';
// import 'components/toast.dart';
// import 'components/chart.dart';
// import 'components/feedback2.dart';
// import 'components/overlays.dart';
// import 'components/menus.dart';
//
//
// class HomeContent extends StatelessWidget {
//   const HomeContent({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final t = ThemeProviderScope.of(context).tokens;
//
//     const chartConfig = AppChartConfig(
//       series: {
//         'revenue': AppChartSeriesConfig(
//           label: 'Revenue',
//           lightColor: Color(0xFF00838F),
//           darkColor: Color(0xFF00C2C2),
//         ),
//         'expenses': AppChartSeriesConfig(
//           label: 'Expenses',
//           color: Color(0xFFE02424),
//         ),
//       },
//     );
//
//     return ListView(
//       // Extra bottom padding (100) ensures content clears the floating nav bar
//       padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
//       children: [
//         // ── Feature Cards Section ──
//         // Text('Quick Actions',
//         //     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.foreground)),
//         // const SizedBox(height: 16),
//
//         // FeatureCard(
//         //   icon: Icons.bolt_rounded,
//         //   title: 'Boost Performance',
//         //   description: 'Optimize your system settings for maximum speed.',
//         //   onTap: () {},
//         // ),
//         // const SizedBox(height: 12),
//
//         // FeatureCard(
//         //   icon: Icons.shield_rounded,
//         //   title: 'Privacy Guard',
//         //   description: 'Secure your data with encrypted protocols.',
//         //   onTap: () {},
//         //   iconDecoration: BoxDecoration(
//         //     borderRadius: BorderRadius.circular(16),
//         //     gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
//         //   ),
//         // ),
//         // ── Tooltip ──
//         AppTooltip(
//           message: 'This is a tooltip',
//           child: const Icon(Icons.info_outline_rounded),
//         ),
//         const SizedBox(height: 16),
//
// // ── Dialog ──
//         ElevatedButton(
//           onPressed: () {
//             showAppDialog(
//               context: context,
//               builder: (ctx) => AppDialogContent(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const AppDialogHeader(
//                       title: AppDialogTitle('Edit Profile'),
//                       description: AppDialogDescription(
//                         'Make changes to your profile here.',
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     const Text('Dialog body content...'),
//                     AppDialogFooter(
//                       children: [
//                         TextButton(
//                           onPressed: () => Navigator.pop(ctx),
//                           child: const Text('Cancel'),
//                         ),
//                         ElevatedButton(
//                           onPressed: () => Navigator.pop(ctx, true),
//                           child: const Text('Save'),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//           child: const Text('Open Dialog'),
//         ),
//         const SizedBox(height: 16),
//
// // ── Alert Dialog ──
//         ElevatedButton(
//           onPressed: () async {
//             final confirmed = await showAppAlertDialog(
//               context: context,
//               title: 'Are you sure?',
//               description: 'This action cannot be undone.',
//               actionLabel: 'Delete',
//               cancelLabel: 'Cancel',
//               isDestructive: true,
//             );
//             if (confirmed == true) {
//               // perform action
//             }
//           },
//           child: const Text('Delete Item'),
//         ),
//         const SizedBox(height: 16),
//
// // ── Sheet (right) ──
//         ElevatedButton(
//           onPressed: () {
//             showAppSheet(
//               context: context,
//               side: AppSheetSide.right,
//               builder: (ctx) => Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const AppSheetHeader(
//                     title: AppSheetTitle('Settings'),
//                     description: AppSheetDescription('Adjust your preferences.'),
//                   ),
//                   const SizedBox(height: 16),
//                   const Text('Sheet content here...'),
//                   AppSheetFooter(
//                     children: [
//                       TextButton(
//                         onPressed: () => Navigator.pop(ctx),
//                         child: const Text('Cancel'),
//                       ),
//                       ElevatedButton(
//                         onPressed: () => Navigator.pop(ctx),
//                         child: const Text('Save'),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             );
//           },
//           child: const Text('Open Sheet'),
//         ),
//         const SizedBox(height: 16),
//
// // ── Drawer (bottom) ──
//         ElevatedButton(
//           onPressed: () {
//             showAppDrawer(
//               context: context,
//               builder: (ctx) => Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const AppDrawerHeader(
//                     title: AppDrawerTitle('Move Goal'),
//                     description: AppDrawerDescription('Set your daily activity goal.'),
//                   ),
//                   const SizedBox(height: 16),
//                   const Text('Drawer content...'),
//                   AppDrawerFooter(
//                     children: [
//                       ElevatedButton(
//                         onPressed: () => Navigator.pop(ctx),
//                         child: const Text('Submit'),
//                       ),
//                       TextButton(
//                         onPressed: () => Navigator.pop(ctx),
//                         child: const Text('Cancel'),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             );
//           },
//           child: const Text('Open Drawer'),
//         ),
//         const SizedBox(height: 16),
//
// // ── Popover ──
//         ElevatedButton(
//           onPressed: () {
//             showAppPopover(
//               context: context,
//               builder: (ctx) => Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Popover Title',
//                     style: TextStyle(fontWeight: FontWeight.w600),
//                   ),
//                   const SizedBox(height: 8),
//                   const Text('Some popover content here.'),
//                 ],
//               ),
//             );
//           },
//           child: const Text('Open Popover'),
//         ),
// // ── Dropdown Menu ──
//         ElevatedButton(
//           onPressed: () async {
//             final result = await showAppMenu<String>(
//               context: context,
//               label: 'My Account',
//               items: [
//                 AppMenuItem(
//                   title: 'Profile',
//                   icon: const Icon(Icons.person_outline_rounded),
//                   value: 'profile',
//                   shortcut: '⌘P',
//                 ),
//                 AppMenuItem(
//                   title: 'Settings',
//                   icon: const Icon(Icons.settings_outlined),
//                   value: 'settings',
//                 ),
//                 const AppMenuItem.separator(),
//                 const AppMenuItem.label('Danger Zone'),
//                 AppMenuItem(
//                   title: 'Delete Account',
//                   icon: const Icon(Icons.delete_outline_rounded),
//                   isDestructive: true,
//                   value: 'delete',
//                 ),
//               ],
//             );
//             debugPrint('Selected: $result');
//           },
//           child: const Text('Open Menu'),
//         ),
//         const SizedBox(height: 16),
//
// // ── Menu with checkboxes ──
//         ElevatedButton(
//           onPressed: () {
//             showAppMenu(
//               context: context,
//               items: [
//                 const AppMenuItem.label('Appearance'),
//                 AppMenuItem(
//                   title: 'Show Toolbar',
//                   isCheckbox: true,
//                   isChecked: true,
//                   onTap: () {},
//                 ),
//                 AppMenuItem(
//                   title: 'Show Sidebar',
//                   isCheckbox: true,
//                   isChecked: false,
//                   onTap: () {},
//                 ),
//                 const AppMenuItem.separator(),
//                 const AppMenuItem.label('Theme'),
//                 AppMenuItem(
//                   title: 'Light',
//                   isRadio: true,
//                   isChecked: true,
//                   onTap: () {},
//                 ),
//                 AppMenuItem(
//                   title: 'Dark',
//                   isRadio: true,
//                   isChecked: false,
//                   onTap: () {},
//                 ),
//               ],
//             );
//           },
//           child: const Text('Open Settings Menu'),
//         ),
//         const SizedBox(height: 16),
//
// // ── Command Palette ──
//         ElevatedButton(
//           onPressed: () async {
//             final result = await showAppCommand<String>(
//               context: context,
//               placeholder: 'Search actions...',
//               groups: [
//                 AppCommandGroup(
//                   heading: 'Suggestions',
//                   items: [
//                     AppCommandItem(
//                       label: 'Calendar',
//                       icon: const Icon(Icons.calendar_today_rounded),
//                       value: 'calendar',
//                     ),
//                     AppCommandItem(
//                       label: 'Search Emoji',
//                       icon: const Icon(Icons.emoji_emotions_outlined),
//                       value: 'emoji',
//                       keywords: ['smiley', 'face'],
//                     ),
//                     AppCommandItem(
//                       label: 'Calculator',
//                       icon: const Icon(Icons.calculate_outlined),
//                       value: 'calculator',
//                     ),
//                   ],
//                 ),
//                 AppCommandGroup(
//                   heading: 'Settings',
//                   items: [
//                     AppCommandItem(
//                       label: 'Profile',
//                       icon: const Icon(Icons.person_outline_rounded),
//                       value: 'profile',
//                       shortcut: '⌘P',
//                     ),
//                     AppCommandItem(
//                       label: 'Billing',
//                       icon: const Icon(Icons.credit_card_rounded),
//                       value: 'billing',
//                       shortcut: '⌘B',
//                     ),
//                     AppCommandItem(
//                       label: 'Settings',
//                       icon: const Icon(Icons.settings_outlined),
//                       value: 'settings',
//                       shortcut: '⌘S',
//                     ),
//                   ],
//                 ),
//               ],
//             );
//             debugPrint('Command: $result');
//           },
//           child: const Text('Open Command Palette'),
//         ),
//       ],
//     );
//   }
// }
//
//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   final themeProvider = await ThemeProvider.load();
//   runApp(MyApp(themeProvider: themeProvider));
// }
//
// class MyApp extends StatelessWidget {
//   final ThemeProvider themeProvider;
//   const MyApp({super.key, required this.themeProvider});
//
//   @override
//   Widget build(BuildContext context) {
//     return ThemeProviderScope(
//       notifier: themeProvider,
//       child: AnimatedBuilder(
//         animation: themeProvider,
//         builder: (context, _) => MaterialApp(
//           debugShowCheckedModeBanner: false,
//           title: 'Design System App',
//           themeMode: themeProvider.themeMode,
//           theme: themeProvider.lightTheme,
//           darkTheme: themeProvider.darkTheme,
//           builder: (context, child) {
//             return Stack(
//               children: [
//                 child!,
//                 const AppToaster(),
//               ],
//             );
//           },
//           home: const MainScreen(),
//         ),
//       ),
//     );
//   }
// }
//
// class MainScreen extends StatefulWidget {
//   const MainScreen({super.key});
//
//   @override
//   State<MainScreen> createState() => _MainScreenState();
// }
//
// class _MainScreenState extends State<MainScreen> {
//   int _currentIndex = 0;
//
//   final List<Widget> _pages = [
//     const HomeContent(),
//     const Center(child: Text('Services Screen')),
//     const Center(child: Text('Profile Screen')),
//   ];
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       // extendBody allows content to scroll behind the glassmorphic nav bar
//       extendBody: true,
//       appBar: AppBar(
//         title: const Text('Design System'),
//         centerTitle: false,
//         actions: const [
//           Padding(
//             padding: EdgeInsets.only(right: 12),
//             child: ThemeToggle(), // Assuming this exists in your theme_provider.dart
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           IndexedStack(
//             index: _currentIndex,
//             children: _pages,
//           ),
//           Positioned(
//             left: 0,
//             right: 0,
//             bottom: 0,
//             child: BottomNav(
//               currentIndex: _currentIndex,
//               onTap: (index) => setState(() => _currentIndex = index),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
