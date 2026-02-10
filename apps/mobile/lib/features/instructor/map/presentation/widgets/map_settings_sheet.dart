import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:quickfit/core/providers/zone_provider.dart';

enum SelectionMode { radius, zones }

class MapSettingsSheet extends ConsumerStatefulWidget {
  const MapSettingsSheet({
    super.key,
    required this.initialMode,
    required this.initialRadius,
    required this.selectedZoneIds,
    required this.onSave,
    required this.onModeChanged,
    required this.onRadiusChanged,
  });

  final SelectionMode initialMode;
  final double initialRadius;
  final Set<String> selectedZoneIds;
  final Future<void> Function() onSave;
  final ValueChanged<SelectionMode> onModeChanged;
  final ValueChanged<double> onRadiusChanged;

  static void show(
    BuildContext context, {
    required SelectionMode mode,
    required double radius,
    required Set<String> selectedZones,
    required Future<void> Function() onSave,
    required ValueChanged<SelectionMode> onModeChanged,
    required ValueChanged<double> onRadiusChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, scrollController) => MapSettingsSheet(
          initialMode: mode,
          initialRadius: radius,
          selectedZoneIds: selectedZones,
          onSave: onSave,
          onModeChanged: onModeChanged,
          onRadiusChanged: onRadiusChanged,
        ),
      ),
    );
  }

  @override
  ConsumerState<MapSettingsSheet> createState() => _MapSettingsSheetState();
}

class _MapSettingsSheetState extends ConsumerState<MapSettingsSheet> {
  late SelectionMode _mode;
  late double _radiusKm;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _radiusKm = widget.initialRadius;
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    await widget.onSave();
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zonesAsync = ref.watch(zonesProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView(
        // padding: const EdgeInsets.all(24), // Avoid padding here if controller is used with custom
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Search Settings',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Toggle Mode
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildToggleItem(
                    theme, 'Radius', SelectionMode.radius, LucideIcons.circle),
                _buildToggleItem(
                    theme, 'Zones', SelectionMode.zones, LucideIcons.map),
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (_mode == SelectionMode.radius) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Search Radius',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${_radiusKm.toStringAsFixed(1)} km',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.primaryContainer,
                thumbColor: theme.colorScheme.primary,
                overlayColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _radiusKm.clamp(0.5, 15.0),
                min: 0.5,
                max: 15.0,
                onChanged: (v) {
                  setState(() => _radiusKm = v);
                  widget.onRadiusChanged(v);
                },
              ),
            ),
          ] else ...[
            // Zone Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info,
                      size: 20, color: theme.colorScheme.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          'Selected zones are managed directly on the map. Close this menu to interact.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (zonesAsync.isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Text(
                '${widget.selectedZoneIds.length} zones active',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold),
              ),
          ],

          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save & Update Map',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildToggleItem(
      ThemeData theme, String label, SelectionMode mode, IconData icon) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _mode = mode);
          widget.onModeChanged(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
