import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/send_flow_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  final _categories = const [
    ('parcel', 'Parcel', Icons.inventory_2_outlined),
    ('document', 'Document', Icons.description_outlined),
    ('food', 'Food', Icons.shopping_bag_outlined),
    ('fragile', 'Fragile', Icons.card_giftcard_outlined),
    ('electronics', 'Electronics', Icons.devices_other_outlined),
    ('clothing', 'Clothing', Icons.checkroom_outlined),
  ];

  static final Uint8List _samplePng = Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
    0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
    0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 248, 207, 240, 31,
    0, 5, 0, 1, 255, 137, 153, 61, 29, 0, 0, 0, 0, 73, 69, 78,
    68, 174, 66, 96, 130,
  ]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SendFlowProvider>().reset();
      _recoverLostPicture();
    });
  }

  Future<void> _chooseParcelPicture(SendFlowProvider flow) async {
    final source = await showModalBottomSheet<_PictureSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add picture',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _PictureSourceTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from gallery',
                  onTap: () => Navigator.pop(context, _PictureSource.gallery),
                ),
                _PictureSourceTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take a photo',
                  onTap: () => Navigator.pop(context, _PictureSource.camera),
                ),
                _PictureSourceTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Use sample picture',
                  onTap: () => Navigator.pop(context, _PictureSource.sample),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;
    if (source == _PictureSource.sample) {
      flow.addParcelPhoto(_sampleParcelImage());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample picture added.')),
      );
      return;
    }

    await _addParcelPicture(
      flow,
      source == _PictureSource.camera ? ImageSource.camera : ImageSource.gallery,
    );
  }

  Future<void> _addParcelPicture(
    SendFlowProvider flow,
    ImageSource source,
  ) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (image == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No picture selected.')),
        );
        return;
      }
      flow.addParcelPhoto(await image.readAsBytes());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Picture added.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add picture: $error')),
      );
    }
  }

  Future<void> _recoverLostPicture() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      if (response.isEmpty || !mounted) return;
      final files = response.files;
      if (files == null || files.isEmpty) return;
      final flow = context.read<SendFlowProvider>();
      for (final file in files.take(4 - flow.parcelPhotos.length)) {
        flow.addParcelPhoto(await file.readAsBytes());
      }
    } catch (_) {
      // Lost-data recovery is best effort.
    }
  }

  Uint8List _sampleParcelImage() => _samplePng;

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 116),
              children: [
                const ScreenHeader(title: 'Send'),
                const Text('New order',
                    style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 24, letterSpacing: -0.3, color: AppColors.ink)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: const Color(0xFFF3F2EC), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ModeTab(
                          label: 'Peer-to-peer',
                          sub: 'Pick a deliverer & negotiate',
                          selected: flow.isP2P,
                          onTap: () => flow.setMode(p2p: true),
                        ),
                      ),
                      Expanded(
                        child: _ModeTab(
                          label: 'Express',
                          sub: 'Fixed price, fastest pickup',
                          selected: !flow.isP2P,
                          onTap: () => flow.setMode(p2p: false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink, width: 3)),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: _AddressField(
                              label: 'PICKUP',
                              value: flow.pickupAddress,
                              hint: 'Enter pickup address',
                              onChanged: (value) => flow.setDetails(
                                pickupAddress: value,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 23),
                        child: Divider(height: 20, color: AppColors.borderSoft),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.symmetric(vertical: 14),
                            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: _AddressField(
                              label: 'DROP-OFF',
                              value: flow.dropoffAddress,
                              hint: 'Enter drop-off address',
                              onChanged: (value) => flow.setDetails(
                                dropoffAddress: value,
                              ),
                            ),
                          ),
                          const Icon(Icons.edit_location_alt_outlined, color: AppColors.faint),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text('What are you sending?', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.15,
                  children: _categories.map((c) {
                    final selected = flow.category == c.$1;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => flow.setDetails(category: c.$1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected ? AppColors.ink : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selected ? AppColors.ink : AppColors.border, width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(c.$3, color: selected ? AppColors.accent : AppColors.ink, size: 24),
                            const SizedBox(height: 8),
                            Text(c.$2, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.ink)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Add a product description & photos so deliverers know what they're carrying.",
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ...List.generate(
                      flow.parcelPhotos.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _PhotoThumb(
                          bytes: flow.parcelPhotos[index],
                          onRemove: () => flow.removeParcelPhotoAt(index),
                        ),
                      ),
                    ),
                    if (flow.parcelPhotos.length < 4)
                      _AddPhotoButton(
                        onTap: () => _chooseParcelPicture(flow),
                      ),
                  ],
                ),
                if (flow.isP2P) ...[
                  const SizedBox(height: 24),
                  const Text('Set your offer', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  const Text(
                    "Name what you'll pay a deliverer. It's held in escrow the moment a peer accepts.",
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(22)),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          right: -30,
                          top: -30,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("YOU'RE OFFERING", style: TextStyle(fontSize: 12, color: Color(0xFF8A93A2), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: '₦', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 34, color: Colors.white)),
                                  TextSpan(text: flow.offer.toStringAsFixed(0), style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 40, color: Colors.white, letterSpacing: -0.4)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [500.0, 1000.0, 2000.0].map((delta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: OutlinedButton(
                                    onPressed: () => flow.adjustOffer(delta),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: Text('+₦${delta.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Choose your deliverer', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  const Text(
                    'Pick a specific peer, or leave it open for any nearby deliverer to accept.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.pushNamed(context, '/pick-deliverer'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: AppColors.tint['lime'], borderRadius: BorderRadius.circular(13)),
                            child: const Icon(Icons.person_outline, color: AppColors.ink, size: 21),
                          ),
                          const SizedBox(width: 13),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Browse deliverers', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                SizedBox(height: 2),
                                Text('Search & filter available peers', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.ink),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  const Text('Delivery speed', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink)),
                  const SizedBox(height: 12),
                  ...List.generate(2, (i) {
                    final selected = flow.speedIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => flow.setSpeedIndex(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.tint['lime'] : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: selected ? AppColors.ink : AppColors.border, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                                child: Icon(i == 0 ? Icons.schedule_outlined : Icons.bolt_outlined, color: AppColors.ink, size: 22),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(SendFlowProvider.expressSpeedLabels[i], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(i == 0 ? 'Arrives within 60–90 min' : 'Priority pickup · under 30 min',
                                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₦${SendFlowProvider.expressSpeedPrices[i].toStringAsFixed(0)}',
                                      style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 5),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: selected ? AppColors.ink : AppColors.faint, width: 2),
                                      color: selected ? AppColors.ink : Colors.transparent,
                                    ),
                                    child: selected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 24),
                const Text('Delivery terms', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Column(
                    children: [
                      const _TermRow(n: '1', title: 'Escrow protection', body: 'Your payment is held safely until you confirm delivery.'),
                      const _TermRow(n: '2', title: 'Verified deliverers', body: 'Every peer is ID-checked before they can accept jobs.'),
                      const _TermRow(n: '3', title: 'Live tracking', body: "Follow your parcel's journey from pickup to your door."),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => flow.toggleTermsAgreed(),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: flow.termsAgreed ? AppColors.accent : Colors.white,
                                borderRadius: BorderRadius.circular(7),
                                border: flow.termsAgreed ? null : Border.all(color: AppColors.border, width: 1.5),
                              ),
                              child: flow.termsAgreed ? const Icon(Icons.check, size: 14, color: AppColors.ink) : null,
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Text("I've verified the item, address & recipient contact.",
                                style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.white.withValues(alpha: 0.98), Colors.white.withValues(alpha: 0.98), Colors.white.withValues(alpha: 0)],
                  stops: const [0, 0.68, 1],
                ),
              ),
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: !flow.termsAgreed
                      ? null
                      : () async {
                          if (flow.isP2P) {
                            Navigator.pushNamed(context, '/pick-deliverer');
                          } else {
                            final auth = context.read<AuthProvider>();
                            if (auth.profile == null) return;
                            try {
                              await flow.submitOrder(auth.profile!);
                              if (context.mounted) Navigator.pushNamed(context, '/send-done');
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.35),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(flow.isP2P ? 'Choose a deliverer' : 'Continue', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Row(
                        children: [
                          Text(
                            flow.isP2P
                                ? '₦${flow.offer.toStringAsFixed(0)}'
                                : '₦${SendFlowProvider.expressSpeedPrices[flow.speedIndex].toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          const SizedBox(width: 7),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: selected ? AppColors.ink : AppColors.inkSoft)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 10.5, color: selected ? AppColors.muted : AppColors.faint), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AddressField extends StatefulWidget {
  final String label;
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  const _AddressField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<_AddressField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _AddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        TextField(
          controller: _controller,
          minLines: 1,
          maxLines: 2,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              color: AppColors.faint,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
            isDense: true,
            filled: false,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

enum _PictureSource { gallery, camera, sample }

class _PictureSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _PictureSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F2EC),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: AppColors.ink, size: 21),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.faint),
      onTap: onTap,
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback onRemove;

  const _PhotoThumb({
    required this.bytes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            bytes,
            width: 66,
            height: 66,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F2EC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.muted,
                  size: 24,
                ),
              );
            },
          ),
        ),
        Positioned(
          right: -7,
          top: -7,
          child: Material(
            color: AppColors.ink,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: const Icon(
          Icons.add_a_photo_outlined,
          color: AppColors.muted,
          size: 24,
        ),
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  final String n;
  final String title;
  final String body;
  const _TermRow({required this.n, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.tint['lime'], borderRadius: BorderRadius.circular(8)),
            child: Text(n, style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
