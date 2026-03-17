import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class FilterChipWidget extends StatelessWidget {
  final String label;
  final String selectedValue;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const FilterChipWidget({
    super.key,
    required this.label,
    required this.selectedValue,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFilterOptions(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: selectedValue != 'All'
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: selectedValue != 'All'
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedValue == 'All' ? label : selectedValue,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selectedValue != 'All'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight:
                    selectedValue != 'All' ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            SizedBox(width: 1.w),
            CustomIconWidget(
              iconName: 'keyboard_arrow_down',
              color: selectedValue != 'All'
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              child: Text(
                'Select $label',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...options.map((option) => ListTile(
                  title: Text(option),
                  trailing: selectedValue == option
                      ? CustomIconWidget(
                          iconName: 'check',
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    onChanged(option);
                    Navigator.pop(context);
                  },
                )),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }
}
