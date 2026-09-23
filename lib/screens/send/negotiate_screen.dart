import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/send_flow_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class NegotiateScreen extends StatelessWidget {
  const NegotiateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();
    final proposal = flow.proposal ?? flow.basePrice;

    Widget statusCard;
    if (flow.negoStatus == 'agreed') {
      statusCard = _StatusBanner(
        color: AppColors.success,
        text: 'Price agreed at ₦${(flow.sentAmount ?? proposal).toStringAsFixed(0)}',
      );
    } else if (flow.negoStatus == 'countered') {
      statusCard = _StatusBanner(
        color: AppColors.warning,
        text: '${flow.selectedDelivererName ?? "Deliverer"} countered with ₦${flow.counterAmount!.toStringAsFixed(0)}',
      );
    } else {
      statusCard = const SizedBox.shrink();
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(title: 'Negotiate'),
              const SizedBox(height: 20),
              Text('Offer your price', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
              const SizedBox(height: 6),
              Text('Base rate is ₦${flow.basePrice.toStringAsFixed(0)} for this delivery.',
                  style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundIconButton(icon: Icons.remove, onTap: () => flow.adjustProposal(-100)),
                    Column(
                      children: [
                        const Text('YOUR OFFER', style: TextStyle(color: Color(0xFF8A93A2), fontSize: 11.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('₦${proposal.toStringAsFixed(0)}',
                            style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 34, color: Colors.white)),
                      ],
                    ),
                    _RoundIconButton(icon: Icons.add, onTap: () => flow.adjustProposal(100)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              statusCard,
              const Spacer(),
              if (flow.negoStatus == 'agreed')
                PrimaryButton(
                  label: 'Accept ₦${(flow.sentAmount ?? proposal).toStringAsFixed(0)}',
                  background: AppColors.accent,
                  foreground: AppColors.ink,
                  onPressed: () {
                    flow.acceptNegotiated(flow.sentAmount ?? proposal);
                    Navigator.pushNamed(context, '/confirm-order');
                  },
                )
              else if (flow.negoStatus == 'countered') ...[
                PrimaryButton(
                  label: 'Accept ₦${flow.counterAmount!.toStringAsFixed(0)}',
                  background: AppColors.accent,
                  foreground: AppColors.ink,
                  onPressed: () {
                    flow.acceptNegotiated(flow.counterAmount!);
                    Navigator.pushNamed(context, '/confirm-order');
                  },
                ),
                const SizedBox(height: 10),
                SecondaryButton(label: 'Keep negotiating', onPressed: () => flow.keepNegotiating()),
              ] else
                PrimaryButton(
                  label: 'Send offer · ₦${proposal.toStringAsFixed(0)}',
                  onPressed: () => flow.sendProposal(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final Color color;
  final String text;
  const _StatusBanner({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: color))),
      ]),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white)),
      ),
    );
  }
}
