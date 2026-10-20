import '../../services/node_api_client.dart';
import '../../features/addresses/location_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/misc_models.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/send_flow_provider.dart';
import '../../services/local_data_service.dart';
import '../../services/feature_gateway.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/movetraq_brand.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/primary_button.dart';
import '../../core/theme/preferences.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});
  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _userId;
  String? _error;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = context.watch<AuthProvider>().profile;
    if (_userId != profile?.uid) {
      _userId = profile?.uid;
      _name.text = profile?.name ?? '';
      _phone.text = profile?.phone ?? '';
      _error = null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    if (_busy || auth.isBusy || !(_form.currentState?.validate() ?? false)) {
      return;
    }
    final userId = _userId;
    if (userId == null || auth.profile?.uid != userId) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await auth.updateProfile(
          name: _name.text.trim(), phone: _phone.text.trim());
      if (!mounted || auth.profile?.uid != userId) return;
      if (!saved) {
        setState(() =>
            _error = auth.errorMessage ?? 'Unable to update personal details.');
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personal details updated')));
      Navigator.maybePop(context);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Unable to update personal details. Try again.');
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    return AppPage(title: 'Personal details', children: [
      if (profile == null)
        const InfoBand(title: 'Sign in to edit your personal details.')
      else
        Form(
            key: _form,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Full name',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(counterText: ''),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter your name'
                      : null),
              const SizedBox(height: 16),
              const Text('Email address',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(profile.email)),
              const SizedBox(height: 20),
              const Text('Phone number',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(),
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    return phone.isNotEmpty &&
                            !RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone)
                        ? 'Enter a valid phone number'
                        : null;
                  }),
              const SizedBox(height: 16),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                    liveRegion: true,
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red))),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                  label: 'Save changes',
                  loading: _busy,
                  onPressed: auth.isBusy ? null : _save),
            ])),
    ]);
  }
}

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key, this.selectForBooking = false});
  final bool selectForBooking;
  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  late Stream<List<SavedAddress>> _stream;
  @override
  void initState() {
    super.initState();
    _stream = context
        .read<LocalDataService>()
        .watchSavedAddresses(context.read<AuthProvider>().profile?.uid ?? '');
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Saved addresses',
        subtitle:
            'Keep pickup and delivery locations ready for your next booking.',
        actions: [
          IconButton(
              tooltip: 'Add address',
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.pushNamed(context, '/address-edit'))
        ],
        children: [
          const Text('Select an address to use for your next delivery.',
              style: TextStyle(color: AppColors.muted, height: 1.6)),
          const SizedBox(height: 16),
          StreamBuilder<List<SavedAddress>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return LoadError(error: snapshot.error!);
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final addresses = snapshot.data!;
                if (addresses.isEmpty) {
                  return const PremiumEmptyState(
                      icon: Icons.location_on_outlined,
                      title: 'Your places, ready to go',
                      body: 'No saved addresses yet.');
                }
                return Column(children: [
                  for (final address in addresses)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DesignCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 18, color: Color(0xFF79913B)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(address.label,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                                if (address.isDefault)
                                  const DesignBadge('Current'),
                                PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_horiz),
                                    tooltip: 'Address actions',
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        Navigator.pushNamed(
                                            context, '/address-edit',
                                            arguments: address);
                                        return;
                                      }
                                      if (!await confirmAction(
                                              context,
                                              'Delete address?',
                                              address.address) ||
                                          !context.mounted) {
                                        return;
                                      }
                                      try {
                                        await context
                                            .read<LocalDataService>()
                                            .deleteAddress(
                                                context
                                                    .read<AuthProvider>()
                                                    .profile!
                                                    .uid,
                                                address.id);
                                      } catch (error) {
                                        if (context.mounted) {
                                          showActionError(context, error);
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                          PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit')),
                                          PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)))
                                        ]),
                              ]),
                              Text(address.address,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.muted,
                                      height: 1.5)),
                              const SizedBox(height: 14),
                              PrimaryButton(
                                  label: widget.selectForBooking
                                      ? 'Use for pickup'
                                      : 'Use this address',
                                  onPressed: () async {
                                    if (widget.selectForBooking) {
                                      context
                                          .read<SendFlowProvider>()
                                          .setDetails(
                                              pickupAddress: address.address,
                                              pickupLocation:
                                                  address.latitude != null &&
                                                          address.longitude !=
                                                              null
                                                      ? LatLng(
                                                          address.latitude!,
                                                          address.longitude!)
                                                      : null,
                                              clearPickupLocation:
                                                  address.latitude == null ||
                                                      address.longitude ==
                                                          null);
                                      Navigator.pop(context, address);
                                    } else {
                                      try {
                                        await FeatureGateway(context
                                                .read<LocalDataService>())
                                            .request('Current address', 'POST',
                                                '/users/me/addresses/${address.id}/select');
                                        if (context.mounted) {
                                          Navigator.pop(context, address);
                                        }
                                      } catch (error) {
                                        if (context.mounted) {
                                          showActionError(context, error);
                                        }
                                      }
                                    }
                                  }),
                            ]))),
                ]);
              }),
          const SizedBox(height: 16),
          SecondaryButton(
              label: 'Add an address',
              onPressed: () => Navigator.pushNamed(context, '/address-edit'))
        ],
      );
}

class AddressEditScreen extends StatefulWidget {
  const AddressEditScreen({super.key, this.address});
  final SavedAddress? address;
  @override
  State<AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends State<AddressEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _label, _street;
  bool _busy = false;
  Object? _error;
  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.address?.label ?? '');
    _street = TextEditingController(text: widget.address?.address ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _street.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final uid = context.read<AuthProvider>().profile?.uid;
    if (uid == null) {
      setState(() => _error = StateError('Sign in to save an address.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<LocalDataService>().saveAddress(uid,
          id: widget.address?.id,
          label: _label.text.trim(),
          address: _street.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
          title: widget.address == null ? 'Add an address' : 'Edit address',
          subtitle:
              'Add a clear address and a helpful landmark for easier collection and handover.',
          children: [
            Form(
                key: _form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Label (Home, Work...)',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: _label,
                          enabled: !_busy,
                          decoration:
                              const InputDecoration(hintText: 'Home, Work...'),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter a label'
                              : null),
                      const SizedBox(height: 20),
                      const Text('Street address',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: _street,
                          enabled: !_busy,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                              hintText: 'Street, area or landmark',
                              suffixIcon: IconButton(
                                  tooltip: 'Find an address',
                                  icon: const Icon(Icons.location_on_outlined),
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          final value = await Navigator.push<
                                                  AddressSuggestion>(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const LocationSearchScreen(
                                                          returnSelection:
                                                              true)));
                                          if (value != null && mounted) {
                                            setState(() =>
                                                _street.text = value.address);
                                          }
                                        })),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter a street address'
                              : null),
                    ])),
            const SizedBox(height: 28),
            if (_error != null) LoadError(error: _error!),
            PrimaryButton(
                label: 'Save address', loading: _busy, onPressed: _save),
          ]);
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
          title: 'Settings',
          subtitle: 'Make MoveTraq work your way.',
          children: [
            _group(context, 'SECURITY', const [
              ('Security & PIN', 'Manage your payment PIN', '/security'),
              (
                'Devices & sessions',
                'Review where you are signed in',
                '/sessions'
              ),
              (
                'Blocked people',
                'Review and unblock contacts',
                '/blocked-users'
              ),
            ]),
            _group(context, 'PREFERENCES', const [
              (
                'Notifications',
                'Delivery updates, receipts and offers',
                '/notification-preferences'
              ),
              (
                'Delivery preferences',
                'Default service and contact method',
                '/delivery-preferences'
              ),
              (
                'Display & accessibility',
                'Motion and larger form text',
                '/display-preferences'
              ),
              ('Privacy', 'Saved suggestions and personalization', '/privacy'),
            ]),
            _group(context, 'ACCOUNT', const [
              (
                'Account controls',
                'Manage your account and sign out',
                '/account-controls'
              ),
              ('About MoveTraq', 'App information', '/about'),
            ]),
          ]);
  Widget _group(BuildContext context, String label,
          List<(String, String, String)> rows) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DesignCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const SizedBox(height: 8),
                for (final row in rows)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(row.$1,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(row.$2,
                          style: const TextStyle(
                              fontSize: 11,
                              height: 1.6,
                              color: AppColors.muted)),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => Navigator.pushNamed(context, row.$3)),
              ])));
}

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _form = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  bool _enabled = true;
  bool _busy = false;
  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final data = context.read<LocalDataService>();
      final uid = context.read<AuthProvider>().profile!.uid;
      await data.updateSecuritySettings(uid,
          biometricsEnabled: false,
          pinEnabled: _enabled,
          pin: _enabled ? _pin.text : null);
      _pin.clear();
      _confirmation.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN settings updated.')));
      }
    } catch (error) {
      if (mounted) showActionError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
          title: 'Security & PIN',
          subtitle: 'Manage your account security and payment PIN.',
          children: [
            const DesignNote(
              title: 'Your account, protected',
              body: 'Biometric unlock is not configured on this device.',
            ),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Payment PIN'),
                value: _enabled,
                onChanged:
                    _busy ? null : (value) => setState(() => _enabled = value)),
            Form(
                key: _form,
                child: Column(children: [
                  if (_enabled) ...[
                    TextFormField(
                        controller: _pin,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'New 4-digit PIN'),
                        validator: (value) =>
                            RegExp(r'^\d{4}$').hasMatch(value ?? '')
                                ? null
                                : 'Enter four digits'),
                    const SizedBox(height: 18),
                    TextFormField(
                        controller: _confirmation,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Confirm PIN'),
                        validator: (value) =>
                            value == _pin.text ? null : 'PINs must match'),
                  ]
                ])),
            const SizedBox(height: 24),
            PrimaryButton(
                label: 'Update PIN', loading: _busy, onPressed: _save),
          ]);
}

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen(
      {super.key,
      required this.title,
      required this.group,
      required this.toggles,
      this.choices = const {},
      this.work = false});
  final String title;
  final String group;
  final bool work;
  final Map<String, String> toggles;
  final Map<String, List<String>> choices;
  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  final _values = <String, dynamic>{};
  bool _busy = false;
  Object? _error;
  late Future<void> _load;
  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<void> _fetch() async {
    try {
      final result = await FeatureGateway(context.read<LocalDataService>())
          .request(
              widget.title,
              'GET',
              widget.group == 'notifications'
                  ? '/users/me/notification-preferences'
                  : '/users/me/preferences');
      final saved =
          widget.group == 'notifications' ? result : result[widget.group];
      if (saved is Map<String, dynamic>) _values.addAll(saved);
      if (mounted && widget.group == 'display_preferences') {
        final uid = context.read<AuthProvider>().profile?.uid;
        if (uid != null) {
          context.read<DisplayPreferences>().applyServer(uid, result);
        }
      }
    } catch (error) {
      _error = error;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await FeatureGateway(context.read<LocalDataService>()).request(
          widget.title,
          'PATCH',
          widget.group == 'notifications'
              ? '/users/me/notification-preferences'
              : '/users/me/preferences',
          body: widget.group == 'notifications'
              ? _values
              : {widget.group: _values});
      if (mounted) {
        if (widget.group == 'display_preferences') {
          final uid = context.read<AuthProvider>().profile?.uid;
          if (uid != null) {
            context
                .read<DisplayPreferences>()
                .applyServer(uid, {widget.group: _values});
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preferences updated.')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
          title: widget.title,
          subtitle: widget.work
              ? 'Set your transport, delivery area and work notifications.'
              : switch (widget.group) {
                  'delivery_preferences' =>
                    'Choose your starting preferences for new deliveries.',
                  'display_preferences' =>
                    'Adjust motion and text for comfortable reading.',
                  'privacy_preferences' =>
                    'Manage your location-sharing and communication preferences.',
                  'notifications' =>
                    'Choose which delivery, payment and account updates you want to receive.',
                  _ => null,
                },
          children: [
            if (widget.work)
              const DesignNote(
                  title: 'Set up how and where you want to deliver',
                  body:
                      'Save your preferences to update your delivery workspace.'),
            FutureBuilder<void>(
                future: _load,
                builder: (context, snapshot) => DesignCard(
                        child: Column(children: [
                      for (final entry in widget.choices.entries)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue:
                                    entry.value.contains(_values[entry.key])
                                        ? _values[entry.key] as String
                                        : null,
                                decoration: InputDecoration(
                                    labelText: switch (entry.key) {
                                  'preferred_service' => 'Default service',
                                  'preferred_contact' =>
                                    'Preferred contact method',
                                  _ => entry.key.replaceAll('_', ' ')
                                }),
                                items: entry.value
                                    .map((item) => DropdownMenuItem(
                                        value: item, child: Text(item)))
                                    .toList(),
                                onChanged: (value) => setState(
                                    () => _values[entry.key] = value))),
                      if (widget.work &&
                          snapshot.connectionState == ConnectionState.done)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: TextFormField(
                                initialValue:
                                    _values['delivery_area']?.toString() ?? '',
                                decoration: const InputDecoration(
                                    labelText: 'Delivery area'),
                                onChanged: (value) =>
                                    _values['delivery_area'] = value.trim())),
                      for (final entry in widget.toggles.entries)
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(entry.value,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: switch (entry.key) {
                              'new_job_alerts' => const Text(
                                  'Notify me about delivery requests',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                              'pickup_reminders' => const Text(
                                  'Remind me about upcoming pickups',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                              'reduce_motion' => const Text(
                                  'Reduce sliding and delivery animations',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                              'larger_text' => const Text(
                                  'Increase text size in forms and detail cards',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                              'scheduled_reminders' => const Text(
                                  'Remind me before a scheduled pickup',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                              'push_enabled' => const Text(
                                  'Updates while you are on the move',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                              'email_enabled' => const Text(
                                  'Payments and delivery summaries',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                              'share_active_delivery_location' => const Text(
                                  'Your preference for active delivery tracking',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                              'marketing_consent' => const Text(
                                  'Occasional offers and product updates',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                              _ => null,
                            },
                            value: _values[entry.key] == true,
                            onChanged: (value) =>
                                setState(() => _values[entry.key] = value)),
                    ]))),
            const SizedBox(height: 18),
            if (widget.group == 'privacy_preferences')
              const DesignNote(
                  title: 'You control your location',
                  body:
                      'Device location and address lookups use connected services. Live delivery sharing requires your consent for an active delivery.'),
            if (_error != null) LoadError(error: _error!),
            PrimaryButton(
                label: 'Save preferences', loading: _busy, onPressed: _save),
            if (widget.work) ...[
              const SizedBox(height: 12),
              SecondaryButton(
                  label: 'Go offline',
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    final ok = await auth.setDelivererOnline(false);
                    if (context.mounted && !ok) {
                      showActionError(context,
                          auth.errorMessage ?? 'Unable to go offline.');
                    }
                  }),
            ],
          ]);
}

class AccountControlsScreen extends StatelessWidget {
  const AccountControlsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Account controls', children: [
        const DesignNote(
            title: 'Your account data',
            body:
                'Orders, saved addresses and account preferences belong to your account. Signing out does not delete them.'),
        const RouteTile(
            title: 'Devices & sessions',
            icon: Icons.devices_outlined,
            route: '/sessions'),
        const RouteTile(
            title: 'Delete account',
            icon: Icons.delete_outline,
            route: '/delete-account'),
        const SizedBox(height: 20),
        SecondaryButton(
            label: 'Sign out',
            onPressed: () async {
              if (!await confirmAction(context, 'Sign out?',
                      'You can sign in again to access your deliveries.') ||
                  !context.mounted) {
                return;
              }
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/onboarding', (_) => false);
              }
            }),
      ]);
}

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  Object? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Delete account', children: [
        const DesignCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Delete your account?',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger)),
          SizedBox(height: 16),
          Text(
              'Deletion is permanent. Records required for payments, disputes and legal retention may be anonymized and retained.',
              style:
                  TextStyle(fontSize: 13, height: 1.7, color: AppColors.muted)),
        ])),
        const SizedBox(height: 20),
        TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            decoration:
                const InputDecoration(labelText: 'Type DELETE to confirm')),
        const SizedBox(height: 24),
        if (_error != null) LoadError(error: _error!),
        PrimaryButton(
            label: 'Delete account',
            background: AppColors.danger,
            loading: _busy,
            onPressed: _controller.text != 'DELETE'
                ? null
                : () async {
                    if (!await confirmAction(
                            context,
                            'Permanently delete account?',
                            'This cannot be undone.') ||
                        !context.mounted) {
                      return;
                    }
                    setState(() => _busy = true);
                    try {
                      await FeatureGateway(context.read<LocalDataService>())
                          .request('Account deletion', 'DELETE', '/users/me');
                      if (!context.mounted) return;
                      await context.read<AuthProvider>().signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/onboarding', (_) => false);
                      }
                    } catch (error) {
                      if (mounted) setState(() => _error = error);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  }),
        const SizedBox(height: 12),
        SecondaryButton(
            label: 'Keep my account',
            onPressed: () => Navigator.maybePop(context)),
      ]);
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AppPage(title: 'About MoveTraq', children: [
        Center(child: MoveTraqMark(size: 42)),
        SizedBox(height: 24),
        DesignCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MoveTraq',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          SizedBox(height: 18),
          Text('Delivery, simplified.',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
          SizedBox(height: 14),
          Text('Version 1.0.0',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
          SizedBox(height: 14),
          Text('Currency: Nigerian naira (NGN)',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
        ])),
        SizedBox(height: 18),
        Text(
            'Your deliveries, account changes and payments use connected services. Payment completion requires server verification.',
            style:
                TextStyle(fontSize: 13, height: 1.7, color: AppColors.muted)),
        RouteTile(
            title: 'Help & support',
            icon: Icons.support_agent,
            route: '/support'),
        RouteTile(
            title: 'Privacy preferences',
            icon: Icons.lock_outline,
            route: '/privacy'),
      ]);
}
