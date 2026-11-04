import 'package:car_shop/core/enums/message_status.dart';
import 'package:car_shop/entities/message.dart';
import 'package:car_shop/features/chat/chat_room/ui/message_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

final base = DateTime.now().subtract(const Duration(hours: 2));

MessageEntity msg(int i, {DateTime? at}) => MessageEntity(
  id: 'm${i.toString().padLeft(2, '0')}',
  conversationId: 'alice_seller',
  senderId: i.isEven ? 'alice' : 'seller',
  text: 'text $i',
  createdAt: at ?? base.add(Duration(seconds: i)),
  isDeleted: false,
  status: MessageStatus.sent,
);

List<MessageEntity> range(int from, int to) => [
  for (var i = from; i <= to; i++) msg(i),
];

void main() {
  late int reachTop;
  late int retryOlder;

  setUp(() {
    reachTop = 0;
    retryOlder = 0;
  });

  Future<void> show(
    WidgetTester tester,
    List<MessageEntity> messages, {
    bool hasOlder = true,
    bool isLoadingOlder = false,
    bool olderLoadFailed = false,
    bool savedMessagesEnded = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: MessageList(
              messages: messages,
              currentUserId: 'alice',
              hasOlder: hasOlder,
              isLoadingOlder: isLoadingOlder,
              olderLoadFailed: olderLoadFailed,
              savedMessagesEnded: savedMessagesEnded,
              onReachTop: () => reachTop++,
              onRetryOlder: () => retryOlder++,
              onRetryMessage: (_) {},
            ),
          ),
        ),
      ),
    );
    // A spinning progress indicator never settles.
    if (isLoadingOlder) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Offset topOf(WidgetTester tester, String id) =>
      tester.getTopLeft(find.byKey(ValueKey(id)));

  testWidgets('opens at the newest message', (tester) async {
    await show(tester, range(21, 40));

    expect(tester.getBottomLeft(find.byKey(const ValueKey('m40'))).dy, lessThanOrEqualTo(400));
    expect(reachTop, 0);
  });

  testWidgets('adding older items keeps the top visible message at the same screen offset', (tester) async {
    await show(tester, range(21, 40));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    final visible = find.byKey(const ValueKey('m30'));
    expect(visible, findsOneWidget);
    final before = topOf(tester, 'm30');

    await show(tester, range(1, 40));

    expect(topOf(tester, 'm30'), before);
  });

  testWidgets('a newer item while scrolled up keeps the offset and shows the "New messages" chip', (tester) async {
    await show(tester, range(21, 40));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    final before = topOf(tester, 'm30');

    await show(tester, range(21, 41));

    expect(topOf(tester, 'm30'), before);
    expect(find.text('New messages'), findsOneWidget);

    await tester.tap(find.text('New messages'));
    await tester.pumpAndSettle();
    expect(find.text('New messages'), findsNothing);
    expect(tester.getBottomLeft(find.byKey(const ValueKey('m41'))).dy, lessThanOrEqualTo(400));
  });

  testWidgets('at the bottom a newer item scrolls into view', (tester) async {
    await show(tester, range(21, 40));

    await show(tester, range(21, 41));

    expect(find.text('New messages'), findsNothing);
    final rect = tester.getRect(find.byKey(const ValueKey('m41')));
    expect(rect.bottom, lessThanOrEqualTo(400));
    expect(rect.top, greaterThanOrEqualTo(0));
  });

  testWidgets('onReachTop fires within 200 px of the top', (tester) async {
    await show(tester, range(21, 40));
    expect(reachTop, 0);

    await tester.fling(find.byType(CustomScrollView), const Offset(0, 3000), 3000);
    await tester.pumpAndSettle();

    expect(reachTop, greaterThan(0));
  });

  testWidgets('no automatic request after a failure; the Retry row asks again', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester, range(1, 3), olderLoadFailed: true);

    expect(reachTop, 0);
    expect(find.bySemanticsLabel("Couldn't load older messages, retry"), findsOneWidget);
    await tester.tap(find.text("Couldn't load older messages · Retry"));
    expect(retryOlder, 1);
    semantics.dispose();
  });

  testWidgets('top row: progress while loading, beginning label when there is nothing older', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester, range(1, 3), isLoadingOlder: true);
    expect(find.bySemanticsLabel('Loading older messages'), findsOneWidget);

    await show(tester, range(1, 3), hasOlder: false);
    expect(find.bySemanticsLabel('Loading older messages'), findsNothing);
    expect(find.bySemanticsLabel('Beginning of the conversation'), findsOneWidget);

    await show(tester, range(1, 3), hasOlder: true);
    expect(find.text('Beginning of the conversation'), findsNothing);
    semantics.dispose();
  });

  testWidgets('offline at the end of the saved messages: its own row, never the beginning label', (tester) async {
    await show(tester, range(1, 3), savedMessagesEnded: true);

    expect(find.text('No more saved messages. Connect to load older ones.'), findsOneWidget);
    expect(find.text('Beginning of the conversation'), findsNothing);
  });

  testWidgets('day separators: Today, Yesterday and the date', (tester) async {
    final now = DateTime.now();
    final older = DateTime(now.year, now.month, now.day - 5, 10);
    final yesterday = DateTime(now.year, now.month, now.day - 1, 10);
    final today = DateTime(now.year, now.month, now.day, 0, 1);

    await show(tester, [
      msg(1, at: older),
      msg(2, at: older.add(const Duration(minutes: 1))),
      msg(3, at: yesterday),
      msg(4, at: today),
    ], hasOlder: false);

    expect(find.text(DateFormat.yMMMd().format(older)), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });
}
