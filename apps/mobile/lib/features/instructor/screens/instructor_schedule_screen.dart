library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:quickfit/core/router/app_routes.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/features/instructor/models/schedule_event.dart';
import 'package:quickfit/features/instructor/providers/schedule_provider.dart';
import 'package:quickfit/l10n/app_localizations.dart';
import 'package:quickfit/shared/widgets/adaptive_app_bar.dart';

class InstructorScheduleScreen extends ConsumerStatefulWidget {
  const InstructorScheduleScreen({super.key});

  @override
  ConsumerState<InstructorScheduleScreen> createState() =>
      _InstructorScheduleScreenState();
}

class _InstructorScheduleScreenState
    extends ConsumerState<InstructorScheduleScreen> {
  static const int _timelineStartHour = 6;
  static const int _timelineEndHour = 23;
  static const double _slotHeight = 58;
  static const double _timelineViewportHeight = 500;
  static const double _hourGutterWidth = 50;
  static const double _swipeDistanceThreshold = 88;
  static const double _swipeVelocityThreshold = 420;

  late DateTime _selectedDate;
  double _horizontalDragAccum = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Future<void> _onRefresh() async {
    await ref.read(scheduleProvider.notifier).refresh();
  }

  void _shiftWindow(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() => _selectedDate = DateTime(now.year, now.month, now.day));
  }

  void _handleTimelineHorizontalDragStart(DragStartDetails _) {
    _horizontalDragAccum = 0;
  }

  void _handleTimelineHorizontalDragUpdate(DragUpdateDetails details) {
    _horizontalDragAccum += details.delta.dx;
  }

  void _handleTimelineHorizontalDragCancel() {
    _horizontalDragAccum = 0;
  }

  void _handleTimelineHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dragDistance = _horizontalDragAccum;
    _horizontalDragAccum = 0;

    final swipeLeft = velocity <= -_swipeVelocityThreshold ||
        (velocity.abs() < _swipeVelocityThreshold &&
            dragDistance <= -_swipeDistanceThreshold);
    final swipeRight = velocity >= _swipeVelocityThreshold ||
        (velocity.abs() < _swipeVelocityThreshold &&
            dragDistance >= _swipeDistanceThreshold);

    if (swipeLeft) {
      _shiftWindow(1);
    } else if (swipeRight) {
      _shiftWindow(-1);
    }
  }

  String _buildDateRangeLabel(List<DateTime> days) {
    final start = days.first;
    final end = days.last;
    if (start.month == end.month && start.year == end.year) {
      return '${DateFormat.MMM().format(start)} ${start.day}-${end.day}, ${start.year}';
    }
    return '${DateFormat.MMMd().format(start)} - ${DateFormat.MMMd().format(end)}';
  }

  Uri _buildGoogleCalendarUri(ScheduleEvent event) {
    final l10n = AppLocalizations.of(context)!;
    final dateFmt = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    final details =
        StringBuffer(l10n.scheduleGoogleCalendarDetailsHeader(event.jobId));
    if (event.studioName.trim().isNotEmpty) {
      details.write(
        '\n${l10n.scheduleGoogleCalendarDetailsStudio(event.studioName.trim())}',
      );
    }
    if (event.category?.trim().isNotEmpty == true) {
      details.write('\n${l10n.categoryLabel}: ${event.category!.trim()}');
    }

    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': event.title,
      'dates':
          '${dateFmt.format(event.startTime.toUtc())}/${dateFmt.format(event.endTime.toUtc())}',
      'details': details.toString(),
      if (event.address.trim().isNotEmpty) 'location': event.address.trim(),
    });
  }

  Future<void> _addToGoogleCalendar(ScheduleEvent event) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = _buildGoogleCalendarUri(event);
    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.couldNotOpenGoogleCalendar),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scheduleProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;

    final threeDays = [
      _selectedDate.subtract(const Duration(days: 1)),
      _selectedDate,
      _selectedDate.add(const Duration(days: 1)),
    ];

    return Scaffold(
      appBar: adaptiveAppBar(
        context,
        title: l10n.calendarTitle,
        actions: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _onRefresh,
              icon: const Icon(LucideIcons.refreshCw),
              tooltip: l10n.refresh,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: state.isLoading && state.events.isEmpty
            ? const _ScheduleLoadingView()
            : state.error != null && state.events.isEmpty
                ? _ScheduleErrorView(
                    error: state.error!,
                    onRetry: _onRefresh,
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _buildCalendarPanel(
                        state: state,
                        days: threeDays,
                      ),
                      if (state.lastUpdated != null) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            l10n.syncedAt(
                                DateFormat.Hm().format(state.lastUpdated!)),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.mutedText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _buildCalendarPanel({
    required ScheduleState state,
    required List<DateTime> days,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        children: [
          _buildWeekStrip(state),
          const SizedBox(height: 4),
          _buildTimelineNavigation(days),
          const SizedBox(height: 10),
          _buildThreeDayTimeline(state, days),
        ],
      ),
    );
  }

  Widget _buildTimelineNavigation(List<DateTime> days) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final rangeLabel = _buildDateRangeLabel(days);
    final isTodaySelected = _isSameDay(_selectedDate, DateTime.now());

    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => _shiftWindow(-1),
          icon: const Icon(LucideIcons.chevronLeft),
          tooltip: l10n.previousDayWindowTooltip,
        ),
        Expanded(
          child: Text(
            rangeLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: isTodaySelected ? null : _jumpToToday,
          child: Text(l10n.todayLabel),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => _shiftWindow(1),
          icon: const Icon(LucideIcons.chevronRight),
          tooltip: l10n.nextDayWindowTooltip,
        ),
      ],
    );
  }

  Widget _buildWeekStrip(ScheduleState state) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final weekStart =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: List.generate(7, (index) {
            final day = weekStart.add(Duration(days: index));
            final isSelected = _isSameDay(day, _selectedDate);
            final isToday = _isSameDay(day, DateTime.now());
            final jobCount = state.jobsCountForDay(day);
            final hours = state.bookedHoursForDay(day);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _selectedDate = day),
                  child: Container(
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.14)
                          : isToday
                              ? theme.colorScheme.primary
                                  .withValues(alpha: 0.08)
                              : theme.colorScheme.surface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat.E()
                              .format(day)
                              .substring(0, 2)
                              .toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : colors.mutedText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${day.day}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          jobCount > 0
                              ? l10n.scheduleHoursCompact(_formatHours(hours))
                              : ' ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : colors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildThreeDayTimeline(
    ScheduleState state,
    List<DateTime> days,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final totalTimelineHeight =
        (_timelineEndHour - _timelineStartHour + 1) * _slotHeight;

    final hasAnyEvents = days.any((day) => state.eventsForDay(day).isNotEmpty);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _handleTimelineHorizontalDragStart,
      onHorizontalDragUpdate: _handleTimelineHorizontalDragUpdate,
      onHorizontalDragEnd: _handleTimelineHorizontalDragEnd,
      onHorizontalDragCancel: _handleTimelineHorizontalDragCancel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: days.map((day) {
              final isCenter = _isSameDay(day, _selectedDate);
              return Expanded(
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isCenter
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.E().format(day),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: context.colors.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          DateFormat.MMMd().format(day),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isCenter
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _timelineViewportHeight,
            child: SingleChildScrollView(
              child: SizedBox(
                height: totalTimelineHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final laneWidth =
                        (constraints.maxWidth - _hourGutterWidth) / 3;

                    return Stack(
                      children: [
                        ..._buildTimelineGrid(theme),
                        ..._buildDaySeparators(theme, laneWidth),
                        ..._buildEventBlocks(
                          state,
                          days,
                          laneWidth,
                        ),
                        ..._buildNowIndicators(days, laneWidth),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (!hasAnyEvents) ...[
            const SizedBox(height: 10),
            Text(
              l10n.noJobsInThreeDayWindow,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.colors.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildTimelineGrid(ThemeData theme) {
    final colors = context.colors;
    final widgets = <Widget>[];
    final rows = _timelineEndHour - _timelineStartHour + 1;

    for (var i = 0; i <= rows; i++) {
      final top = i * _slotHeight;
      final hour = _timelineStartHour + i;
      final showLabel = i < rows;

      widgets.add(
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _hourGutterWidth - 6,
                child: showLabel
                    ? Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 1,
                  color: colors.divider.withValues(alpha: 0.26),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildDaySeparators(ThemeData theme, double laneWidth) {
    final colors = context.colors;
    return [
      Positioned(
        left: _hourGutterWidth + laneWidth,
        top: 0,
        bottom: 0,
        child:
            Container(width: 1, color: colors.divider.withValues(alpha: 0.2)),
      ),
      Positioned(
        left: _hourGutterWidth + (laneWidth * 2),
        top: 0,
        bottom: 0,
        child:
            Container(width: 1, color: colors.divider.withValues(alpha: 0.2)),
      ),
    ];
  }

  List<Widget> _buildEventBlocks(
    ScheduleState state,
    List<DateTime> days,
    double laneWidth,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final widgets = <Widget>[];

    for (var lane = 0; lane < days.length; lane++) {
      final dayEvents = state.eventsForDay(days[lane]);
      for (final event in dayEvents) {
        final eventStartMinutes =
            (event.startTime.hour * 60) + event.startTime.minute;
        final eventEndMinutes =
            (event.endTime.hour * 60) + event.endTime.minute;
        final timelineStartMinutes = _timelineStartHour * 60;
        final timelineEndMinutes = (_timelineEndHour + 1) * 60;

        if (eventEndMinutes <= timelineStartMinutes ||
            eventStartMinutes >= timelineEndMinutes) {
          continue;
        }

        final clampedStartMinutes = eventStartMinutes < timelineStartMinutes
            ? timelineStartMinutes
            : eventStartMinutes;
        final clampedEndMinutes = eventEndMinutes > timelineEndMinutes
            ? timelineEndMinutes
            : eventEndMinutes;

        final top =
            ((clampedStartMinutes - timelineStartMinutes) / 60) * _slotHeight;
        final height =
            (((clampedEndMinutes - clampedStartMinutes) / 60) * _slotHeight)
                .clamp(32, 260)
                .toDouble();

        final isPending = event.isPendingClaim;
        final accent =
            isPending ? Colors.orange : Theme.of(context).colorScheme.primary;

        widgets.add(
          Positioned(
            top: top + 2,
            left: _hourGutterWidth + (lane * laneWidth) + 5,
            width: laneWidth - 10,
            height: height - 4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.push(
                  AppRoutes.jobDetail.replaceFirst(':id', event.jobId),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showCalendarAction = constraints.maxHeight >= 62;
                    final showStudio = constraints.maxHeight >= 76;

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: accent.withValues(alpha: 0.12),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      child: Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              right: showCalendarAction ? 26 : 0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${DateFormat.Hm().format(event.startTime)} - ${DateFormat.Hm().format(event.endTime)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: accent,
                                      ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  event.title,
                                  maxLines: showStudio ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                if (showStudio &&
                                    event.studioName.trim().isNotEmpty)
                                  Expanded(
                                    child: Text(
                                      event.studioName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: context.colors.mutedText,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (showCalendarAction)
                            Positioned(
                              right: -4,
                              top: -6,
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 16,
                                splashRadius: 18,
                                tooltip: l10n.addToGoogleCalendar,
                                onPressed: () => _addToGoogleCalendar(event),
                                icon: Icon(
                                  LucideIcons.calendarPlus,
                                  color: accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  List<Widget> _buildNowIndicators(List<DateTime> days, double laneWidth) {
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final timelineStartMinutes = _timelineStartHour * 60;
    final timelineEndMinutes = (_timelineEndHour + 1) * 60;
    if (nowMinutes < timelineStartMinutes || nowMinutes > timelineEndMinutes) {
      return const [];
    }

    final dayIndex = days.indexWhere((day) => _isSameDay(day, now));
    if (dayIndex < 0) return const [];

    final top = ((nowMinutes - timelineStartMinutes) / 60) * _slotHeight;
    final left = _hourGutterWidth + (dayIndex * laneWidth) + 3;

    return [
      Positioned(
        top: top,
        left: left,
        width: laneWidth - 6,
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(height: 1, color: Colors.red),
            ),
          ],
        ),
      ),
    ];
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatHours(double hours) {
    final rounded = (hours * 10).round() / 10;
    if (rounded == rounded.toInt()) {
      return rounded.toInt().toString();
    }
    return rounded.toStringAsFixed(1);
  }
}

class _ScheduleLoadingView extends StatelessWidget {
  const _ScheduleLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleErrorView extends StatelessWidget {
  const _ScheduleErrorView({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(
          LucideIcons.alertCircle,
          size: 52,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            l10n.somethingWentWrong,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.refreshCw),
            label: Text(l10n.tryAgain),
          ),
        ),
      ],
    );
  }
}
