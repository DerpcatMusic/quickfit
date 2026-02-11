import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:quickfit/core/models/zone.dart';
import 'package:quickfit/core/providers/zone_provider.dart';
import 'package:quickfit/core/services/location_service.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/l10n/app_localizations.dart';

enum SelectionMode { radius, zones }

class MapSettingsSheet extends ConsumerStatefulWidget {
  const MapSettingsSheet({
    super.key,
    required this.mode,
    required this.radiusKm,
    required this.selectedZoneIds,
    required this.isExpanded,
    required this.addressController,
    required this.isResolvingAddress,
    required this.isPinDropMode,
    required this.onToggleExpanded,
    required this.onTogglePinDropMode,
    required this.onApplyAddress,
    required this.onAddressSelected,
    required this.onModeChanged,
    required this.onRadiusChanged,
    required this.onRadiusChangeEnd,
  });

  final SelectionMode mode;
  final double radiusKm;
  final Set<String> selectedZoneIds;
  final bool isExpanded;
  final TextEditingController addressController;
  final bool isResolvingAddress;
  final bool isPinDropMode;
  final VoidCallback onToggleExpanded;
  final VoidCallback onTogglePinDropMode;
  final VoidCallback onApplyAddress;
  final void Function({
    required String address,
    required double? latitude,
    required double? longitude,
  }) onAddressSelected;
  final ValueChanged<SelectionMode> onModeChanged;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onRadiusChangeEnd;

  @override
  ConsumerState<MapSettingsSheet> createState() => _MapSettingsSheetState();
}

class _MapSettingsSheetState extends ConsumerState<MapSettingsSheet> {
  static const double _minRadiusKm = 0.1;
  static const double _maxRadiusKm = 15.0;
  static const double _radiusStepKm = 0.05;
  static const List<double> _quickRadiusOptions = <double>[0.5, 1, 2, 5, 10];
  late double _editableRadiusKm;

  @override
  void initState() {
    super.initState();
    _editableRadiusKm = widget.radiusKm.clamp(_minRadiusKm, _maxRadiusKm);
  }

  @override
  void didUpdateWidget(covariant MapSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.radiusKm - oldWidget.radiusKm).abs() > 0.001) {
      _editableRadiusKm = widget.radiusKm.clamp(_minRadiusKm, _maxRadiusKm);
    }
  }

  void _selectMode(SelectionMode mode) {
    if (widget.mode == mode) return;
    widget.onModeChanged(mode);
  }

  void _setRadius(double value) {
    final snapped = (value / _radiusStepKm).round() * _radiusStepKm;
    final nextValue = snapped.clamp(_minRadiusKm, _maxRadiusKm);
    setState(() {
      _editableRadiusKm = nextValue;
    });
    widget.onRadiusChanged(nextValue);
  }

  void _commitRadius() {
    widget.onRadiusChangeEnd();
  }

  String _radiusDisplay(double value) {
    if (value < 1) return value.toStringAsFixed(2);
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final zonesAsync = ref.watch(zonesProvider);
    final selectedNames = _selectedZoneNames(zonesAsync);
    final l10n = AppLocalizations.of(context)!;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).top -
        viewInsetsBottom -
        24;
    final maxExpandedHeight = availableHeight.clamp(240.0, 520.0).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onPanStart: (_) {},
      onPanUpdate: (_) {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.cardBorder),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          16 + viewInsetsBottom,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: widget.onToggleExpanded,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          LucideIcons.settings2,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.mode == SelectionMode.radius
                              ? '${l10n.instructorMapServiceArea}: ${l10n.radiusKmLabel(_radiusDisplay(_editableRadiusKm))}'
                              : l10n.zonesSelectedLabel(
                                  widget.selectedZoneIds.length),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        widget.isExpanded
                            ? LucideIcons.chevronDown
                            : LucideIcons.chevronUp,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.isExpanded) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxExpandedHeight),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              _buildModeTab(
                                label: l10n.mapModeRadius,
                                icon: LucideIcons.locateFixed,
                                mode: SelectionMode.radius,
                              ),
                              _buildModeTab(
                                label: l10n.mapModeZones,
                                icon: LucideIcons.map,
                                mode: SelectionMode.zones,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: widget.mode == SelectionMode.radius
                              ? _buildRadiusSection(theme)
                              : _buildZonesSection(
                                  theme, zonesAsync, selectedNames),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadiusSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const ValueKey<String>('radius-section'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.radiusKmLabel(_radiusDisplay(_editableRadiusKm)),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: widget.isPinDropMode
                    ? l10n.cancel
                    : l10n.instructorMapDropPinTooltip,
                onPressed: widget.onTogglePinDropMode,
                style: IconButton.styleFrom(
                  backgroundColor: widget.isPinDropMode
                      ? theme.colorScheme.primary.withValues(alpha: 0.14)
                      : theme.colorScheme.surface,
                ),
                icon: Icon(
                  LucideIcons.locate,
                  size: 18,
                  color: widget.isPinDropMode
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Slider.adaptive(
            value: _editableRadiusKm.clamp(_minRadiusKm, _maxRadiusKm),
            min: _minRadiusKm,
            max: _maxRadiusKm,
            divisions: ((_maxRadiusKm - _minRadiusKm) / _radiusStepKm).round(),
            onChanged: _setRadius,
            onChangeEnd: (_) => _commitRadius(),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickRadiusOptions.map((option) {
              final isSelected = (_editableRadiusKm - option).abs() < 0.1;
              return ChoiceChip(
                label: Text(l10n.radiusKmLabel(_radiusDisplay(option))),
                selected: isSelected,
                onSelected: (_) {
                  _setRadius(option);
                  _commitRadius();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TypeAheadField<Map<String, dynamic>>(
                  controller: widget.addressController,
                  direction: VerticalDirection.up,
                  autoFlipDirection: true,
                  constraints: const BoxConstraints(maxHeight: 240),
                  offset: const Offset(0, 8),
                  debounceDuration: const Duration(milliseconds: 280),
                  hideOnEmpty: true,
                  hideOnError: true,
                  decorationBuilder: (context, child) => PointerInterceptor(
                    child: Material(
                      elevation: 10,
                      color: theme.colorScheme.surface,
                      shadowColor: Colors.black.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: child,
                    ),
                  ),
                  suggestionsCallback: (pattern) => LocationService.instance
                      .getAutocompleteSuggestions(pattern),
                  itemBuilder: (context, suggestion) {
                    final label =
                        (suggestion['label'] ?? suggestion['description'] ?? '')
                            .toString();
                    final city = (suggestion['city'] ?? '').toString().trim();
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(LucideIcons.mapPin, size: 16),
                      title: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: city.isEmpty
                          ? null
                          : Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    );
                  },
                  loadingBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  emptyBuilder: (context) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      l10n.instructorMapAddressNotFound,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  onSelected: (suggestion) {
                    final address =
                        (suggestion['label'] ?? suggestion['description'] ?? '')
                            .toString()
                            .trim();
                    final latitude = (suggestion['lat'] as num?)?.toDouble();
                    final longitude = (suggestion['lng'] as num?)?.toDouble();
                    widget.onAddressSelected(
                      address: address,
                      latitude: latitude,
                      longitude: longitude,
                    );
                  },
                  builder: (context, controller, focusNode) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => widget.onApplyAddress(),
                    decoration: InputDecoration(
                      hintText: l10n.homeAddress,
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: l10n.mapApply,
                onPressed:
                    widget.isResolvingAddress ? null : widget.onApplyAddress,
                icon: widget.isResolvingAddress
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.check, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZonesSection(
    ThemeData theme,
    AsyncValue<List<Zone>> zonesAsync,
    List<String> selectedNames,
  ) {
    final selectedCount = widget.selectedZoneIds.length;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      key: const ValueKey<String>('zones-section'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.mapActiveCount(selectedCount),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.info,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.mapZoneSelectionHint,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (zonesAsync.isLoading)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.mapLoadingZones,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            )
          else if (selectedNames.isEmpty)
            Text(
              selectedCount == 0
                  ? l10n.mapNoZonesSelectedYet
                  : l10n.zonesSelectedLabel(selectedCount),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedNames.map((name) {
                return Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(name),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required SelectionMode mode,
  }) {
    final theme = Theme.of(context);
    final isSelected = widget.mode == mode;

    return Expanded(
      child: InkWell(
        onTap: () => _selectMode(mode),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _selectedZoneNames(AsyncValue<List<Zone>> zonesAsync) {
    return zonesAsync.maybeWhen(
      data: (zones) {
        final names = zones
            .where((zone) => widget.selectedZoneIds.contains(zone.id))
            .map((zone) => zone.name)
            .where((name) => name.trim().isNotEmpty)
            .take(4)
            .toList();
        return names;
      },
      orElse: () => const <String>[],
    );
  }
}
