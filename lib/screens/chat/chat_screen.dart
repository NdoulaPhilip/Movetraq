import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/misc_models.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  const ChatScreen({super.key, required this.orderId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String orderId, String uid) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in before sending messages.')),
      );
      return;
    }

    _controller.clear();
    try {
      await context.read<LocalDataService>().sendMessage(orderId, uid, text);
    } catch (error) {
      if (!mounted) return;
      _controller.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.read<LocalDataService>();
    final uid = context.watch<AuthProvider>().profile?.uid ?? '';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StreamBuilder<ParcelOrder?>(
              stream: data.watchOrder(widget.orderId),
              builder: (context, snap) {
                final order = snap.data;
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderSoft))),
                  child: Row(
                    children: [
                      CircleIconButton(icon: Icons.arrow_back, background: const Color(0xFFF3F2EC), onTap: () => Navigator.maybePop(context)),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: const Color(0xFF3A4250),
                        child: Text(
                          _initials(order?.delivererName ?? 'Courier'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order?.delivererName ?? 'Courier', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const Row(children: [
                              Icon(Icons.circle, size: 6, color: AppColors.success),
                              SizedBox(width: 5),
                              Text('Online · your courier', style: TextStyle(fontSize: 12, color: AppColors.success)),
                            ]),
                          ],
                        ),
                      ),
                      CircleIconButton(
                        icon: Icons.call_outlined,
                        background: AppColors.ink,
                        iconColor: Colors.white,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Calling ${order?.delivererName ?? "your courier"} is not available in this prototype.'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: data.watchMessages(widget.orderId),
                builder: (context, snap) {
                  final messages = snap.data ?? [];
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });
                  if (messages.isEmpty) {
                    return const Center(child: Text('Say hello 👋', style: TextStyle(color: AppColors.muted)));
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: Center(
                            child: Text('Today', style: TextStyle(fontSize: 12, color: AppColors.faint, fontWeight: FontWeight.w600)),
                          ),
                        );
                      }
                      final m = messages[i - 1];
                      final mine = m.senderId == uid;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: mine ? AppColors.ink : const Color(0xFFF3F2EC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(m.text, style: TextStyle(color: mine ? Colors.white : AppColors.ink, fontSize: 14, height: 1.4)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            StreamBuilder<ParcelOrder?>(
              stream: data.watchOrder(widget.orderId),
              builder: (context, orderSnap) {
                final name = orderSnap.data?.delivererName ?? 'Courier';
                final firstName = name.split(' ').first;
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderSoft))),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onSubmitted: (_) {
                            _send(widget.orderId, uid);
                          },
                          decoration: InputDecoration(
                            hintText: 'Message $firstName...',
                            filled: true,
                            fillColor: const Color(0xFFF3F2EC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: AppColors.accent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            _send(widget.orderId, uid);
                          },
                          child: const SizedBox(width: 46, height: 46, child: Icon(Icons.send, color: AppColors.ink, size: 19)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
