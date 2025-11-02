import 'package:flutter/widgets.dart';
import 'cropped_image_provider.dart';

class ImageUtils {
  static String getCarImageUrl(String carId, String imageId, {String size = 'mediums'}) {
    return 'https://www.ultimatecarpage.com/images/$size/$imageId.jpg';
  }

  static String getCarThumbnailUrl(String carId, String imageId) {
    return getCarImageUrl(carId, imageId, size: 'thumbs');
  }

  static String getCarMediumImageUrl(String carId, String imageId) {
    return getCarImageUrl(carId, imageId, size: 'mediums');
  }

  static String getCarLargeImageUrl(String carId, String slug, String imageId) {
    return 'https://www.ultimatecarpage.com/images/car/$carId/$slug-$imageId.jpg';
  }

  /// Creates a widget that uses actual pixel-level cropping
  /// This removes the specified percentage from all edges by cropping the actual image data
  static Widget croppedCachedNetworkImage({
    required String imageUrl,
    BoxFit fit = BoxFit.cover,
    double cropPercent = 0.05,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CroppedNetworkImage(
      imageUrl: imageUrl,
      cropPercent: cropPercent,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  /// Wraps an image widget with clipping to remove 5% from all edges (to remove watermark)
  /// DEPRECATED: Use croppedCachedNetworkImage for actual pixel-level cropping
  @Deprecated('Use croppedCachedNetworkImage for actual pixel-level cropping instead')
  static Widget cropImageEdges(Widget image, {double cropPercent = 0.0}) {
    if (cropPercent <= 0) {
      return image; // No cropping needed
    }
    
    // To crop 5% from all sides:
    // Scale up the image, then use Align with widthFactor/heightFactor to show only the center portion
    // This effectively clips 5% from each edge
    // For 5% crop: scale = 1/(1-0.1) = 1/0.9 ≈ 1.111
    final scale = 1.0 / (1.0 - (cropPercent * 2));
    final visibleFactor = 1.0 / scale; // The portion we want to show (0.9 for 5% crop)
    
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: Align(
        alignment: Alignment.center,
        widthFactor: visibleFactor,  // Show only 90% width (center portion)
        heightFactor: visibleFactor, // Show only 90% height (center portion)
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: image,
        ),
      ),
    );
  }
}

