import 'package:flutter/material.dart';
import 'package:quickfit/core/services/convex_service.dart';
import 'package:quickfit/shared/widgets/adaptive_app_bar.dart';

class InstructorPayoutDestinationsScreen extends StatefulWidget {
  const InstructorPayoutDestinationsScreen({super.key});

  @override
  State<InstructorPayoutDestinationsScreen> createState() =>
      _InstructorPayoutDestinationsScreenState();
}

class _InstructorPayoutDestinationsScreenState
    extends State<InstructorPayoutDestinationsScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _destinations = <Map<String, dynamic>>[];

  final _recipientIdController = TextEditingController();
  final _labelController = TextEditingController();
  final _last4Controller = TextEditingController();
  final _countryController = TextEditingController(text: 'IL');
  final _currencyController = TextEditingController(text: 'ILS');

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  @override
  void dispose() {
    _recipientIdController.dispose();
    _labelController.dispose();
    _last4Controller.dispose();
    _countryController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    setState(() => _loading = true);
    final rows = await ConvexService.instance.listMyPayoutDestinations();
    if (!mounted) return;
    setState(() {
      _destinations = rows;
      _loading = false;
    });
  }

  Future<void> _saveDestination() async {
    final recipientId = _recipientIdController.text.trim();
    if (recipientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipient ID is required')),
      );
      return;
    }
    setState(() => _saving = true);
    final saved = await ConvexService.instance.upsertMyPayoutDestination(
      provider: 'rapyd',
      type: 'bank_account',
      externalRecipientId: recipientId,
      label: _labelController.text.trim().isEmpty
          ? null
          : _labelController.text.trim(),
      last4: _last4Controller.text.trim().isEmpty
          ? null
          : _last4Controller.text.trim(),
      country: _countryController.text.trim(),
      currency: _currencyController.text.trim(),
      isDefault: true,
      status: 'verified',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save payout destination')),
      );
      return;
    }
    _recipientIdController.clear();
    _labelController.clear();
    _last4Controller.clear();
    await _loadDestinations();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payout destination saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adaptiveAppBar(context, title: 'Payout Destinations'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Rapyd Recipient',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _recipientIdController,
                    decoration: const InputDecoration(
                      labelText: 'Recipient ID',
                      hintText: 'beneficiary_xxx',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: 'Label (optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _last4Controller,
                    decoration: const InputDecoration(
                      labelText: 'Last 4 (optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _countryController,
                          decoration: const InputDecoration(labelText: 'Country'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _currencyController,
                          decoration:
                              const InputDecoration(labelText: 'Currency'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveDestination,
                      child: Text(_saving ? 'Saving...' : 'Save Destination'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'My Destinations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_destinations.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No payout destination saved yet.'),
              ),
            )
          else
            ..._destinations.map(
              (row) => Card(
                child: ListTile(
                  title: Text(row['label']?.toString().trim().isNotEmpty == true
                      ? row['label'].toString()
                      : (row['externalRecipientId']?.toString() ?? 'Destination')),
                  subtitle: Text(
                    '${row['provider'] ?? 'unknown'} • '
                    '${row['type'] ?? 'unknown'} • '
                    '${row['status'] ?? 'unknown'}'
                    '${row['isDefault'] == true ? ' • DEFAULT' : ''}',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
