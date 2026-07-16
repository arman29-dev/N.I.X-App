import 'package:flutter/material.dart';

class SectionData {
  final String label;
  final IconData icon;
  final Color activeColor;
  final int badgeCount;

  const SectionData({
    required this.label,
    required this.icon,
    required this.activeColor,
    this.badgeCount = 0,
  });
}

class SlidingSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<SectionData> sections;

  const SlidingSelector({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final pillWidth = (screenWidth - 30) / sections.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment(
                -1 + (2.0 / (sections.length - 1)) * selectedIndex,
                0,
              ),
              child: Container(
                width: pillWidth,
                height: 34,
                decoration: BoxDecoration(
                  color: sections[selectedIndex].activeColor.withValues(alpha: 0.50),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            Row(
              children: List.generate(sections.length, (i) {
                final section = sections[i];
                final isSelected = i == selectedIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            section.icon,
                            size: 24,
                            color: isSelected
                                ? section.activeColor
                                : Colors.white54,
                          ),
                          if (section.badgeCount > 0)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  section.badgeCount > 99 ? '99+' : '${section.badgeCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
