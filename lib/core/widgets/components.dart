import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      );
}

class AppCard extends StatelessWidget {
  final Widget child;
  const AppCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppTheme.border)),
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      );
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? retry;
  const ErrorState({super.key, required this.message, this.retry});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              semanticsLabel: 'Error: $message',
              style: const TextStyle(
                color: Color(0xFFA44732),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (retry != null)
              TextButton(onPressed: retry, child: const Text('Try again')),
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  final String title;
  const EmptyState({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(title, style: const TextStyle(color: AppTheme.muted)),
        ),
      );
}

/// The same line icons used in the uploaded design.
class BrandIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  const BrandIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });
  static final names = <IconData, String>{
    Icons.home_outlined: 'home',
    Icons.home: 'homeF',
    Icons.timeline: 'activity',
    Icons.bar_chart: 'activity',
    Icons.inventory_2_outlined: 'box',
    Icons.inventory_2: 'box',
    Icons.person_outline: 'user',
    Icons.people_outline: 'user',
    Icons.notifications_outlined: 'bell',
    Icons.search: 'search',
    Icons.arrow_back: 'back',
    Icons.chevron_right: 'chevRight',
    Icons.keyboard_arrow_down: 'chevDown',
    Icons.location_on_outlined: 'pin',
    Icons.location_on: 'pin',
    Icons.schedule: 'clock',
    Icons.chat_bubble_outline: 'chat',
    Icons.chat_outlined: 'chat',
    Icons.phone: 'phone',
    Icons.phone_outlined: 'phone',
    Icons.star: 'star',
    Icons.check: 'check',
    Icons.navigation_outlined: 'navigation',
    Icons.share_outlined: 'share',
    Icons.send_outlined: 'send',
    Icons.card_giftcard: 'gift',
    Icons.settings_outlined: 'sliders',
    Icons.tune: 'sliders',
    Icons.local_shipping_outlined: 'truck',
    Icons.account_balance_wallet_outlined: 'wallet',
    Icons.shield_outlined: 'shield',
    Icons.verified_user_outlined: 'shield',
    Icons.arrow_forward: 'arrowRight',
    Icons.close: 'close',
    Icons.description_outlined: 'doc',
    Icons.calendar_today_outlined: 'calendar',
    Icons.shopping_bag_outlined: 'bag',
    Icons.bolt: 'bolt',
    Icons.more_horiz: 'more',
  };
  @override
  Widget build(BuildContext context) {
    final name = names[icon];
    if (name == null) {
      return Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
    }
    final theme = IconTheme.of(context);
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SvgPicture.asset(
        'assets/icons/$name.svg',
        width: size ?? theme.size ?? 22,
        height: size ?? theme.size ?? 22,
        semanticsLabel: semanticLabel,
        colorFilter: ColorFilter.mode(
          color ?? theme.color ?? AppTheme.charcoal,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final double size;
  const IconTile(
    this.icon, {
    super.key,
    this.tint = AppTheme.sage,
    this.size = 44,
  });
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: BrandIcon(icon, size: 22),
      );
}

class SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  final Color tint;
  const SquareButton({
    super.key,
    required this.icon,
    this.onPressed,
    required this.label,
    this.tint = Colors.white,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          onPressed: onPressed,
          tooltip: label,
          style: IconButton.styleFrom(
            backgroundColor: tint,
            side: const BorderSide(color: AppTheme.border),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: BrandIcon(icon, size: 21),
        ),
      );
}

/// Prototype header: square back button above an uncentered page heading.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool compact;
  const AppHeader({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.compact = false,
  });
  @override
  Size get preferredSize => Size.fromHeight(
        compact || title == null
            ? 64
            : title is Text && ((title as Text).data?.length ?? 0) > 23
                ? 144
                : 112,
      );
  @override
  Widget build(BuildContext context) => compact
      ? SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                if (title != null)
                  Expanded(
                    child: DefaultTextStyle(
                      style: AppTheme.heading(26),
                      child: title!,
                    ),
                  ),
                ...?actions,
              ],
            ),
          ),
        )
      : SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leading ??
                        (automaticallyImplyLeading
                            ? SquareButton(
                                icon: Icons.arrow_back,
                                label: 'Back',
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              )
                            : const SizedBox(width: 44, height: 44)),
                    const Spacer(),
                    ...?actions,
                  ],
                ),
                if (title != null) ...[
                  const SizedBox(height: 14),
                  DefaultTextStyle(style: AppTheme.heading(26), child: title!),
                ],
              ],
            ),
          ),
        );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionHeading(this.title, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTheme.heading(19, weight: FontWeight.w600),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      );
}

class MenuRow extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;
  const MenuRow({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.icon,
    this.tint = AppTheme.sage,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          child: Row(
            children: [
              IconTile(icon, tint: tint, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const BrandIcon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFFC9CDD4),
              ),
            ],
          ),
        ),
      );
}

class DarkPanel extends StatelessWidget {
  const DarkPanel({super.key, required this.child, this.padding = 22});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
            color: AppTheme.charcoal, borderRadius: BorderRadius.circular(8)),
        child: child,
      );
}

class SocialButtons extends StatelessWidget {
  final void Function(String provider) onPressed;
  const SocialButtons({super.key, required this.onPressed});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 12),
            child: Row(
              children: [
                Expanded(child: Divider(height: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or continue with',
                    style: TextStyle(fontSize: 10, color: AppTheme.muted),
                  ),
                ),
                Expanded(child: Divider(height: 1)),
              ],
            ),
          ),
          Row(
            children: [
              for (final provider in ['Google', 'Apple']) ...[
                if (provider == 'Apple') const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => onPressed(provider.toLowerCase()),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFFAFBF9),
                        side: const BorderSide(color: Color(0xFFE7EAE5)),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: provider == 'Apple'
                          ? const Icon(Icons.apple, size: 18)
                          : SvgPicture.asset('assets/brand/google.svg',
                              width: 18, height: 18),
                      label: Text(provider),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
}

class DesignFormField extends StatelessWidget {
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText, readOnly, enabled;
  final int? maxLength;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  const DesignFormField({
    super.key,
    this.controller,
    this.decoration = const InputDecoration(),
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLength,
    this.onTap,
    this.maxLines = 1,
    this.onChanged,
    this.autofillHints,
    this.style,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
  });
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (decoration.labelText?.isNotEmpty == true) ...[
            Text(
              decoration.labelText!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF454E58),
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            obscureText: obscureText,
            readOnly: readOnly,
            enabled: enabled,
            maxLength: maxLength,
            maxLines: maxLines,
            onTap: onTap,
            onChanged: onChanged,
            autofillHints: autofillHints,
            style: style,
            textAlign: textAlign,
            textCapitalization: textCapitalization,
            decoration: decoration.labelText == null
                ? decoration
                : decoration.copyWith(
                    labelText: '',
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
          ),
        ],
      );
}

class ServiceSwitch extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const ServiceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4ED),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            for (final item in [
              ('p2p', 'P2P Delivery', 'Name your price'),
              ('express', 'Express', 'Instant quote'),
            ])
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(item.$1),
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color:
                          value == item.$1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: value == item.$1
                          ? const [
                              BoxShadow(
                                color: Color(0x11101319),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          item.$2,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: value == item.$1
                                ? AppTheme.charcoal
                                : AppTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$3,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class RouteCard extends StatelessWidget {
  final String? pickup, destination;
  final VoidCallback? onPickup, onDestination;
  const RouteCard({
    super.key,
    this.pickup,
    this.destination,
    this.onPickup,
    this.onDestination,
  });
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          children: [
            routePoint('PICKUP', pickup ?? 'Select pickup', false, onPickup),
            const Padding(
              padding: EdgeInsets.only(left: 24),
              child: Divider(height: 24),
            ),
            routePoint(
              'DROP-OFF',
              destination ?? 'Select destination',
              true,
              onDestination,
            ),
          ],
        ),
      );
  Widget routePoint(
    String label,
    String address,
    bool end,
    VoidCallback? tap,
  ) =>
      InkWell(
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: end ? AppTheme.lime : Colors.white,
                  border: end
                      ? null
                      : Border.all(color: AppTheme.charcoal, width: 1.7),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(address, style: const TextStyle(fontSize: 13.5)),
                  ],
                ),
              ),
              if (tap != null)
                const BrandIcon(
                  Icons.chevron_right,
                  color: Color(0xFFCDD2D8),
                  size: 18,
                ),
            ],
          ),
        ),
      );
}

class ServiceHero extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color tint;
  const ServiceHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.tint = AppTheme.sage,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            IconTile(icon, tint: Colors.white.withValues(alpha: .65), size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.heading(17, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: AppTheme.bodyMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class MetricTile extends StatelessWidget {
  final String label, value;
  final String? caption;
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
  });
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.bodyMuted),
            ),
            const SizedBox(height: 8),
            Text(value, style: AppTheme.heading(24)),
            if (caption != null) ...[
              const SizedBox(height: 6),
              Text(
                caption!,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ],
        ),
      );
}

String money(dynamic minor) {
  final value = BigInt.tryParse('$minor');
  if (value == null) {
    throw ArgumentError('An integer minor-unit amount is required.');
  }
  final whole = value.abs() ~/ BigInt.from(100),
      cents = (value.abs() % BigInt.from(100)).toString().padLeft(2, '0');
  final grouped = whole.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return '\u20a6${value.isNegative ? '-' : ''}$grouped${cents == '00' ? '' : '.$cents'}';
}

String statusLabel(dynamic value) =>
    const {
      'draft': 'Draft',
      'pending_payment': 'Awaiting payment',
      'awaiting_deliverer': 'Finding a deliverer',
      'offer_received': 'Offers received',
      'deliverer_assigned': 'Deliverer confirmed',
      'accepted': 'Accepted',
      'awaiting_confirmation': 'Awaiting confirmation',
      'disputed': 'Under review',
      'return_requested': 'Return requested',
      'return_approved': 'Return approved',
      'rejected': 'Rejected',
      'assigned': 'Deliverer confirmed',
      'heading_to_pickup': 'Heading to pickup',
      'arrived_pickup': 'At pickup',
      'picked_up': 'Picked up',
      'heading_to_dropoff': 'On the way',
      'arrived_dropoff': 'At your door',
      'delivered': 'Awaiting confirmation',
      'completed': 'Delivered',
      'cancelled': 'Cancelled',
      'returning': 'Returning to sender',
      'returned': 'Returned',
      'failed': 'Delivery stopped',
    }[value] ??
    '$value'.replaceAll('_', ' ');
