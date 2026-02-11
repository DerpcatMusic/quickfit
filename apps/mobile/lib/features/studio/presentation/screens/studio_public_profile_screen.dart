import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfit/core/router/app_routes.dart';
import 'package:quickfit/core/services/convex_service.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/l10n/app_localizations.dart';

class StudioPublicProfileScreen extends StatefulWidget {
  const StudioPublicProfileScreen({
    super.key,
    required this.studioId,
  });

  final String studioId;

  @override
  State<StudioPublicProfileScreen> createState() =>
      _StudioPublicProfileScreenState();
}

class _StudioPublicProfileScreenState extends State<StudioPublicProfileScreen> {
  Map<String, dynamic>? _payload;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload =
          await ConvexService.instance.getStudioPublicProfile(widget.studioId);
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.studioPublicProfileTitle)),
        body: Center(
          child: Text(_error!),
        ),
      );
    }

    final payload = _payload;
    if (payload == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.studioPublicProfileTitle)),
        body: Center(
          child: Text(l10n.studioPublicProfileNotFound),
        ),
      );
    }

    final studio = Map<String, dynamic>.from(payload['studio'] as Map);
    final counts = Map<String, dynamic>.from(payload['counts'] as Map);
    final jobs = (payload['jobs'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studioPublicProfileTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (studio['name'] as String?) ??
                        l10n.studioPublicProfileFallbackName,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.studioPublicProfileOpenJobsCount(
                      ((counts['openJobs'] as num?) ?? 0).toInt(),
                    ),
                  ),
                  Text(
                    l10n.studioPublicProfileActiveJobsCount(
                      ((counts['activeJobs'] as num?) ?? 0).toInt(),
                    ),
                  ),
                  if ((studio['address'] as String?)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        studio['address'] as String,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.mutedText),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.studioPublicProfileAvailableJobsTitle,
              style:
                  theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (jobs.isEmpty)
              Text(l10n.studioPublicProfileNoAvailableJobs)
            else
              ...jobs.map((job) {
                final jobId = (job['_id'] as String?) ?? '';
                final rate = ((job['currentRate'] as num?) ?? 0).toStringAsFixed(0);
                return Card(
                  child: ListTile(
                    title: Text(
                      (job['title'] as String?) ??
                          l10n.studioPublicProfileUntitledClass,
                    ),
                    subtitle: Text(
                      '${job['category'] ?? l10n.studioPublicProfileCategoryFallback} - ${l10n.currencyAmount(l10n.studioPublicProfileRateCurrency, rate)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: jobId.isEmpty
                        ? null
                        : () => context.push(
                              AppRoutes.jobDetail.replaceFirst(':id', jobId),
                            ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
