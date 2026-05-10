import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UiHelper {
  static double _clampedScaleFactor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final factor = width / 375.0;
    return factor.clamp(0.85, 1.05);
  }

  static double scale(BuildContext context, double size) {
    return size * _clampedScaleFactor(context);
  }

  static double responsiveFontSize(BuildContext context, double size) {
    return size * _clampedScaleFactor(context);
  }

  static EdgeInsets responsivePadding(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
  }) {
    final factor = _clampedScaleFactor(context);
    return EdgeInsets.symmetric(
      horizontal: horizontal * factor,
      vertical: vertical * factor,
    );
  }

  static Widget loadingIndicator({double size = 24, Color? color}) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? const Color(0xFF2E8B57),
        ),
      ),
    );
  }

  static void showCustomSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF2E8B57),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static void showCenteredSnackBar(
    BuildContext context,
    String message, {
    bool isSuccess = true,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    final media = MediaQuery.maybeOf(context);
    final height = media?.size.height ?? 0;
    final width = media?.size.width ?? 360;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width * 0.86),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: isSuccess
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: height / 2.2, left: 20, right: 20),
        duration: duration,
      ),
    );
  }

  static Future<void> showSuccessDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF2E8B57),
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Great!',
              style: TextStyle(
                color: Color(0xFF2E8B57),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int cacheSizePx(
    BuildContext context,
    double logicalSize, {
    int min = 64,
    int max = 1200,
  }) {
    final mq = MediaQuery.maybeOf(context);
    final dpr = mq?.devicePixelRatio ?? 2.0;
    final fallback = mq?.size.width ?? 375;
    final safeLogical = logicalSize.isFinite && logicalSize > 0
        ? logicalSize
        : fallback;
    final px = (safeLogical * dpr).round();
    return px.clamp(min, max);
  }

  static Widget buildImage(
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    // Handle empty URLs
    if (url.isEmpty) {
      return errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
          );
    }

    // Handle base64 data URIs
    if (url.startsWith('data:image')) {
      return FutureBuilder<Uint8List>(
        future: compute(_decodeBase64, url),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              width: width,
              height: height,
              color: Colors.black.withValues(alpha: 0.03),
            );
          }
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                errorWidget ??
                Container(
                  width: width,
                  height: height,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.grey,
                  ),
                ),
          );
        },
      );
    }

    final int? resolvedCacheWidth =
        cacheWidth ??
        ((width != null && width.isFinite && width > 0)
            ? (width * 2).round().clamp(64, 1200)
            : null);
    final int? resolvedCacheHeight =
        cacheHeight ??
        ((height != null && height.isFinite && height > 0)
            ? (height * 2).round().clamp(64, 1200)
            : null);

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.low,
      useOldImageOnUrlChange: true,
      memCacheWidth: resolvedCacheWidth,
      memCacheHeight: resolvedCacheHeight,
      maxWidthDiskCache: resolvedCacheWidth,
      maxHeightDiskCache: resolvedCacheHeight,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholderFadeInDuration: Duration.zero,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Colors.black.withValues(alpha: 0.03),
      ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
          ),
    );
  }
  static Uint8List _decodeBase64(String url) {
    return base64Decode(url.split(',').last);
  }
}
