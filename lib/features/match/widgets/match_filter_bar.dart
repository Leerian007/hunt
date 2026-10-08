import 'package:flutter/material.dart';

import '../../../models/match_filter.dart';
export '../../../models/match_filter.dart';

/// Controlled selection: the parent owns [selectedFilter] and the visible list.
class MatchFilterBar extends StatelessWidget {
  const MatchFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onChanged,
  });

  final MatchFilter selectedFilter;
  final ValueChanged<MatchFilter> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: MatchFilter.values.map((filter) {
      final selected = filter == selectedFilter;
      return Semantics(
        selected: selected,
        child: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            foregroundColor: selected
                ? const Color(0xFF141C21)
                : const Color(0xFFADBAC1),
            backgroundColor: selected
                ? const Color(0xFFD5BC86)
                : const Color(0xFF1A2831),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            if (!selected) onChanged(filter);
          },
          child: Text(filter.label),
        ),
      );
    }).toList(),
  );
}
