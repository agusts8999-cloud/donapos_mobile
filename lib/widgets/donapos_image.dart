import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/utils_scaler.dart';

class DonaposImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final double? opacity;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const DonaposImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.color,
    this.opacity,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildError(context);
    }

    Widget image;

    if (imageUrl!.startsWith('assets/')) {
      image = Image.asset(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        color: color?.withOpacity(opacity ?? 1.0) ?? color,
        opacity: opacity != null ? AlwaysStoppedAnimation(opacity!) : null,
      );
    } else if (imageUrl!.startsWith('/')) {
      // Local file path
      image = Image.file(
        File(imageUrl!),
        width: width,
        height: height,
        fit: fit,
        color: color?.withOpacity(opacity ?? 1.0) ?? color,
        opacity: opacity != null ? AlwaysStoppedAnimation(opacity!) : null,
      );
    } else {
      // Network image with caching
      image = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        color: color,
        colorBlendMode: opacity != null ? BlendMode.modulate : null,
        placeholder: (context, url) => placeholder ?? _buildPlaceholder(context),
        errorWidget: (context, url, error) => errorWidget ?? _buildError(context),
        imageBuilder: opacity != null ? (context, imageProvider) => Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageProvider,
              fit: fit,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(1.0 - opacity!),
                BlendMode.dstATop,
              ),
            ),
          ),
        ) : null,
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      child: Center(
        child: DonaposLoader(size: (width ?? 40.sc) / 2),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade300, size: (width ?? 40.sc) / 2),
      ),
    );
  }

  /// Utility to get a Cached Image Provider for use in DecorationImage or CircleAvatar
  static ImageProvider provider(String? url, {String fallbackAsset = 'assets/images/logo.png'}) {
    if (url == null || url.isEmpty) {
      return AssetImage(fallbackAsset);
    }

    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }

    if (url.startsWith('/')) {
      return FileImage(File(url));
    }

    return CachedNetworkImageProvider(url);
  }
}
