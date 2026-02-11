import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:quickfit/core/services/convex_service.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/l10n/app_localizations.dart';

class StudioBillingSheet {
  StudioBillingSheet._();

  static String providerLabel(BuildContext context, String provider) {
    final l10n = AppLocalizations.of(context)!;
    switch (provider.toLowerCase()) {
      case 'morning':
        return l10n.studioBillingProviderMorning;
      case 'icount':
        return l10n.studioBillingProviderIcount;
      default:
        return provider;
    }
  }

  static String summaryFromIntegrations(
    List<Map<String, dynamic>> rows, {
    required BuildContext context,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final active = rows.cast<Map<String, dynamic>?>().firstWhere(
          (row) => row?['isActive'] == true,
          orElse: () => null,
        );
    if (active == null) {
      return l10n.studioBillingSummaryNotConnected;
    }
    final provider = (active['provider']?.toString() ?? '').toLowerCase();
    if (provider == 'morning') {
      return l10n.studioBillingSummaryMorningActive;
    }
    if (provider == 'icount') {
      return l10n.studioBillingSummaryIcountActive;
    }
    return l10n.studioBillingSummaryConnected;
  }

  static Future<void> show(
    BuildContext context, {
    Future<void> Function()? onUpdated,
  }) async {
    var isLoading = false;
    var integrations =
        await ConvexService.instance.getMyInvoicingIntegrations();
    if (!context.mounted) return;

    Future<void> refresh(StateSetter setModalState) async {
      setModalState(() => isLoading = true);
      integrations = await ConvexService.instance.getMyInvoicingIntegrations();
      if (!context.mounted) return;
      setModalState(() => isLoading = false);
      if (onUpdated != null) await onUpdated();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final theme = Theme.of(sheetContext);
            final colors = sheetContext.colors;
            final l10n = AppLocalizations.of(sheetContext)!;
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.divider,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.profileStudioBillingTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.profileStudioBillingSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              LucideIcons.shield,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.studioBillingPlatformManagedNotice,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.studioBillingInvoicingSectionTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (integrations.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: theme.colorScheme.outlineVariant),
                        ),
                        child: Text(l10n.studioBillingNoProviderConnected),
                      )
                    else
                      ...integrations.map(
                        (item) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: theme.colorScheme.outlineVariant),
                          ),
                          child: ListTile(
                            title: Text(providerLabel(sheetContext,
                                item['provider']?.toString() ?? '')),
                            subtitle: Text(item['isActive'] == true
                                ? l10n.studioBillingStatusActive
                                : l10n.studioBillingStatusInactive),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                final provider =
                                    item['provider']?.toString() ?? '';
                                if (provider.isEmpty) return;
                                if (value == 'edit') {
                                  await _showEditor(
                                    context,
                                    provider: provider,
                                    existing: item,
                                  );
                                  await refresh(setModalState);
                                  return;
                                }
                                if (value == 'activate') {
                                  await ConvexService.instance
                                      .setMyInvoicingIntegrationActive(
                                    provider: provider,
                                    isActive: true,
                                  );
                                  await refresh(setModalState);
                                  return;
                                }
                                if (value == 'deactivate') {
                                  await ConvexService.instance
                                      .setMyInvoicingIntegrationActive(
                                    provider: provider,
                                    isActive: false,
                                  );
                                  await refresh(setModalState);
                                  return;
                                }
                                if (value == 'remove') {
                                  await ConvexService.instance
                                      .removeMyInvoicingIntegration(
                                    provider: provider,
                                  );
                                  await refresh(setModalState);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(l10n.studioBillingMenuEdit),
                                ),
                                if (item['isActive'] == true)
                                  PopupMenuItem(
                                    value: 'deactivate',
                                    child: Text(
                                      l10n.studioBillingMenuSetInactive,
                                    ),
                                  )
                                else
                                  PopupMenuItem(
                                    value: 'activate',
                                    child: Text(
                                      l10n.studioBillingMenuSetActive,
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text(l10n.studioBillingMenuRemove),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _showEditor(context, provider: 'morning');
                              await refresh(setModalState);
                            },
                            icon: const Icon(LucideIcons.fileText, size: 16),
                            label: Text(l10n.studioBillingConnectMorning),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _showEditor(context, provider: 'icount');
                              await refresh(setModalState);
                            },
                            icon: const Icon(LucideIcons.receipt, size: 16),
                            label: Text(l10n.studioBillingConnectIcount),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _showEditor(
    BuildContext context, {
    required String provider,
    Map<String, dynamic>? existing,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final label = providerLabel(context, provider);
    final baseUrlController = TextEditingController(
      text: existing?['baseUrl']?.toString() ?? '',
    );
    final secretController = TextEditingController();
    final accountIdController = TextEditingController(
      text: existing?['accountId']?.toString() ?? '',
    );
    final vatRateController = TextEditingController(
      text: (existing?['defaultVatRate']?.toString() ?? '').trim(),
    );

    final isMorning = provider.toLowerCase() == 'morning';
    String? errorText;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setSheetState) {
          Future<void> save() async {
            final baseUrl = baseUrlController.text.trim();
            final secret = secretController.text.trim();
            if (baseUrl.isEmpty) {
              setSheetState(
                  () => errorText = l10n.studioBillingBaseUrlRequired);
              return;
            }
            if (!baseUrl.startsWith('https://')) {
              setSheetState(
                  () => errorText = l10n.studioBillingBaseUrlHttpsRequired);
              return;
            }
            if (existing == null && secret.isEmpty) {
              setSheetState(
                () => errorText = isMorning
                    ? l10n.studioBillingApiTokenRequired
                    : l10n.studioBillingApiKeyRequired,
              );
              return;
            }

            setSheetState(() {
              errorText = null;
              isSaving = true;
            });

            try {
              await ConvexService.instance.upsertMyInvoicingIntegration(
                provider: provider,
                baseUrl: baseUrl,
                isActive: true,
                accountId: accountIdController.text.trim().isEmpty
                    ? null
                    : accountIdController.text.trim(),
                defaultVatRate: vatRateController.text.trim().isEmpty
                    ? null
                    : double.tryParse(vatRateController.text.trim()),
                apiToken: isMorning ? (secret.isEmpty ? null : secret) : null,
                apiKey: isMorning ? null : (secret.isEmpty ? null : secret),
              );

              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.studioBillingConnected(label))),
              );
            } catch (e) {
              setSheetState(() {
                errorText = e.toString();
                isSaving = false;
              });
            }
          }

          final secretLabel = isMorning
              ? l10n.studioBillingApiTokenLabel
              : l10n.studioBillingApiKeyLabel;

          return AlertDialog(
            title: Text(
              existing == null
                  ? l10n.studioBillingConnectProvider(label)
                  : l10n.studioBillingEditProvider(label),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: baseUrlController,
                    decoration: InputDecoration(
                        labelText: l10n.studioBillingBaseUrlLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: secretController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: secretLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: accountIdController,
                    decoration: InputDecoration(
                      labelText: l10n.studioBillingAccountIdOptionalLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: vatRateController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.studioBillingDefaultVatOptionalLabel,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSaving ? null : () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }
}
