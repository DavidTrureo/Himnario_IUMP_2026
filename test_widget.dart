import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test SliverReorderableList', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverReorderableList(
                itemCount: 2,
                onReorder: (o, n) {},
                itemBuilder: (context, index) {
                  return Container(
                    key: ValueKey(index),
                    child: ReorderableDragStartListener(
                      index: index,
                      child: Text('Item $index'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    final dragLocation = tester.getCenter(find.text('Item 0'));
    await tester.startGesture(dragLocation);
    await tester.pump();
  });
}
