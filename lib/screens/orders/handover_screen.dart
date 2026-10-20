import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/design_ui.dart';

class HandoverScreen extends StatefulWidget {
  const HandoverScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  String? _evidence;
  bool _busy = false;
  late final Stream<ParcelOrder?> _order;
  @override
  void initState() {
    super.initState();
    _order = context.read<LocalDataService>().watchOrder(widget.orderId);
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (widget.orderId.isEmpty) {
      showActionError(context, 'Open an active delivery first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await FeatureGateway(context.read<LocalDataService>()).request(
          'Delivery handover', 'POST', '/orders/${widget.orderId}/commands',
          body: {
            'command': 'handover',
            'recipientName': _name.text.trim(),
            'code': _code.text,
            if (_evidence != null) 'evidenceUploadId': _evidence
          });
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/delivery-summary',
            arguments: widget.orderId);
      }
    } catch (error) {
      if (mounted) showActionError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: _order,
      builder: (context, snapshot) {
        final order = snapshot.data;
        final uid = context.watch<AuthProvider>().profile?.uid;
        return AppPage(
            title: 'Confirm parcel handover',
            subtitle:
                'Record who received the parcel and confirm handover using their delivery code.',
            children: [
              if (snapshot.hasError)
                LoadError(error: snapshot.error!)
              else if (order == null &&
                  snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (uid == null ||
                  order == null ||
                  order.delivererId != uid ||
                  order.status != OrderStatus.pickedUp)
                const InfoBand(
                    title: 'Handover unavailable',
                    body:
                        'Only the assigned deliverer can confirm an in-transit delivery.')
              else ...[
                DesignNote(
                    reference: order.code,
                    title: 'Record handover details',
                    body:
                        'Ask the recipient for their delivery code. You can also attach a photo with their permission. Payment remains protected until sender confirmation.'),
                Form(
                    key: _form,
                    child: Column(children: [
                      TextFormField(
                          controller: _name,
                          decoration:
                              const InputDecoration(labelText: 'Received by'),
                          validator: (value) => (value ?? '').trim().length < 2
                              ? 'Enter the recipient name'
                              : null),
                      const SizedBox(height: 18),
                      TextFormField(
                          controller: _code,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                              labelText: 'Recipient delivery code'),
                          validator: (value) =>
                              RegExp(r'^\d{6}$').hasMatch(value ?? '')
                                  ? null
                                  : 'Enter six digits')
                    ])),
                const SizedBox(height: 18),
                RouteTile(
                    title: _evidence == null
                        ? 'Add delivery photo'
                        : 'Delivery photo verified',
                    icon: _evidence == null
                        ? Icons.photo_camera_outlined
                        : Icons.check_circle_outline,
                    onTap: _busy
                        ? null
                        : () async {
                            final id = await Navigator.pushNamed(
                                context, '/evidence-upload',
                                arguments: widget.orderId);
                            if (mounted && id is String) {
                              setState(() => _evidence = id);
                            }
                          }),
                const SizedBox(height: 24),
                PrimaryButton(
                    label: 'Confirm handover and finish',
                    loading: _busy,
                    onPressed: _submit),
                RouteTile(
                    title: 'Report a problem',
                    icon: Icons.support_agent,
                    route: '/delivery-problem',
                    arguments: widget.orderId),
              ],
            ]);
      });
}
