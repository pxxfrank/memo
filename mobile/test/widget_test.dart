import 'package:flutter_test/flutter_test.dart';

import 'package:memo_mobile/main.dart';

void main() {
  testWidgets('APP 启动渲染 HomePage', (tester) async {
    await tester.pumpWidget(const MemoApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('MEMO'), findsOneWidget);
  });
}
