import 'package:flutter/material.dart';
import '../tokens/dct_colors.dart';
import '../tokens/dct_spacing.dart';

class DctCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const DctCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DctColors.card,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: padding ?? DctSpacing.cardPadding,
          decoration: BoxDecoration(
            border: Border.all(color: DctColors.fog.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ),
    );
  }
}
