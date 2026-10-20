import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'premium_ui.dart';

class AppPage extends StatelessWidget {
  const AppPage(
      {super.key,
      required this.title,
      required this.children,
      this.subtitle,
      this.eyebrow,
      this.actions = const [],
      this.footer,
      this.embedded = false});
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final List<Widget> children;
  final List<Widget> actions;
  final Widget? footer;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
        child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (!embedded) ...[
          Row(children: [
            IconButton.outlined(
                tooltip: 'Back',
                style: IconButton.styleFrom(
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13))),
                icon: const Icon(Icons.chevron_left, size: 22),
                onPressed: () => Navigator.maybePop(context)),
            const Spacer(),
            ...actions,
          ]),
          const SizedBox(height: 12),
        ],
        PremiumHeader(
            title: title,
            subtitle: subtitle,
            eyebrow: eyebrow,
            trailing: embedded && actions.isNotEmpty
                ? Row(mainAxisSize: MainAxisSize.min, children: actions)
                : null),
        const SizedBox(height: 20),
        ...children,
      ],
    ));
    if (embedded) return body;
    return Scaffold(
        body: body,
        bottomNavigationBar: footer == null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: footer)));
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15))),
          if (trailing != null) trailing!
        ]),
      );
}

class InfoBand extends StatelessWidget {
  const InfoBand(
      {super.key,
      required this.title,
      this.body,
      this.icon = Icons.shield_outlined,
      this.dark = false});
  final String title;
  final String? body;
  final IconData icon;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: dark ? AppColors.ink : AppColors.tint['lime'],
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon,
              size: 20,
              color: dark ? AppColors.accent : const Color(0xFF79913B)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: dark ? Colors.white : AppColors.ink)),
                if (body != null) ...[
                  const SizedBox(height: 5),
                  Text(body!,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: dark ? AppColors.faint : AppColors.inkSoft))
                ],
              ])),
        ]),
      );
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.dark = false});
  final String label;
  final String value;
  final bool dark;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.muted))),
          const SizedBox(width: 16),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : AppColors.ink))),
        ]),
      );
}

class RouteTile extends StatelessWidget {
  const RouteTile(
      {super.key,
      required this.title,
      required this.icon,
      this.subtitle,
      this.route,
      this.arguments,
      this.onTap,
      this.trailing});
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? route;
  final Object? arguments;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppColors.tint['lime'],
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.ink)),
        title: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        trailing: trailing ??
            const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
        onTap: onTap ??
            (route == null
                ? null
                : () =>
                    Navigator.pushNamed(context, route!, arguments: arguments)),
      );
}

class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InfoBand(
            title: 'Currently unavailable',
            body: error.toString(),
            icon: Icons.info_outline),
        if (onRetry != null)
          TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again')),
      ]);
}

Future<bool> confirmAction(
        BuildContext context, String title, String body) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm')),
              ],
            )) ??
    false;

void showActionError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
