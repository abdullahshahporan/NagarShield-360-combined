import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nagar_shield_360/ui/operations_lab.dart';

void main() {
  testWidgets('seeded city operation opens and advances on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OperationsLab(bangla: true))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('বাজার করিডর: বর্জ্য, ড্রেন ও হাঁটার পথ'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('এই স্থাপনা থেকে কাজের খসড়া'),
      230,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('এই স্থাপনা থেকে কাজের খসড়া'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('এই স্থাপনা থেকে কাজের খসড়া'));
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 6 && find.text('নমুনা mission অনুমোদন').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('নমুনা mission অনুমোদন'));
    await tester.pumpAndSettle();
    expect(find.text('একটি সমন্বিত কাজ'), findsOneWidget);
    await tester.tap(find.text('নমুনা mission অনুমোদন'));
    await tester.pumpAndSettle();
    expect(find.text('নমুনা অনুমোদন প্রত্যাহার'), findsOneWidget);
    for (
      var attempt = 0;
      attempt < 6 && find.text('নমুনা দলকে দায়িত্ব দিন').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    final assign = find.text('নমুনা দলকে দায়িত্ব দিন').first;
    await tester.ensureVisible(assign);
    await tester.pumpAndSettle();
    await tester.tap(assign);
    await tester.pumpAndSettle();
    expect(find.text('দেওয়া · update দিন'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ছোট ড্রেন গাড়ি প্রস্তুত (নমুনা)'),
      -260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('ছোট ড্রেন গাড়ি প্রস্তুত (নমুনা)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ছোট ড্রেন গাড়ি প্রস্তুত (নমুনা)'));
    await tester.pumpAndSettle();
    expect(find.text('সরঞ্জাম বা অনুমতি নেই'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sewage and emergency access share a mapped response', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OperationsLab(bangla: true))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.drag(find.byType(ListView).at(1), const Offset(-560, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        ChoiceChip,
        'জরুরি চলাচলের রাস্তায় পয়ঃনিষ্কাশনের পানি',
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('নমুনা ক্লিনিক পথ ও sewer মানচিত্র'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('নমুনা ক্লিনিক পথ ও sewer মানচিত্র'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ক্যামেরায় যা দেখা যায় না'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('মাটির নিচের sewer ও pump-এর অবস্থা'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('4. কাজ'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('4. কাজ'));
    await tester.tap(find.text('4. কাজ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('দুর্ঘটনা বা আগুনে কে নেতৃত্ব দেবে?'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('পুলিশ ও অ্যাম্বুলেন্সের ঘটনাস্থল নেতৃত্ব'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('বিভাগ ও অংশীদার'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('বিভাগ ও অংশীদার'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
