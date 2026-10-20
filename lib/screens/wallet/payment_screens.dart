import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/misc_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/send_flow_provider.dart';
import '../../services/local_data_service.dart';
import '../../services/feature_gateway.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/design_ui.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  String _movement = 'All', _type = '';
  bool _newest = true;
  DateTime? _from, _to;
  String? _uid;
  Stream<List<WalletTransaction>>? _stream;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthProvider>().profile?.uid;
    if (_stream == null || uid != _uid) {
      _uid = uid;
      _stream = uid == null
          ? Stream.value([])
          : context.read<LocalDataService>().watchWalletTransactions(uid);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _date(bool from) async {
    final value = await showDatePicker(
        context: context,
        initialDate: (from ? _from : _to) ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now());
    if (value != null && mounted) {
      setState(() {
        if (from) {
          _from = value;
        } else {
          _to = value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Payments and transactions', children: [
        TextField(
            controller: _search,
            decoration: const InputDecoration(
                labelText: 'Search transactions',
                prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        DesignCard(
            child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Filter transactions',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                children: [
              DropdownButtonFormField<String>(
                  key: ValueKey('type-$_type'),
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All types')),
                    for (final type in WalletTxType.values)
                      DropdownMenuItem(
                          value: type.name, child: Text(type.name)),
                  ],
                  onChanged: (value) => setState(() => _type = value ?? '')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  key: ValueKey(_movement),
                  initialValue: _movement,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Money movement'),
                  items: [
                    for (final value in ['All', 'Money in', 'Money out'])
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) =>
                      setState(() => _movement = value ?? 'All')),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Newest first',
                      style: TextStyle(fontSize: 12)),
                  value: _newest,
                  onChanged: (value) => setState(() => _newest = value)),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(
                    onPressed: () => _date(true),
                    child:
                        Text(_from == null ? 'From date' : shortDate(_from!))),
                OutlinedButton(
                    onPressed: () => _date(false),
                    child: Text(_to == null ? 'To date' : shortDate(_to!))),
                TextButton(
                    onPressed: () => setState(() {
                          _search.clear();
                          _type = '';
                          _movement = 'All';
                          _from = null;
                          _to = null;
                          _newest = true;
                        }),
                    child: const Text('Reset filters')),
              ]),
            ])),
        const SizedBox(height: 16),
        StreamBuilder<List<WalletTransaction>>(
            key: ValueKey(_uid),
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final records = snapshot.data!
                  .where((record) =>
                      '${record.title} ${record.sub}'
                          .toLowerCase()
                          .contains(_search.text.toLowerCase()) &&
                      (_type.isEmpty || record.type.name == _type) &&
                      (_movement == 'All' ||
                          (_movement == 'Money in'
                              ? record.amount > 0
                              : record.amount < 0)) &&
                      (_from == null || !record.createdAt.isBefore(_from!)) &&
                      (_to == null ||
                          record.createdAt.isBefore(
                              DateTime(_to!.year, _to!.month, _to!.day + 1))))
                  .toList()
                ..sort((a, b) => _newest
                    ? b.createdAt.compareTo(a.createdAt)
                    : a.createdAt.compareTo(b.createdAt));
              final incoming = records
                  .where((record) => record.amount > 0)
                  .fold<double>(0, (sum, record) => sum + record.amount);
              final outgoing = records
                  .where((record) => record.amount < 0)
                  .fold<double>(0, (sum, record) => sum - record.amount);
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: DesignNote(
                                  title: naira(incoming), body: 'Money in')),
                          const SizedBox(width: 10),
                          Expanded(
                              child: DesignNote(
                                  title: naira(outgoing), body: 'Money out')),
                        ]),
                    Text('${records.length} transactions',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 14),
                    if (records.isEmpty)
                      const DesignNote(
                          title: 'No transactions yet',
                          body:
                              'Payments, top-ups and withdrawals will appear here.'),
                    for (final record in records)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DesignCard(
                              child: RouteTile(
                                  title: record.title,
                                  subtitle:
                                      '${record.sub}\n${shortDate(record.createdAt)} · ${record.amount < 0 ? '−' : '+'}${naira(record.amount.abs())}',
                                  icon: record.amount > 0
                                      ? Icons.south_west
                                      : Icons.north_east,
                                  route: '/transaction-detail',
                                  arguments: record))),
                  ]);
            }),
      ]);
}

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, this.transaction});
  final WalletTransaction? transaction;
  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Transaction details', children: [
        if (transaction == null)
          const InfoBand(
              title: 'Select a transaction to continue.',
              icon: Icons.receipt_long_outlined)
        else ...[
          InfoBand(
              title: transaction!.title,
              body: 'NGN ${transaction!.amount.abs().toStringAsFixed(2)}',
              dark: true,
              icon: Icons.receipt_long_outlined),
          DetailRow('Reference', transaction!.id),
          DetailRow('Type', transaction!.type.name),
          DetailRow('Description', transaction!.sub),
          DetailRow('Date', transaction!.createdAt.toLocal().toString()),
          const RouteTile(
              title: 'Report a payment issue',
              icon: Icons.support_agent,
              route: '/report-issue'),
        ],
      ]);
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, this.quote});
  final Map<String, dynamic>? quote;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'wallet';
  bool _busy = false;
  Object? _error;
  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();
    final wallet = context.watch<AuthProvider>().profile?.walletBalance ?? 0;
    return AppPage(title: 'Payment', children: [
      DesignCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TOTAL TO PAY',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 15),
        Text(
            widget.quote == null
                ? naira(flow.totalPrice)
                : 'Review your delivery quote',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(flow.isP2P ? 'P2P delivery' : 'Express delivery',
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        if (flow.title.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(flow.title,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
        if (flow.selectedDelivererName != null) ...[
          const SizedBox(height: 10),
          Text('Deliverer: ${flow.selectedDelivererName!}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ])),
      const SectionTitle('Payment method'),
      RadioGroup<String>(
          groupValue: _method,
          onChanged: (value) => setState(() => _method = value!),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DesignCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: RadioListTile(
                        value: 'wallet',
                        title: const Text('MoveTraq Wallet'),
                        subtitle:
                            Text('Available NGN ${wallet.toStringAsFixed(2)}'),
                        contentPadding: EdgeInsets.zero))),
            const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: DesignCard(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: RadioListTile(
                        value: 'card',
                        title: Text('Pay by card'),
                        contentPadding: EdgeInsets.zero))),
            const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: DesignCard(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: RadioListTile(
                        value: 'bank',
                        title: Text('Bank transfer'),
                        contentPadding: EdgeInsets.zero))),
          ])),
      if (_method != 'wallet')
        const InfoBand(
            title: 'Provider checkout unavailable',
            body:
                'Card and bank checkout are not connected to this mobile build.',
            icon: Icons.info_outline),
      if (_error != null) LoadError(error: _error!),
      const SizedBox(height: 18),
      PrimaryButton(
          label: 'Confirm payment',
          loading: _busy,
          onPressed: () async {
            if (_method != 'wallet' || widget.quote != null) {
              setState(() =>
                  _error = const FeatureUnavailable('Provider order checkout'));
              return;
            }
            final auth = context.read<AuthProvider>();
            if (auth.profile == null) {
              setState(() => _error = StateError('Sign in before paying.'));
              return;
            }
            if (wallet < flow.totalPrice) {
              await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                          title: const Text('Insufficient wallet balance'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(this.context, '/topup');
                                },
                                child: const Text('Add money'))
                          ]));
              return;
            }
            if (!await confirmAction(context, 'Confirm delivery payment?',
                    'Your server-verified wallet will fund this order.') ||
                !context.mounted) {
              return;
            }
            setState(() => _busy = true);
            try {
              await flow.submitOrder(auth.profile!);
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/send-done');
              }
            } catch (error) {
              if (mounted) setState(() => _error = error);
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          }),
      const SizedBox(height: 12),
      SecondaryButton(
          label: 'Manage payment methods',
          onPressed: () => Navigator.pushNamed(context, '/payment-methods')),
    ]);
  }
}

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final tier =
        context.watch<AuthProvider>().profile?.memberTier ?? 'Not enrolled';
    return AppPage(title: 'Membership', children: [
      InfoBand(
          title: '$tier member',
          icon: Icons.workspace_premium_outlined,
          dark: true),
      const RouteTile(
          title: 'Payment history',
          icon: Icons.receipt_long_outlined,
          route: '/transactions'),
      const RouteTile(
          title: 'Account details',
          icon: Icons.person_outline,
          route: '/personal-details'),
      const RouteTile(
          title: 'Membership support',
          icon: Icons.support_agent,
          route: '/support'),
      const SizedBox(height: 18),
      const InfoBand(
          title: 'Membership upgrades unavailable',
          body: 'Subscription billing has not been configured.',
          icon: Icons.info_outline),
    ]);
  }
}
