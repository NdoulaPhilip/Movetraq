import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.service, this.initialSchedule});
  final String service;
  final DateTime? initialSchedule;
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  int _step = 0;
  String _task = 'shopping';
  String _loadType = 'Furniture';
  String _vehicle = 'van';
  String _pickupAccess = 'ground';
  String _dropoffAccess = 'ground';
  int _helpers = 0;
  bool _scheduled = false;
  DateTime? _when;
  bool _busy = false;
  Object? _error;
  Map<String, dynamic>? _quote;

  bool get _move => widget.service == 'big_move';
  bool get _errand => widget.service == 'errand';
  String get _title => _move
      ? 'Plan a big move'
      : _errand
          ? 'Run an errand'
          : 'Create a delivery request';

  @override
  void initState() {
    super.initState();
    for (final key in [
      'instructions',
      'budget',
      'items',
      'pickup',
      'destination',
      'name',
      'phone',
      'weight',
      'offer'
    ]) {
      _fields[key] = TextEditingController();
    }
    _when = widget.initialSchedule;
    _scheduled = _move || _when != null;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, String label,
          {bool multiline = false,
          bool money = false,
          bool optional = false,
          bool number = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: TextFormField(
            controller: _fields[key],
            decoration: InputDecoration(labelText: label),
            maxLines: multiline ? 4 : 1,
            keyboardType: money || number
                ? const TextInputType.numberWithOptions(decimal: true)
                : key == 'phone'
                    ? TextInputType.phone
                    : TextInputType.text,
            validator: (input) {
              final value = (input ?? '').trim();
              if (optional && value.isEmpty) return null;
              if (value.isEmpty) return 'Required';
              if (money && parseMinorUnits(value) == null) {
                return 'Enter a valid amount';
              }
              if (number &&
                  (double.tryParse(value) == null ||
                      double.parse(value) <= 0)) {
                return 'Enter a weight greater than zero';
              }
              if (key == 'phone' &&
                  !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value)) {
                return 'Use a phone number including country code';
              }
              return null;
            },
          ));

  Widget _options(String label, List<String> values, String selected,
          ValueChanged<String> change) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(label),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values
                  .map((value) => ChoiceChip(
                        label: Text(value.replaceAll('_', ' ')),
                        selected: selected == value,
                        onSelected: (_) => setState(() => change(value)),
                      ))
                  .toList()),
          const SizedBox(height: 12),
        ],
      );

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final day = await showDatePicker(
        context: context,
        firstDate: DateUtils.dateOnly(now),
        lastDate: now.add(const Duration(days: 180)),
        initialDate: _when ?? now.add(const Duration(days: 1)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: _when == null
            ? const TimeOfDay(hour: 10, minute: 0)
            : TimeOfDay.fromDateTime(_when!));
    if (time == null || !mounted) return;
    setState(() {
      _when = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      _error = null;
    });
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_step < 3) {
      if (!_form.currentState!.validate()) return;
      if (_step == 2 &&
          _scheduled &&
          (_when == null || !_when!.isAfter(DateTime.now()))) {
        setState(() => _error = StateError('Choose a future pickup time.'));
        return;
      }
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
      if (!FeatureGateway.enabled) {
        throw const FeatureUnavailable('Service quotes');
      }
      final data = context.read<LocalDataService>();
      final pickup = await data.resolveAddressLocation(_fields['pickup']!.text);
      final destination =
          await data.resolveAddressLocation(_fields['destination']!.text);
      if (pickup == null || destination == null) {
        throw StateError('Both route addresses must resolve to a location.');
      }
      final quote = await FeatureGateway(data)
          .request('Service quotes', 'POST', '/quotes', body: {
        'serviceType': widget.service,
        'pickup': {
          'address': _fields['pickup']!.text.trim(),
          ...pickup.toJson()
        },
        'destination': {
          'address': _fields['destination']!.text.trim(),
          ...destination.toJson()
        },
        'recipient': {
          'name': _fields['name']!.text.trim(),
          'phone': _fields['phone']!.text.trim()
        },
        'parcel': {
          'description': _fields['items']!.text.trim(),
          'weightKg': double.parse(_fields['weight']!.text)
        },
        if (_scheduled) 'scheduledAt': _when!.toUtc().toIso8601String(),
        if (_scheduled) 'scheduledTimezone': 'Africa/Lagos',
        if (widget.service == 'p2p')
          'offerMinor': parseMinorUnits(_fields['offer']!.text),
        'serviceDetails': _move
            ? {
                'loadType': _loadType,
                'items': _fields['items']!.text.trim(),
                'vehicleSize': _vehicle,
                'helpers': _helpers,
                'pickupAccess': _pickupAccess,
                'destinationAccess': _dropoffAccess
              }
            : _errand
                ? {
                    'task': _task,
                    'instructions': _fields['instructions']!.text.trim(),
                    'shoppingBudgetMinor': _task == 'shopping'
                        ? parseMinorUnits(_fields['budget']!.text) ?? 0
                        : 0
                  }
                : {'notes': _fields['instructions']!.text.trim()},
      });
      if (mounted) setState(() => _quote = quote);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: _step == 3
            ? _move
                ? 'Review your big move'
                : _errand
                    ? 'Review your errand'
                    : 'Review your request'
            : _title,
        children: [
          InfoBand(
              title: _move
                  ? 'A smoother move starts here.'
                  : _errand
                      ? 'Your to-do list, taken care of.'
                      : 'Your parcel. Your route.',
              icon: _move
                  ? Icons.local_shipping_outlined
                  : Icons.shopping_bag_outlined),
          Row(
              children: List.generate(
                  4,
                  (index) => Expanded(
                          child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  height: 3,
                                  color: index <= _step
                                      ? AppColors.accent
                                      : AppColors.borderSoft),
                              const SizedBox(height: 7),
                              Text(
                                  [
                                    'Details',
                                    'Route',
                                    'Schedule',
                                    'Review'
                                  ][index],
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: index == _step
                                          ? AppColors.ink
                                          : AppColors.muted)),
                            ]),
                      )))),
          const SizedBox(height: 20),
          Form(
              key: _form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_step == 0) ...[
                      SectionTitle(_move
                          ? 'Tell us about your load'
                          : _errand
                              ? 'What needs doing?'
                              : 'Parcel details'),
                      if (_move)
                        _options(
                            'What are you moving?',
                            [
                              'Furniture',
                              'Appliances',
                              'Room move',
                              'Office move'
                            ],
                            _loadType,
                            (value) => _loadType = value),
                      if (_errand)
                        _options(
                            'What can we help with?',
                            ['shopping', 'pickup_dropoff', 'other'],
                            _task,
                            (value) => _task = value),
                      _field('items',
                          _move ? 'Items to move' : 'Parcel description',
                          multiline: true),
                      if (!_move)
                        _field('instructions', 'Your list & instructions',
                            multiline: true, optional: !_errand),
                      if (_errand && _task == 'shopping') ...[
                        _field('budget', 'Maximum shopping spend (NGN)',
                            money: true),
                        const InfoBand(
                            title: 'Spending limit',
                            body:
                                'Shopping money is separate from the delivery service fee.',
                            icon: Icons.shopping_basket_outlined),
                      ],
                      _field('weight', 'Estimated weight (kg)', number: true),
                      if (widget.service == 'p2p')
                        _field('offer', 'Your offer (NGN)', money: true),
                      if (_move) ...[
                        _options('Vehicle', ['car', 'van', 'large_van'],
                            _vehicle, (value) => _vehicle = value),
                        _options(
                            'Loading helpers',
                            ['0', '1', '2'],
                            '$_helpers',
                            (value) => _helpers = int.parse(value)),
                      ],
                    ],
                    if (_step == 1) ...[
                      _field('pickup', 'Pickup address'),
                      _field('destination', 'Delivery address'),
                      _field('name', 'Recipient name'),
                      _field('phone', 'Recipient phone (+country code)'),
                      if (_move) ...[
                        _options('Pickup access', ['ground', 'stairs', 'lift'],
                            _pickupAccess, (value) => _pickupAccess = value),
                        _options(
                            'Drop-off access',
                            ['ground', 'stairs', 'lift'],
                            _dropoffAccess,
                            (value) => _dropoffAccess = value),
                      ],
                    ],
                    if (_step == 2) ...[
                      if (!_move)
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Schedule collection'),
                            value: _scheduled,
                            onChanged: (value) =>
                                setState(() => _scheduled = value)),
                      if (_scheduled)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_month_outlined),
                            title: Text(_when == null
                                ? 'Choose pickup date and time'
                                : '${_when!.day}/${_when!.month}/${_when!.year} ${TimeOfDay.fromDateTime(_when!).format(context)}'),
                            subtitle: const Text('Africa/Lagos'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _pickSchedule),
                      if (!_scheduled)
                        const InfoBand(
                            title: 'Soonest available pickup',
                            icon: Icons.schedule),
                    ],
                    if (_step == 3) ...[
                      DetailRow('Service', widget.service.replaceAll('_', ' ')),
                      DetailRow('Parcel', _fields['items']!.text),
                      DetailRow('Pickup', _fields['pickup']!.text),
                      DetailRow('Destination', _fields['destination']!.text),
                      DetailRow('Recipient', _fields['name']!.text),
                      DetailRow('Phone', _fields['phone']!.text),
                      DetailRow('Collection',
                          _scheduled ? _when.toString() : 'Soonest available'),
                      if (_errand && _task == 'shopping')
                        DetailRow('Shopping spending limit',
                            'NGN ${_fields['budget']!.text}'),
                      if (_move) ...[
                        DetailRow('Vehicle', _vehicle),
                        DetailRow('Helpers', '$_helpers'),
                        DetailRow('Access', '$_pickupAccess / $_dropoffAccess')
                      ],
                      const SizedBox(height: 18),
                      if (_quote == null)
                        const InfoBand(
                            title: 'Delivery fee',
                            body: 'Awaiting a server-calculated quote.',
                            icon: Icons.receipt_long_outlined)
                      else ...[
                        DetailRow(
                            'Quote reference',
                            (_quote!['id'] ?? _quote!['quoteId'] ?? '')
                                .toString()),
                        PrimaryButton(
                            label: 'Continue to payment',
                            onPressed: () => Navigator.pushNamed(
                                context, '/payment',
                                arguments: _quote)),
                      ],
                    ],
                  ])),
          if (_error != null) LoadError(error: _error!),
          const SizedBox(height: 18),
          PrimaryButton(
              label: _step == 3 ? 'Get delivery quote' : 'Continue',
              loading: _busy,
              onPressed: _next),
          if (_step > 0)
            TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _step--;
                          _quote = null;
                        }),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Back')),
        ],
      );
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime? _date;
  TimeOfDay? _time;
  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Schedule a delivery', children: [
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(_date == null
                ? 'Pickup date'
                : '${_date!.day}/${_date!.month}/${_date!.year}'),
            onTap: () async {
              final now = DateTime.now();
              final value = await showDatePicker(
                  context: context,
                  initialDate: _date ?? now.add(const Duration(days: 1)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 180)));
              if (value != null && mounted) setState(() => _date = value);
            }),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(_time == null ? 'Pickup time' : _time!.format(context)),
            onTap: () async {
              final value = await showTimePicker(
                  context: context,
                  initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0));
              if (value != null && mounted) setState(() => _time = value);
            }),
        const DetailRow('Timezone', 'Africa/Lagos'),
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'Continue to parcel details',
            onPressed: _date == null || _time == null
                ? null
                : () {
                    final value = DateTime(_date!.year, _date!.month,
                        _date!.day, _time!.hour, _time!.minute);
                    if (!value.isAfter(DateTime.now())) {
                      showActionError(context,
                          StateError('Choose a future collection time.'));
                      return;
                    }
                    Navigator.pushNamed(context, '/p2p-request',
                        arguments: value);
                  }),
      ]);
}
