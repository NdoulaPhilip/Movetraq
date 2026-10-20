import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../models/misc_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/design_ui.dart';
import '../../models/parcel_order.dart';
import '../../screens/orders/order_tools.dart' show orderStatusLabel;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  late Future<AppUser> _contact;
  late Stream<List<ChatMessage>> _messages;
  late Stream<ParcelOrder?> _order;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final data = context.read<LocalDataService>();
    _contact = data.orderContact(widget.orderId);
    _messages = data.watchMessages(widget.orderId);
    _order = data.watchOrder(widget.orderId);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _text.text.trim().isEmpty) return;
    final uid = context.read<AuthProvider>().profile?.uid;
    if (uid == null || widget.orderId.isEmpty) {
      showActionError(context, 'Sign in and open a delivery to chat.');
      return;
    }
    final body = _text.text.trim();
    setState(() => _busy = true);
    try {
      await context
          .read<LocalDataService>()
          .sendMessage(widget.orderId, uid, body);
      if (mounted && _text.text.trim() == body) _text.clear();
    } catch (error) {
      if (mounted) showActionError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().profile?.uid;
    return Scaffold(
        body: SafeArea(
            child: Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
          child: Row(children: [
            CircleIconButton(
                icon: Icons.chevron_left,
                onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Delivery chat',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
            IconButton(
                tooltip: 'Call contact',
                icon: const Icon(Icons.call_outlined),
                onPressed: () => Navigator.pushNamed(context, '/call',
                    arguments: widget.orderId)),
            PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                tooltip: 'Conversation actions',
                onSelected: (value) => Navigator.pushNamed(context, value,
                    arguments: widget.orderId),
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: '/delivery-summary',
                          child: Text('Manage order')),
                      PopupMenuItem(
                          value: '/safety-reporting',
                          child: Text('Block or report'))
                    ]),
          ])),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DesignCard(
              child: FutureBuilder<AppUser>(
                  future: _contact,
                  builder: (context, snapshot) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                                spacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                      snapshot.data?.name ??
                                          'Delivery conversation',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                  TextButton(
                                      onPressed: () => Navigator.pushNamed(
                                          context, '/delivery-summary',
                                          arguments: widget.orderId),
                                      child: const Text('Manage order')),
                                ]),
                            const SizedBox(height: 4),
                            Text(
                                snapshot.hasError
                                    ? 'Contact unavailable'
                                    : 'Delivery conversation',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.muted)),
                            StreamBuilder<ParcelOrder?>(
                                stream: _order,
                                builder: (context, order) => order.data == null
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                            '${order.data!.title} / ${orderStatusLabel(order.data!.status)}',
                                            style: const TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 12)),
                                      )),
                          ])))),
      const SizedBox(height: 8),
      Expanded(
          child: StreamBuilder<List<ChatMessage>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                      padding: const EdgeInsets.all(20),
                      child: LoadError(error: snapshot.error!));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.toList()
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                if (messages.isEmpty) {
                  return const Center(
                      child: Text('No messages yet',
                          style: TextStyle(color: AppColors.muted)));
                }
                return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(18),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - index - 1];
                      final mine = message.senderId == uid;
                      return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * .8),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: mine
                                      ? const Color(0xFFEAF3CA)
                                      : const Color(0xFFF1F3EB),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(message.text,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.ink,
                                            height: 1.4)),
                                    const SizedBox(height: 5),
                                    Text(
                                        TimeOfDay.fromDateTime(
                                                message.createdAt.toLocal())
                                            .format(context),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.muted)),
                                  ])));
                    });
              })),
      const Divider(height: 1, color: AppColors.borderSoft),
      Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
                child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                        hintText: 'Message...', filled: false))),
            const SizedBox(width: 8),
            IconButton.filled(
                tooltip: 'Send message',
                onPressed: _busy ? null : _send,
                style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: const Color(0xFFEAF9B2),
                    foregroundColor: AppColors.ink),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_outlined)),
          ])),
    ])));
  }
}
