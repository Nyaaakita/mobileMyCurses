import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lms_mobile/widgets/empty_state.dart";

void main() {
  testWidgets("EmptyState renders title and message", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: "Пусто",
            message: "Данных нет",
          ),
        ),
      ),
    );

    expect(find.text("Пусто"), findsOneWidget);
    expect(find.text("Данных нет"), findsOneWidget);
  });
}
