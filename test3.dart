import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test SliverReorderableList with ListTile', (WidgetTester tester) async {
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
                    child: ListTile(
                      title: Text('Item $index'),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    final dragLocation = tester.getCenter(find.byIcon(Icons.drag_handle).first);
    await tester.startGesture(dragLocation);
    await tester.pump();
  });
}
