import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';

class ReleaseOtpScreen extends StatefulWidget {
  final String orderId;
  const ReleaseOtpScreen({super.key, required this.orderId});

  @override
  State<ReleaseOtpScreen> createState() => _ReleaseOtpScreenState();
}

class _ReleaseOtpScreenState extends State<ReleaseOtpScreen> {
  String _code = '';
  bool _submitting = false;

  void _tapDigit(String d) {
    if (_code.length >= 6 || _submitting) return;
    setState(() => _code += d);
    if (_code.length == 6) _submit();
  }

  void _backspace() {
    if (_code.isEmpty || _submitting) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await context.read<LocalDataService>().releaseEscrow(widget.orderId);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/release-done', arguments: widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.read<LocalDataService>();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<ParcelOrder?>(
          stream: data.watchOrder(widget.orderId),
          builder: (context, snap) {
            final order = snap.data;
            if (order == null) return const Center(child: CircularProgressIndicator());

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.maybePop(context)),
                  const SizedBox(height: 18),
                  const Text('Authorize release', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 22)),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.5),
                      children: [
                        const TextSpan(text: 'Enter the 6-digit code we sent to '),
                        const TextSpan(text: '+234 803 •••• 4821', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                        TextSpan(text: ' to release ₦${order.price.toStringAsFixed(0)} from escrow.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) {
                      final filled = i < _code.length;
                      final isCursor = i == _code.length;
                      return Container(
                        width: 44,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isCursor ? AppColors.accent : AppColors.border, width: isCursor ? 2 : 1.5),
                        ),
                        child: Text(
                          filled ? '•' : '',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_outlined, size: 15, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Text(_submitting ? 'Releasing…' : 'Protected by MoveTraq escrow',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    ],
                  ),
                  const Spacer(),
                  _Numpad(onDigit: _tapDigit, onBackspace: _backspace),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  const _Numpad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {IconData? icon, VoidCallback? onTap}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: const Color(0xFFF3F2EC),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: SizedBox(
                height: 58,
                child: Center(
                  child: icon != null
                      ? Icon(icon, size: 20, color: AppColors.ink)
                      : Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [key('1', onTap: () => onDigit('1')), key('2', onTap: () => onDigit('2')), key('3', onTap: () => onDigit('3'))]),
        Row(children: [key('4', onTap: () => onDigit('4')), key('5', onTap: () => onDigit('5')), key('6', onTap: () => onDigit('6'))]),
        Row(children: [key('7', onTap: () => onDigit('7')), key('8', onTap: () => onDigit('8')), key('9', onTap: () => onDigit('9'))]),
        Row(children: [
          const Expanded(child: SizedBox()),
          key('0', onTap: () => onDigit('0')),
          key('', icon: Icons.backspace_outlined, onTap: onBackspace),
        ]),
      ],
    );
  }
}
