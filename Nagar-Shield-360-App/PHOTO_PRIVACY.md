# Photo privacy and content confirmation

New citizen report photos and field-task after-evidence photos pass through a local review screen before attachment. Android 8/API 26 or later is required for this implementation.

1. Check the selected image locally using the bundled `nsfw_detector_flutter` 2.0.2 model. Scores from 0.4 upwards prompt the user. This is a probabilistic signal, not a definitive label.
2. A possible nudity/explicit-content result opens a Yes/No warning. Yes continues; No returns without attaching the image. This warning does not blur sexual content or automatically reject the user's choice.
3. Independently, bundled Android face detection pixelates detected faces with padding, and local Latin-script text recognition covers recognized text. No image is uploaded for these checks.
4. The user can drag extra opaque rectangles over missed information, including Bengali text, then must confirm the preview. Automatic masks cannot be undone; the Undo action only removes a newly drawn manual rectangle.
5. Only the processed copy is returned to the report/evidence flow. Re-encoding creates a new JPEG without copying source EXIF/GPS metadata. The gallery original is untouched.

If decoding, the model or privacy processing fails, no original image is silently attached. The user can choose another image; citizen reports can also be submitted without a photo when the description is adequate. Cancellation cleans up generated preview copies. Legacy report drafts are rechecked before submission, but this change does not retroactively rewrite photos already in a pending upload queue.

The native privacy processor is Android-only. iOS and desktop processing need separate platform implementations and are currently unavailable; they do not fall back to attaching unprocessed originals. Imported survey videos and arbitrary web uploads are outside these two photo-selection paths. These are client-side controls; they do not enforce a server-side moderation policy against modified clients.

Small, obscured or angled faces can be missed. The text model recognizes Latin scripts, not Bengali reliably. The manual review is required for these reasons. Content confirmation, face redaction, and final form submission are separate decisions.

## Sources

- [Google face detection, bundled library](https://developers.google.com/ml-kit/vision/face-detection/android)
- [Google text recognition, bundled Latin-script library](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)
- [nsfw_detector_flutter 2.0.2](https://pub.dev/packages/nsfw_detector_flutter), MIT; bundled Yahoo/open_nsfw-derived model under BSD 3-Clause.
- [Bundled model copyright and license notice](assets/presets/PRIVACY_MODEL_LICENSE.txt)

The test fixture uses the public-domain US Navy Grace Hopper portrait distributed in TensorFlow's example images, with a synthetic test contact line added. It contains no explicit content. Model classification accuracy on explicit imagery is not established by that fixture. Choice-policy tests use injected scores, and UI tests inject a model verdict to test both Yes and No without sensitive media.
