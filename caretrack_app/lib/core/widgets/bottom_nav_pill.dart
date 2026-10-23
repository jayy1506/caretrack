import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class BottomNavPillItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const BottomNavPillItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// A modern floating pill bottom navigation bar for mobile views.
class BottomNavPill extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavPillItem> items;

  const BottomNavPill({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.borderGrey,
            width: 1,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppTheme.softShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = currentIndex == index;
            final activeColor = isDark ? AppTheme.mintAccent : AppTheme.primaryTeal;
            final inactiveColor = isDark ? Colors.white54 : AppTheme.slateMuted;

            return Expanded(
              child: Semantics(
                button: true,
                selected: isSelected,
                label: item.label,
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? AppTheme.mintAccent.withAlpha(35)
                              : AppTheme.primaryTeal.withAlpha(22))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                          size: 20,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? activeColor : inactiveColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
