// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:toeic_app/main.dart';

void main() {
  testWidgets('starts a reading question and checks the selected answer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ToeicReadingApp());

    expect(find.text('Bắt đầu luyện ngay'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu luyện ngay'));
    await tester.pumpAndSettle();

    expect(
      find.text('What should participants do before Friday?'),
      findsOneWidget,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -420));
    await tester.pumpAndSettle();
    final answer = find.text('Confirm their attendance before Friday.');
    await tester.ensureVisible(answer);
    await tester.tap(answer);
    await tester.pump();
    await tester.tap(find.text('Kiểm tra đáp án'));
    await tester.pump();

    expect(find.textContaining('Đáp án đúng là C.'), findsOneWidget);
    await tester.tap(find.text('Xem kết quả'));
    await tester.pumpAndSettle();

    expect(find.text('Kết quả bài làm'), findsOneWidget);
    expect(find.text('1 / 1 câu đúng'), findsOneWidget);
  });

  testWidgets('admin imports and edits an exam visible to the learner', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ToeicReadingApp());
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();

    expect(find.text('Quản lý đề thi'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('exam-json-input')),
      '[{"title":"Imported Reading","questionCount":12,"durationMinutes":20}]',
    );
    await tester.tap(find.text('Import đề thi'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    final importedTitle = find.text('Imported Reading');
    await tester.ensureVisible(importedTitle);
    expect(importedTitle, findsOneWidget);
    await tester.tap(find.byTooltip('Chỉnh sửa đề').last);
    await tester.pumpAndSettle();

    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogFields.first, 'Updated Reading');
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Updated Reading'), findsOneWidget);

    await tester.tap(find.text('Người học'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luyện tập'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    final updatedTitle = find.text('Updated Reading');
    await tester.ensureVisible(updatedTitle);
    await tester.tap(updatedTitle);
    await tester.pumpAndSettle();

    expect(find.text('Updated Reading'), findsOneWidget);
    expect(find.text('CÂU 3 TRÊN 10'), findsOneWidget);
  });
}
