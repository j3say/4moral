import 'package:flutter/material.dart';

class ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool visible;

  const ScrollToBottomButton({
    super.key,
    required this.onPressed,
    this.visible = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      right: 16,
      bottom: 80,
      child: FloatingActionButton(
        mini: true,
        onPressed: onPressed,
        child: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}
