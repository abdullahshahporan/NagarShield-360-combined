import 'dart:io';

import 'package:flutter/services.dart';
import 'package:nsfw_detector_flutter/nsfw_detector_flutter.dart';

import 'photo_safety_policy.dart';

class PhotoProtectionException implements Exception {
  const PhotoProtectionException(this.decision, {this.declined = false});
  final PhotoContentDecision decision;
  final bool declined;
}

class ProtectedPhoto {
  const ProtectedPhoto({
    required this.path,
    required this.width,
    required this.height,
    required this.faces,
    required this.textRegions,
  });
  final String path;
  final int width;
  final int height;
  final int faces;
  final int textRegions;

  factory ProtectedPhoto.fromMap(Map<Object?, Object?> map) => ProtectedPhoto(
    path: map['path']! as String,
    width: (map['width']! as num).toInt(),
    height: (map['height']! as num).toInt(),
    faces: (map['faces']! as num).toInt(),
    textRegions: (map['textRegions']! as num).toInt(),
  );
}

class PhotoPrivacy {
  static const _channel = MethodChannel('bd.nagarshield/photo_privacy');

  Future<ProtectedPhoto> protect(
    String originalPath, {
    Future<bool> Function(PhotoContentDecision)? confirmExplicit,
  }) async {
    if (!Platform.isAndroid) {
      throw const PhotoProtectionException(PhotoContentDecision.unavailable);
    }
    final original = File(originalPath);
    // Do not decode or classify arbitrarily large files in a UI isolate.
    if (await original.length() > 20 * 1024 * 1024) {
      throw const PhotoProtectionException(PhotoContentDecision.unavailable);
    }
    final verdict = await NsfwDetector.detectBytesInBackground(
      await original.readAsBytes(),
    );
    final decision = PhotoSafetyPolicy.classify(verdict?.score);
    if (decision == PhotoContentDecision.unavailable) {
      throw PhotoProtectionException(decision);
    }
    final confirmed =
        decision == PhotoContentDecision.allow ||
        await confirmExplicit?.call(decision) == true;
    if (!PhotoSafetyPolicy.mayContinue(verdict?.score, confirmed: confirmed)) {
      throw PhotoProtectionException(decision, declined: true);
    }
    final map = await _channel.invokeMapMethod<Object?, Object?>('protect', {
      'path': originalPath,
    });
    if (map == null) {
      throw const PhotoProtectionException(PhotoContentDecision.unavailable);
    }
    return ProtectedPhoto.fromMap(map);
  }

  Future<ProtectedPhoto> mask(ProtectedPhoto photo, List<Rect> rects) async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('mask', {
      'path': photo.path,
      'rects': [
        for (final r in rects)
          {'left': r.left, 'top': r.top, 'right': r.right, 'bottom': r.bottom},
      ],
    });
    if (map == null) {
      throw const PhotoProtectionException(PhotoContentDecision.unavailable);
    }
    final next = ProtectedPhoto.fromMap(map);
    return ProtectedPhoto(
      path: next.path,
      width: next.width,
      height: next.height,
      faces: photo.faces,
      textRegions: photo.textRegions,
    );
  }
}
