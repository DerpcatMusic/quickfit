import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/categories.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/convex_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/studio_jobs_provider.dart';
import 'package:quickfit/shared/widgets/adaptive_app_bar.dart';

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();

  FitnessCategory? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = _defaultEndTime();
  final _titleController = TextEditingController();
  final _lessonTypeController = TextEditingController();
  final _rateController = TextEditingController();
  final _notesController = TextEditingController();
  bool _requiresVerification = false;
  bool _isSubmitting = false;
  bool _studioPricingLoaded = false;
  List<Map<String, dynamic>> _leadTimeSurgeRules = const [
    {'maxHoursBeforeStart': 6.0, 'boostPercent': 10.0},
    {'maxHoursBeforeStart': 3.0, 'boostPercent': 15.0},
  ];

  static TimeOfDay _defaultEndTime() {
    final now = TimeOfDay.now();
    final totalMinutes = (now.hour * 60) + now.minute + 60;
    if (totalMinutes >= 24 * 60) {
      return const TimeOfDay(hour: 23, minute: 59);
    }
    return TimeOfDay(
      hour: totalMinutes ~/ 60,
      minute: totalMinutes % 60,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedCategory = FitnessCategory.yoga;
    _rateController.text = '${defaultRates[_selectedCategory!.id] ?? 120}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lessonTypeController.dispose();
    _rateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  bool get _isSosJob {
    final startDateTime = _combineDateAndTime(_selectedDate, _startTime);
    final hoursUntilStart =
        startDateTime.difference(DateTime.now()).inMinutes / 60.0;
    return hoursUntilStart < 3 && hoursUntilStart >= 0;
  }

  int get _displayRate {
    final baseRate = int.tryParse(_rateController.text) ?? 0;
    if (baseRate <= 0) return 0;
    final boostPercent = _leadTimeBoostPercent();
    return (baseRate * (1 + (boostPercent / 100))).round();
  }

  double _leadTimeBoostPercent() {
    final startDateTime = _combineDateAndTime(_selectedDate, _startTime);
    final hoursUntilStart =
        startDateTime.difference(DateTime.now()).inMinutes / 60.0;
    if (hoursUntilStart <= 0) return 0;
    final normalized = [..._leadTimeSurgeRules]
      ..sort(
        (a, b) => ((a['maxHoursBeforeStart'] as num?) ?? 0)
            .compareTo((b['maxHoursBeforeStart'] as num?) ?? 0),
      );
    for (final rule in normalized) {
      final maxHours = ((rule['maxHoursBeforeStart'] as num?) ?? 0).toDouble();
      final boost = ((rule['boostPercent'] as num?) ?? 0).toDouble();
      if (hoursUntilStart <= maxHours) return boost;
    }
    return 0;
  }

  Future<void> _loadStudioPricingIfNeeded() async {
    if (_studioPricingLoaded) return;
    _studioPricingLoaded = true;
    try {
      final settings = await ConvexService.instance.getMyStudioPricingSettings();
      if (!mounted || settings == null) return;

      final defaultRate = (settings['defaultBaseRate'] as num?)?.toDouble();
      final rulesRaw = settings['leadTimeSurgeRules'] as List?;
      final rules = (rulesRaw ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);

      setState(() {
        if (defaultRate != null &&
            (double.tryParse(_rateController.text) ?? 0) <= 0) {
          _rateController.text = defaultRate.toStringAsFixed(0);
        }
        if (rules.isNotEmpty) _leadTimeSurgeRules = rules;
      });
    } catch (_) {
      // Keep post-job UX resilient if pricing settings are unavailable.
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.role != 'studio') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.studioAuthRequiredSnack)),
      );
      context.go(AppRoutes.login);
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.postJobPleaseEnterClassTitle)),
      );
      return;
    }

    final inferredCategory = FitnessCategory.inferFromFreeText(
      '${_lessonTypeController.text} ${_titleController.text} ${_notesController.text}',
    );
    if (_selectedCategory == null && inferredCategory != null) {
      _selectedCategory = inferredCategory;
      _rateController.text = '${defaultRates[inferredCategory.id] ?? 120}';
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.postJobLessonTypeRequired),
        ),
      );
      return;
    }

    final rate = double.tryParse(_rateController.text);
    if (rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.postJobPleaseEnterValidRate)),
      );
      return;
    }

    if (auth.latitude == null || auth.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.postJobStudioAddressNotSet)),
      );
      context.push(AppRoutes.onboarding);
      return;
    }

    final startDateTime = _combineDateAndTime(_selectedDate, _startTime);
    final endDateTime = _combineDateAndTime(_selectedDate, _endTime);

    if (startDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.postJobStartTimeFuture)),
      );
      return;
    }

    if (endDateTime.isBefore(startDateTime) || endDateTime == startDateTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.postJobEndTimeAfterStart)),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(studioJobsProvider.notifier).postJob(
            title: title,
            category: _selectedCategory!.id,
            startTime: startDateTime,
            endTime: endDateTime,
            baseRate: rate,
            address: auth.homeAddress ?? l10n.postJobStudioLocationFallback,
            latitude: auth.latitude!,
            longitude: auth.longitude!,
            description: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            requiresVerification: _requiresVerification,
          );

      // Try to warm the studio jobs list before navigation. Do not fail success
      // flow if refresh takes too long.
      try {
        await ref
            .read(studioJobsProvider.notifier)
            .refresh()
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // Posting success remains canonical even if list refresh lags.
      }
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.checkCircle2, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.postJobSuccessMessage)),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go(AppRoutes.studioJobs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.mapErrorWithMessage(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    if (auth.isAuthenticated && auth.role == 'studio' && !_studioPricingLoaded) {
      _loadStudioPricingIfNeeded();
    }

    if (!auth.isAuthenticated || auth.role != 'studio') {
      return Scaffold(
        appBar: adaptiveAppBar(
          context,
          title: l10n.postJobTitle,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.logIn,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.studioAuthRequiredTitle,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.studioAuthRequiredBodyPostJob,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.colors.mutedText,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: Text(l10n.authGoToLogin),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: adaptiveAppBar(
        context,
        title: l10n.postJobTitle,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.06),
              theme.colorScheme.surface,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormSectionLabel(title: l10n.postJobClassTitle),
                  const SizedBox(height: 10),
                  _buildTitleInput(),
                  const SizedBox(height: 20),
                  _FormSectionLabel(title: l10n.postJobClassType),
                  const SizedBox(height: 10),
                  _buildLessonTypeInput(),
                  const SizedBox(height: 10),
                  _buildCategorySelector(),
                  const SizedBox(height: 20),
                  _FormSectionLabel(title: l10n.postJobDate),
                  const SizedBox(height: 10),
                  _buildDateSelector(),
                  const SizedBox(height: 20),
                  _FormSectionLabel(title: l10n.postJobTime),
                  const SizedBox(height: 10),
                  _buildTimeSelector(),
                  const SizedBox(height: 20),
                  _FormSectionLabel(title: l10n.postJobRateIls),
                  const SizedBox(height: 10),
                  _buildRateInput(),
                  const SizedBox(height: 20),
                  _FormSectionLabel(title: l10n.postJobNotesOptional),
                  const SizedBox(height: 10),
                  _buildNotesInput(),
                  const SizedBox(height: 20),
                  _FormSectionLabel(title: l10n.postJobInstructorEligibility),
                  const SizedBox(height: 10),
                  _buildVerificationEligibilityToggle(),
                  if (_isSosJob) ...[
                    const SizedBox(height: 20),
                    _buildSosWarning(),
                  ],
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _PrimarySubmitButton(
            isSubmitting: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
            text: l10n.postJobButtonWithRate(_displayRate.toString()),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleInput() {
    final l10n = AppLocalizations.of(context)!;
    return _FieldCard(
      child: TextField(
        controller: _titleController,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        decoration: InputDecoration(
          hintText: l10n.postJobTitleHint,
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FitnessCategory.values.map((category) {
        final isSelected = _selectedCategory == category;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                _selectedCategory = category;
                _rateController.text = '${defaultRates[category.id] ?? 120}';
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? category.color.withValues(alpha: 0.12)
                    : theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? category.color : colors.cardBorder,
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _localizedCategoryLabel(l10n, category),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected ? category.color : null,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _localizedCategoryLabel(
    AppLocalizations l10n,
    FitnessCategory category,
  ) {
    switch (category) {
      case FitnessCategory.yoga:
        return l10n.postJobCategoryYoga;
      case FitnessCategory.pilates:
        return l10n.postJobCategoryPilates;
      case FitnessCategory.reformerPilates:
        return l10n.postJobCategoryReformerPilates;
      case FitnessCategory.matPilates:
        return l10n.postJobCategoryMatPilates;
      case FitnessCategory.functional:
        return l10n.postJobCategoryFunctionalTraining;
      case FitnessCategory.hiit:
        return l10n.postJobCategoryHiit;
      case FitnessCategory.strength:
        return l10n.postJobCategoryStrength;
      case FitnessCategory.mobility:
        return l10n.postJobCategoryMobility;
      case FitnessCategory.barre:
        return l10n.postJobCategoryBarre;
      case FitnessCategory.spinning:
        return l10n.postJobCategorySpinning;
      case FitnessCategory.dance:
        return l10n.postJobCategoryDance;
      case FitnessCategory.personalTraining:
        return l10n.postJobCategoryPersonalTraining;
    }
  }

  Widget _buildLessonTypeInput() {
    final l10n = AppLocalizations.of(context)!;
    return _FieldCard(
      child: TextField(
        controller: _lessonTypeController,
        decoration: InputDecoration(
          hintText: l10n.postJobLessonTypeHint,
          border: InputBorder.none,
          isCollapsed: true,
        ),
        onChanged: (value) {
          final inferred = FitnessCategory.inferFromFreeText(value);
          if (inferred == null) return;
          setState(() {
            _selectedCategory = inferred;
            _rateController.text = '${defaultRates[inferred.id] ?? 120}';
          });
        },
      ),
    );
  }

  Widget _buildDateSelector() {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateText = DateFormat.yMMMMEEEEd(locale).format(_selectedDate);

    return _FieldCard(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (date != null) {
          setState(() => _selectedDate = date);
        }
      },
      child: Row(
        children: [
          Icon(LucideIcons.calendar, size: 18, color: context.colors.mutedText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dateText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.chevronDown,
              size: 16, color: context.colors.mutedText),
        ],
      ),
    );
  }

  Widget _buildTimeSelector() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _buildTimePicker(
            label: l10n.postJobStartLabel,
            time: _startTime,
            onChanged: (time) => setState(() => _startTime = time),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTimePicker(
            label: l10n.postJobEndLabel,
            time: _endTime,
            onChanged: (time) => setState(() => _endTime = time),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onChanged,
  }) {
    final theme = Theme.of(context);

    return _FieldCard(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: context.colors.mutedText,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(LucideIcons.clock,
                  size: 16, color: context.colors.mutedText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  time.format(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateInput() {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return _FieldCard(
      child: Row(
        children: [
          Text(
            l10n.postJobRateCurrency,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _rateController,
              keyboardType: TextInputType.number,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: AppLocalizations.of(context)!.postJobRateHint,
                isCollapsed: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_leadTimeBoostPercent() > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.successBackground,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.successBorder),
              ),
              child: Text(
                '+${_leadTimeBoostPercent().toStringAsFixed(0)}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.successText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesInput() {
    final l10n = AppLocalizations.of(context)!;
    return _FieldCard(
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: l10n.postJobNotesHint,
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }

  Widget _buildVerificationEligibilityToggle() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    return _FieldCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.postJobVerifiedOnlyLabel,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.postJobVerifiedOnlyHelp,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: _requiresVerification,
            onChanged: (value) => setState(() => _requiresVerification = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSosWarning() {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.urgentBackground.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.urgentBorder.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.urgentBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(LucideIcons.zap, color: colors.urgentBorder, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.postJobSosTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.urgentText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.postJobSosDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.urgentText,
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

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: context.colors.mutedText,
            ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _PrimarySubmitButton extends StatelessWidget {
  const _PrimarySubmitButton({
    required this.isSubmitting,
    required this.onPressed,
    required this.text,
  });

  final bool isSubmitting;
  final VoidCallback? onPressed;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isCupertino = isCupertinoPlatform(context);

    if (isCupertino) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: onPressed,
          child: _ButtonContent(isSubmitting: isSubmitting, text: text),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        child: _ButtonContent(isSubmitting: isSubmitting, text: text),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.isSubmitting,
    required this.text,
  });

  final bool isSubmitting;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (isSubmitting) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(LucideIcons.send, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
