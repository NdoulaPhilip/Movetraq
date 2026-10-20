import 'package:flutter/material.dart';
import '../models/parcel_order.dart';
import '../theme/app_theme.dart';

String naira(num amount) {
  final parts = amount
      .toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)
      .split('.');
  final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
  return '\u20a6$whole${parts.length > 1 ? '.${parts.last}' : ''}';
}

String shortDate(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'Today';
  if (day == DateTime(now.year, now.month, now.day - 1)) return 'Yesterday';
  return '${local.day}/${local.month}/${local.year}';
}

class DesignCard extends StatelessWidget {
  const DesignCard(
      {super.key,
      required this.child,
      this.dark = false,
      this.color,
      this.padding = const EdgeInsets.all(17)});
  final Widget child;
  final bool dark;
  final Color? color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: color ?? (dark ? AppColors.ink : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: dark ? AppColors.ink : const Color(0xFFEAECE5)),
          boxShadow: dark
              ? null
              : const [
                  BoxShadow(
                      color: Color(0x03000000),
                      blurRadius: 16,
                      offset: Offset(0, 4))
                ]),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        if (dark)
          Positioned(
              right: -18,
              top: -24,
              child: IgnorePointer(
                  child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(48))))),
        Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
                style: TextStyle(color: dark ? Colors.white : AppColors.ink),
                child: child)),
      ]));
}

class DesignSection extends StatelessWidget {
  const DesignSection(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Text(title,
          style: const TextStyle(
              fontSize: 11,
              letterSpacing: .6,
              fontWeight: FontWeight.w600,
              color: AppColors.muted)));
}

class DesignMetric extends StatelessWidget {
  const DesignMetric({super.key, required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => DesignCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Column(children: [
        Text(value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]));
}

class DesignNote extends StatelessWidget {
  const DesignNote({super.key, required this.title, this.body, this.reference});
  final String title;
  final String? body, reference;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DesignCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (reference != null) ...[
          Text(reference!, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 5)
        ],
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (body != null) ...[
          const SizedBox(height: 12),
          Text(body!,
              style: const TextStyle(
                  fontSize: 13, height: 1.65, color: Color(0xFF7D8878)))
        ],
      ])));
}

class DesignBadge extends StatelessWidget {
  const DesignBadge(this.label, {super.key, this.warning = false});
  final String label;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: warning ? const Color(0xFFFFF3E1) : const Color(0xFFEAF3DF),
          borderRadius: BorderRadius.circular(30)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: warning
                  ? const Color(0xFFB77900)
                  : const Color(0xFF608109))));
}

class DesignAvatar extends StatelessWidget {
  const DesignAvatar(this.name, {super.key, this.radius = 23});
  final String name;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.accent,
        child: Text(
            parts.isEmpty
                ? '?'
                : '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'
                    .toUpperCase(),
            style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: radius * .65)));
  }
}

class ParcelIcon extends StatelessWidget {
  const ParcelIcon(this.category, {super.key});
  final String category;
  @override
  Widget build(BuildContext context) => Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
          color: switch (category) {
            'document' || 'documents' => const Color(0xFFE4EDF7),
            'fragile' => const Color(0xFFFBEADA),
            'food' || 'groceries' => const Color(0xFFDCF1E6),
            _ => const Color(0xFFF0F4D9),
          },
          borderRadius: BorderRadius.circular(13)),
      child: Icon(
          switch (category) {
            'document' || 'documents' => Icons.description_outlined,
            'fragile' => Icons.card_giftcard_outlined,
            'food' || 'groceries' => Icons.shopping_bag_outlined,
            _ => Icons.inventory_2_outlined,
          },
          size: 20,
          color: AppColors.ink));
}

class DesignRoute extends StatelessWidget {
  const DesignRoute(
      {super.key,
      required this.pickup,
      required this.destination,
      this.compact = false});
  final String pickup, destination;
  final bool compact;
  @override
  Widget build(BuildContext context) => compact
      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.circle, size: 7, color: AppColors.faint),
          const SizedBox(width: 7),
          Expanded(
              child: Text(pickup,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.inkSoft))),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7),
              child:
                  Icon(Icons.arrow_forward, size: 13, color: AppColors.faint)),
          const Icon(Icons.circle, size: 7, color: AppColors.accent),
          const SizedBox(width: 7),
          Expanded(
              child: Text(destination,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600))),
        ])
      : Column(children: [
          _point('PICKUP ADDRESS', pickup, false),
          const Padding(
              padding: EdgeInsets.only(left: 20),
              child: Divider(height: 28, color: AppColors.cardBorder)),
          _point('DELIVERY ADDRESS', destination, true),
        ]);
  Widget _point(String label, String address, bool end) => Row(children: [
        Icon(end ? Icons.circle : Icons.circle_outlined,
            size: 9, color: end ? AppColors.accent : AppColors.ink),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(address,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ])),
      ]);
}

class DesignOrderCard extends StatelessWidget {
  const DesignOrderCard(
      {super.key,
      required this.order,
      required this.status,
      required this.onTap,
      this.driver = false});
  final ParcelOrder order;
  final String status;
  final VoidCallback onTap;
  final bool driver;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFEDEDEB))),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(children: [
                  ParcelIcon(order.category),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(order.title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('${order.code} · ${shortDate(order.createdAt)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                      ])),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(naira(driver ? order.payout : order.price),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(status,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: order.status == OrderStatus.cancelled
                                      ? AppColors.danger
                                      : const Color(0xFF608109))),
                        ]),
                  ),
                ]))),
      ));
}

class DesignMenuTile extends StatelessWidget {
  const DesignMenuTile(
      {super.key,
      required this.title,
      required this.icon,
      this.subtitle,
      this.route,
      this.arguments});
  final String title;
  final IconData icon;
  final String? subtitle, route;
  final Object? arguments;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: switch (icon) {
                  Icons.person_outline => const Color(0xFFF3F2EC),
                  Icons.location_on_outlined ||
                  Icons.credit_card =>
                    const Color(0xFFE4EDF7),
                  Icons.help_outline => const Color(0xFFEDE6F8),
                  _ => const Color(0xFFF0F4D9),
                },
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19)),
        title: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        trailing:
            const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
        onTap: route == null
            ? null
            : () => Navigator.pushNamed(context, route!, arguments: arguments),
      ));
}
