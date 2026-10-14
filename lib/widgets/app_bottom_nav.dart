import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const NavItem(
      {required this.icon, required this.selectedIcon, required this.label});
}

/// Bottom nav bar matching the design exactly: white bar, top hairline,
/// A compact lime tab identifies the selected destination.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<NavItem> items;
  final ValueChanged<int> onTap;

  const AppBottomNav(
      {super.key,
      required this.currentIndex,
      required this.items,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              final item = items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 30,
                        decoration: BoxDecoration(
                          color:
                              selected ? AppColors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: 19,
                          color: selected ? AppColors.ink : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(height: 20, child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                          item.label, maxLines: 1,
                          style: TextStyle(fontSize: 10.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? AppColors.ink : AppColors.faint),
                        )),
                      )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
