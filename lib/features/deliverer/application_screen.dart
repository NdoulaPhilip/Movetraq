import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';

class DelivererApplicationScreen extends StatefulWidget {
  const DelivererApplicationScreen({super.key});
  @override
  State<DelivererApplicationScreen> createState() =>
      _DelivererApplicationScreenState();
}

class _DelivererApplicationScreenState
    extends State<DelivererApplicationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  DateTime? _birth;
  String? _transport;
  int _step = 0;
  bool _lawful = false;
  bool _handling = false;
  bool _terms = false;
  bool _busy = false;
  Object? _error;
  static const _transports = {
    'motorcycle': 'Motorcycle',
    'bicycle': 'Bicycle',
    'walking': 'Walking',
    'car': 'Car',
    'van': 'Van',
    'other_motor': 'Other motor vehicle',
    'other_non_motor': 'Other non-motor transport',
  };
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 0) {
      if (!_form.currentState!.validate()) return;
      final now = DateTime.now();
      final eighteenthBirthday = _birth == null
          ? null
          : DateTime(_birth!.year + 18, _birth!.month, _birth!.day);
      if (eighteenthBirthday == null || eighteenthBirthday.isAfter(now)) {
        setState(() =>
            _error = StateError('Applicants must be at least 18 years old.'));
        return;
      }
    }
    if (_step == 1 && _transport == null) {
      setState(() => _error = StateError('Choose a transport type.'));
      return;
    }
    if (_step == 2 && (!_lawful || !_handling || !_terms)) {
      setState(() => _error =
          StateError('Confirm the safety declarations before continuing.'));
      return;
    }
    if (_step < 3) {
      setState(() {
        _step++;
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FeatureGateway(context.read<LocalDataService>())
          .request(
              'Deliverer applications', 'POST', '/deliverers/me/applications',
              body: {
            'identity': {
              'fullName': _name.text.trim(),
              'dateOfBirth':
                  '${_birth!.year}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}'
            },
            'transportType': _transport,
            'safety': {
              'lawfulTransport': _lawful,
              'safeHandling': _handling,
              'termsAccepted': _terms
            },
          });
      if (mounted) {
        Navigator.pushNamed(context, '/verification', arguments: result['id']);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
          title: _step == 3 ? 'Review application' : 'Your application',
          children: [
            Wrap(
                spacing: 8,
                children: ['Personal', 'Transport', 'Safety', 'Review']
                    .asMap()
                    .entries
                    .map((entry) => ChoiceChip(
                        label: Text(entry.value),
                        selected: _step == entry.key,
                        onSelected: null))
                    .toList()),
            const SizedBox(height: 20),
            if (_step == 0) ...[
              const InfoBand(title: 'About you', icon: Icons.person_outline),
              Form(
                  key: _form,
                  child: TextFormField(
                      controller: _name,
                      decoration:
                          const InputDecoration(labelText: 'Legal full name'),
                      validator: (value) => (value ?? '').trim().length < 2
                          ? 'Enter your legal name'
                          : null)),
              const SizedBox(height: 16),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(_birth == null
                      ? 'Date of birth'
                      : '${_birth!.day}/${_birth!.month}/${_birth!.year}'),
                  onTap: () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                        context: context,
                        initialDate: _birth ??
                            DateTime(now.year - 18, now.month, now.day),
                        firstDate: DateTime(now.year - 100),
                        lastDate: now);
                    if (date != null && mounted) setState(() => _birth = date);
                  }),
            ],
            if (_step == 1) ...[
              const SectionTitle('How will you deliver?'),
              DropdownButtonFormField<String>(
                  initialValue: _transport,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Transport'),
                  items: _transports.entries
                      .map((entry) => DropdownMenuItem(
                          value: entry.key, child: Text(entry.value)))
                      .toList(),
                  onChanged: (value) => setState(() => _transport = value)),
              const SizedBox(height: 18),
              const InfoBand(
                  title: 'Verification documents',
                  body:
                      'Identity documents are required. Motor vehicles may also require a licence, registration and insurance. Your approved policy is checked by the server.',
                  icon: Icons.fact_check_outlined),
            ],
            if (_step == 2) ...[
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                      'My transport meets applicable safety requirements.'),
                  value: _lawful,
                  onChanged: (value) =>
                      setState(() => _lawful = value ?? false)),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I can collect and handle parcels safely.'),
                  value: _handling,
                  onChanged: (value) =>
                      setState(() => _handling = value ?? false)),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I agree to the delivery work terms.'),
                  value: _terms,
                  onChanged: (value) =>
                      setState(() => _terms = value ?? false)),
            ],
            if (_step == 3) ...[
              DetailRow('Full name', _name.text),
              DetailRow('Date of birth',
                  '${_birth!.day}/${_birth!.month}/${_birth!.year}'),
              DetailRow('Transport', _transports[_transport]!),
              const DetailRow('Safety declarations', 'Confirmed'),
              const InfoBand(
                  title: 'Approval is required',
                  body:
                      'Saving an application does not activate deliverer access. Upload and submit your required documents for review.'),
            ],
            if (_error != null) LoadError(error: _error!),
            const SizedBox(height: 18),
            PrimaryButton(
                label: _step == 3 ? 'Save application & continue' : 'Continue',
                loading: _busy,
                onPressed: _next),
            if (_step > 0)
              TextButton.icon(
                  onPressed: _busy ? null : () => setState(() => _step--),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Back')),
          ]);
}

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key, this.applicationId = ''});
  final String applicationId;
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.applicationId.isEmpty
        ? Future.value({'status': 'not_started'})
        : FeatureGateway(context.read<LocalDataService>()).request(
            'Verification',
            'GET',
            '/deliverers/me/applications/${widget.applicationId}');
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Delivery verification', children: [
        FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return LoadError(
                    error: snapshot.error!, onRetry: () => setState(_load));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final status =
                  snapshot.data!['status']?.toString() ?? 'not_started';
              return InfoBand(
                  title: status.replaceAll('_', ' '),
                  body: 'Private documents are reviewed before approval.',
                  icon: Icons.verified_user_outlined);
            }),
        const RouteTile(
            title: 'Identity information',
            icon: Icons.person_outline,
            route: '/deliverer-apply'),
        RouteTile(
            title: 'Verification documents',
            icon: Icons.description_outlined,
            route: '/verification-documents',
            arguments: widget.applicationId),
        const RouteTile(
            title: 'Transport & delivery area',
            icon: Icons.local_shipping_outlined,
            route: '/deliverer-work-settings'),
        const RouteTile(
            title: 'Safety information',
            icon: Icons.shield_outlined,
            route: '/safety'),
        const SizedBox(height: 24),
        PrimaryButton(
            label: widget.applicationId.isEmpty
                ? 'Start application'
                : 'Submit for review',
            loading: _busy,
            onPressed: () async {
              if (widget.applicationId.isEmpty) {
                Navigator.pushNamed(context, '/deliverer-apply');
                return;
              }
              setState(() => _busy = true);
              try {
                await FeatureGateway(context.read<LocalDataService>()).request(
                    'Verification',
                    'POST',
                    '/deliverers/me/applications/${widget.applicationId}/submit');
                if (mounted) setState(_load);
              } catch (error) {
                if (context.mounted) showActionError(context, error);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            }),
      ]);
}
