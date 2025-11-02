import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Wraps an image widget with a watermark overlay at the top right corner
class WatermarkedImage extends StatelessWidget {
  final Widget image;

  const WatermarkedImage({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The actual image
        image,
        // Image watermark overlay at top right
        SafeArea(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    'assets/images/watermark.png',
                    width: Responsive.scaleWidth(context, 150),
                    height: Responsive.scaleHeight(context, 150),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

      ],
    );
  }
}

