import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nagar_shield_360/photo_privacy.dart';
import 'package:nagar_shield_360/photo_safety_policy.dart';
import 'package:nagar_shield_360/ui/photo_privacy_page.dart';

class ExplicitExample extends PhotoPrivacy {
  ExplicitExample(this.path);
  final String path;
  @override
  Future<ProtectedPhoto> protect(
    String originalPath, {
    Future<bool> Function(PhotoContentDecision)? confirmExplicit,
  }) async {
    if (await confirmExplicit?.call(PhotoContentDecision.explicit) != true) {
      throw const PhotoProtectionException(
        PhotoContentDecision.explicit,
        declined: true,
      );
    }
    return ProtectedPhoto(
      path: path,
      width: 1,
      height: 1,
      faces: 0,
      textRegions: 0,
    );
  }
}

void main() {
  for (final agree in [false, true]) {
    testWidgets(
      'explicit warning ${agree ? 'yes continues to preview' : 'no returns without attaching'}',
      (tester) async {
        final dir = Directory.systemTemp.createTempSync('privacy_choice_');
        final image = File('${dir.path}/example.png');
        image.writeAsBytesSync(
          File('assets/presets/privacy_fixture.jpg').readAsBytesSync(),
        );
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PhotoPrivacyPage(
                          path: image.path,
                          bangla: true,
                          privacy: ExplicitExample(image.path),
                        ),
                      ),
                    ),
                    child: const Text('খুলুন'),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => precacheImage(
              FileImage(image),
              tester.element(find.text('খুলুন')),
            ),
          );
          await tester.tap(find.text('খুলুন'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('এই ছবিটি পাঠাতে চান?'), findsOneWidget);
          await tester.tap(
            find.text(agree ? 'হ্যাঁ, চালিয়ে যান' : 'না, অন্য ছবি'),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(agree ? 'ঢাকা ছবিটি ব্যবহার করুন' : 'খুলুন'),
            findsOneWidget,
          );
          if (agree) {
            final button = tester.widget<FilledButton>(
              find.byWidgetPredicate((w) => w is FilledButton),
            );
            expect(
              button.onPressed,
              isNull,
              reason:
                  'A separate privacy preview confirmation is still required.',
            );
          }
          await tester.pumpWidget(const SizedBox());
        } finally {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        }
      },
    );
  }
}
