import 'package:flutter_test/flutter_test.dart';
import 'package:nagar_shield_360/photo_safety_policy.dart';

void main() {
  test(
    'unavailable or invalid scores cannot silently allow an original photo',
    () {
      for (final value in [null, double.nan, double.infinity, -.01, 1.01]) {
        expect(
          PhotoSafetyPolicy.classify(value),
          PhotoContentDecision.unavailable,
        );
      }
    },
  );
  test(
    'uncertain and explicit images require a choice rather than auto-blocking',
    () {
      expect(PhotoSafetyPolicy.classify(.3999), PhotoContentDecision.allow);
      expect(PhotoSafetyPolicy.classify(.4), PhotoContentDecision.review);
      expect(PhotoSafetyPolicy.classify(.6999), PhotoContentDecision.review);
      expect(PhotoSafetyPolicy.classify(.7), PhotoContentDecision.explicit);
      expect(PhotoSafetyPolicy.classify(1), PhotoContentDecision.explicit);
      for (final score in [.4, .7, 1.0]) {
        expect(PhotoSafetyPolicy.mayContinue(score, confirmed: false), false);
        expect(PhotoSafetyPolicy.mayContinue(score, confirmed: true), true);
      }
      expect(PhotoSafetyPolicy.mayContinue(double.nan, confirmed: true), false);
      expect(PhotoSafetyPolicy.mayContinue(.1, confirmed: false), true);
    },
  );
}
