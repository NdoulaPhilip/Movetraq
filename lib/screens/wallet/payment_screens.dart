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

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _query = '';
  String _movement = 'All';
  String? _type;
  bool _newest = true;
  late Stream<List<WalletTransaction>> _stream;
  @override
  void initState() {
    super.initState();
    _stream = context.read<LocalDataService>().watchWalletTransactions(
        context.read<AuthProvider>().profile?.uid ?? '');
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Payments and transactions', children: [
        TextField(
            decoration: const InputDecoration(
                hintText: 'Search transactions',
                prefixIcon: Icon(Icons.search)),
            onChanged: (value) => setState(() => _query = value.toLowerCase())),
        const SizedBox(height: 18),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'Money in', 'Money out']
                .map((value) => ChoiceChip(
                    label: Text(value),
                    selected: _movement == value,
                    onSelected: (_) => setState(() => _movement = value)))
                .toList()),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Transaction type'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All types')),
              ...WalletTxType.values.map((type) =>
                  DropdownMenuItem(value: type.name, child: Text(type.name)))
            ],
            onChanged: (value) =>
                setState(() => _type = value == '' ? null : value)),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Newest first', style: TextStyle(fontSize: 13)),
            value: _newest,
            onChanged: (value) => setState(() => _newest = value)),
        StreamBuilder<List<WalletTransaction>>(
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
                          .contains(_query) &&
                      (_type == null || record.type.name == _type) &&
                      (_movement == 'All' ||
                          (_movement == 'Money in'
                              ? record.amount > 0
                              : record.amount < 0)))
                  .toList()
                ..sort((a, b) => _newest
                    ? b.createdAt.compareTo(a.createdAt)
                    : a.createdAt.compareTo(b.createdAt));
              if (records.isEmpty) {
                return const InfoBand(
                    title: 'No transactions found',
                    icon: Icons.receipt_long_outlined);
              }
              return Column(
                  children: records
                      .map((record) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                                record.amount > 0
                                    ? Icons.south_west
                                    : Icons.north_east,
                                color: record.amount > 0
                                    ? AppColors.successDeep
                                    : AppColors.ink),
                            title: Text(record.title,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${record.sub}\n${record.createdAt.toLocal()}',
                                style: const TextStyle(fontSize: 11)),
                            trailing: Text(
                                '${record.amount >= 0 ? '+' : '-'}NGN ${record.amount.abs().toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11)),
                            onTap: () => Navigator.pushNamed(
                                context, '/transaction-detail',
                                arguments: record),
                          ))
                      .toList());
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
      InfoBand(
          title: widget.quote == null
              ? 'NGN ${flow.totalPrice.toStringAsFixed(2)}'
              : 'Review your delivery quote',
          body: flow.title.isEmpty ? null : flow.title,
          dark: true,
          icon: Icons.shield_outlined),
      const SectionTitle('Payment method'),
      RadioGroup<String>(
          groupValue: _method,
          onChanged: (value) => setState(() => _method = value!),
          child: Column(children: [
            RadioListTile(
                value: 'wallet',
                title: const Text('MoveTraq Wallet'),
                subtitle: Text('Available NGN ${wallet.toStringAsFixed(2)}'),
                contentPadding: EdgeInsets.zero),
            const RadioListTile(
                value: 'card',
                title: Text('Pay by card'),
                contentPadding: EdgeInsets.zero),
            const RadioListTile(
                value: 'bank',
                title: Text('Bank transfer'),
                contentPadding: EdgeInsets.zero),
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
