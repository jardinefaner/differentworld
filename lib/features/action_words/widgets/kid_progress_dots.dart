import 'package:flutter/material.dart';

/// N big dots that fill left-to-right — the kid-legible progress meter shared
/// by the action-words kid surfaces (words picked on the pick screen, jobs
/// finished on the job screen).
class KidProgressDots extends StatelessWidget {
  const KidProgressDots({
    required this.filled,
    required this.total,
    super.key,
  });

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: i < filled ? scheme.primary : scheme.outline,
                  width: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
