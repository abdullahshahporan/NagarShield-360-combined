enum PhotoContentDecision { allow, review, explicit, unavailable }

class PhotoSafetyPolicy {
  static PhotoContentDecision classify(double? score) {
    if (score == null || !score.isFinite || score < 0 || score > 1) {
      return PhotoContentDecision.unavailable;
    }
    if (score >= 0.7) return PhotoContentDecision.explicit;
    if (score >= 0.4) return PhotoContentDecision.review;
    return PhotoContentDecision.allow;
  }

  static bool mayContinue(double? score, {required bool confirmed}) =>
      switch (classify(score)) {
        PhotoContentDecision.allow => true,
        PhotoContentDecision.review ||
        PhotoContentDecision.explicit => confirmed,
        PhotoContentDecision.unavailable => false,
      };
}
