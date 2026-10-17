import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nagar_shield_360/photo_privacy.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real local models protect a face and printed test contact; manual masks are baked into bytes',
    (tester) async {
      final data = await rootBundle.load('assets/presets/privacy_fixture.jpg');
      final dir = await Directory.systemTemp.createTemp('privacy_integration_');
      try {
        final source = File('${dir.path}/source.jpg');
        await source.writeAsBytes(data.buffer.asUint8List());
        final engine = PhotoPrivacy();
        var confirmationAsked = false;
        final protected = await engine.protect(
          source.path,
          confirmExplicit: (_) async {
            confirmationAsked = true;
            return false;
          },
        );
        expect(
          confirmationAsked,
          false,
          reason:
              'The fully clothed public-domain test portrait should pass the content check.',
        );
        expect(protected.faces, greaterThanOrEqualTo(1));
        expect(protected.textRegions, greaterThanOrEqualTo(1));
        expect(protected.path, isNot(source.path));
        final masked = await engine.mask(protected, [
          const ui.Rect.fromLTRB(.1, .2, .9, .8),
        ]);
        final codec = await ui.instantiateImageCodec(
          await File(masked.path).readAsBytes(),
        );
        final image = (await codec.getNextFrame()).image;
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final rgba = Uint8List.view(bytes.buffer);
        final offset =
            ((image.height ~/ 2) * image.width + (image.width ~/ 2)) * 4;
        expect(rgba[offset], closeTo(23, 12));
        expect(rgba[offset + 1], closeTo(59, 12));
        expect(rgba[offset + 2], closeTo(54, 12));
        image.dispose();
        codec.dispose();
        await File(masked.path).delete();
        await File(protected.path).delete();
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
