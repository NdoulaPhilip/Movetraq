import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/misc_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/send_flow_provider.dart';
import '../../services/local_data_service.dart';
import '../../services/feature_gateway.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/movetraq_brand.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/primary_button.dart';
import '../shared/feature_screen.dart';
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
              const SectionTitle('Contact information'),
              TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter your name'
                      : null),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    return phone.isNotEmpty &&
                            !RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone)
                        ? 'Enter a valid phone number'
                        : null;
                  }),
              const SizedBox(height: 16),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Email'),
                  subtitle: Text(profile.email)),
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
        subtitle: 'Your pickup and delivery locations.',
        actions: [
          IconButton(
              tooltip: 'Add address',
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.pushNamed(context, '/address-edit'))
        ],
        children: [
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
                        child: PremiumSurface(
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
                                PopupMenuButton<String>(
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
                                              child: Text('Delete'))
                                        ]),
                              ]),
                              Text(address.address,
                                  style: const TextStyle(
                                      fontSize: 12,
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
                                              pickupAddress: address.address);
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

class AddressEditScreen extends StatelessWidget {
  const AddressEditScreen({super.key, this.address});
  final SavedAddress? address;
  @override
  Widget build(BuildContext context) => FeatureFormScreen(
        title: address == null ? 'Add an address' : 'Edit address',
        action: 'Save address',
        fields: const [
          FormFieldSpec('label', 'Label', hint: 'Home, Work...'),
          FormFieldSpec('address', 'Street address', kind: FieldKind.multiline)
        ],
        initialValues: {'label': address?.label, 'address': address?.address},
        onSubmit: (context, values) async {
          final uid = context.read<AuthProvider>().profile?.uid;
          if (uid == null) throw StateError('Sign in to save an address.');
          await context.read<LocalDataService>().saveAddress(uid,
              id: address?.id,
              label: values['label'] as String,
              address: values['address'] as String);
        },
      );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AppPage(title: 'Settings', children: [
        SectionTitle('Security'),
        RouteTile(
            title: 'Security & PIN',
            icon: Icons.shield_outlined,
            route: '/security'),
        RouteTile(
            title: 'Devices & sessions',
            icon: Icons.devices_outlined,
            route: '/sessions'),
        RouteTile(
            title: 'Blocked people',
            icon: Icons.block_outlined,
            route: '/blocked-users'),
        Divider(color: AppColors.borderSoft),
        SectionTitle('Preferences'),
        RouteTile(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            route: '/notification-preferences'),
        RouteTile(
            title: 'Delivery preferences',
            icon: Icons.local_shipping_outlined,
            route: '/delivery-preferences'),
        RouteTile(
            title: 'Display & accessibility',
            icon: Icons.accessibility_new_outlined,
            route: '/display-preferences'),
        RouteTile(
            title: 'Privacy', icon: Icons.lock_outline, route: '/privacy'),
        Divider(color: AppColors.borderSoft),
        SectionTitle('Account'),
        RouteTile(
            title: 'Account controls',
            icon: Icons.manage_accounts_outlined,
            route: '/account-controls'),
        RouteTile(
            title: 'About MoveTraq', icon: Icons.info_outline, route: '/about'),
      ]);
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
  Widget build(BuildContext context) =>
      AppPage(title: 'Security & PIN', children: [
        const InfoBand(
            title: 'Your account, protected',
            body: 'Biometric unlock is not configured on this device.',
            icon: Icons.fingerprint),
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
                    decoration: const InputDecoration(labelText: 'Confirm PIN'),
                    validator: (value) =>
                        value == _pin.text ? null : 'PINs must match'),
              ]
            ])),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Update PIN', loading: _busy, onPressed: _save),
      ]);
}

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen(
      {super.key,
      required this.title,
      required this.group,
      required this.toggles,
      this.choices = const {}});
  final String title;
  final String group;
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
  Widget build(BuildContext context) => AppPage(title: widget.title, children: [
        FutureBuilder<void>(
            future: _load,
            builder: (context, snapshot) => Column(children: [
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
                                labelText: entry.key.replaceAll('_', ' ')),
                            items: entry.value
                                .map((item) => DropdownMenuItem(
                                    value: item, child: Text(item)))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _values[entry.key] = value))),
                  for (final entry in widget.toggles.entries)
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value,
                            style: const TextStyle(fontSize: 13)),
                        value: _values[entry.key] == true,
                        onChanged: (value) =>
                            setState(() => _values[entry.key] = value)),
                ])),
        const SizedBox(height: 18),
        if (_error != null) LoadError(error: _error!),
        PrimaryButton(
            label: 'Save preferences', loading: _busy, onPressed: _save),
      ]);
}

class AccountControlsScreen extends StatelessWidget {
  const AccountControlsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Account controls', children: [
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
        const InfoBand(
            title: 'Delete your account?',
            body:
                'Deletion is permanent. Records required for payments, disputes and legal retention may be anonymized and retained.',
            icon: Icons.warning_amber_outlined),
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
        Center(child: MoveTraqMark(size: 64)),
        SizedBox(height: 28),
        InfoBand(
            title: 'MoveTraq',
            body: 'Delivery, simplified.',
            icon: Icons.inventory_2_outlined),
        DetailRow('Version', '1.0.0'),
        DetailRow('Currency', 'Nigerian naira (NGN)'),
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
