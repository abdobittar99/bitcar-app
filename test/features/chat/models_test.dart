import 'package:car_shop/core/enums/message_status.dart';
import 'package:car_shop/models/conversation_model.dart';
import 'package:car_shop/models/message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t1 = DateTime(2026, 11, 1, 10);
  final t2 = DateTime(2026, 11, 1, 12);

  Map<String, dynamic> conversationMap({Map<String, dynamic>? clearedAt}) => {
        'participants': ['alice', 'seller'],
        'buyerId': 'alice',
        'sellerId': 'seller',
        'participantNames': {'alice': 'Alice Buyer', 'seller': 'Sam Seller'},
        'createdAt': Timestamp.fromDate(t1),
        'lastMessage': {
          'id': 'm2',
          'text': 'Still available',
          'senderId': 'seller',
          'deleted': false,
        },
        'lastMessageAt': Timestamp.fromDate(t2),
        'unreadCount': {'alice': 3, 'seller': 0},
        'lastReadAt': {'seller': Timestamp.fromDate(t1)},
        if (clearedAt != null) 'clearedAt': clearedAt,
      };

  group('ConversationModel.idFor', () {
    test('is the same whichever user starts the conversation', () {
      expect(ConversationModel.idFor('seller', 'alice'), 'alice_seller');
      expect(ConversationModel.idFor('alice', 'seller'), 'alice_seller');
    });
  });

  group('ConversationModel.fromMap', () {
    test('reads per-user entries for the current user', () {
      final c = ConversationModel.fromMap(conversationMap(), 'alice_seller', 'alice');

      expect(c.otherUserId, 'seller');
      expect(c.otherUserName, 'Sam Seller');
      expect(c.unreadCount, 3);
      expect(c.otherLastReadAt, t1);
      expect(c.lastMessageText, 'Still available');
      expect(c.isLastMessageDeleted, isFalse);
      expect(c.lastMessageSenderId, 'seller');
      expect(c.lastMessageAt, t2);
      expect(c.clearedAt, isNull);
    });

    test('the other participant sees their own values', () {
      final c = ConversationModel.fromMap(conversationMap(), 'alice_seller', 'seller');

      expect(c.otherUserId, 'alice');
      expect(c.otherUserName, 'Alice Buyer');
      expect(c.unreadCount, 0);
      expect(c.otherLastReadAt, isNull);
    });

    test('a pending own clearedAt (present key, null value) reads as now', () {
      final before = DateTime.now();
      final c = ConversationModel.fromMap(
        conversationMap(clearedAt: {'alice': null}),
        'alice_seller',
        'alice',
      );

      expect(c.clearedAt, isNotNull);
      expect(c.clearedAt!.isBefore(before), isFalse);
      expect(c.isVisibleInList, isFalse);
    });
  });

  group('ConversationEntity.isVisibleInList', () {
    test('is visible when never cleared', () {
      final c = ConversationModel.fromMap(conversationMap(), 'alice_seller', 'alice');
      expect(c.isVisibleInList, isTrue);
    });

    test('is hidden when cleared after the last message', () {
      final c = ConversationModel.fromMap(
        conversationMap(clearedAt: {'alice': Timestamp.fromDate(t2.add(const Duration(minutes: 1)))}),
        'alice_seller',
        'alice',
      );
      expect(c.isVisibleInList, isFalse);
    });

    test('reappears when a message arrives after the clear', () {
      final c = ConversationModel.fromMap(
        conversationMap(clearedAt: {'alice': Timestamp.fromDate(t1)}),
        'alice_seller',
        'alice',
      );
      expect(c.isVisibleInList, isTrue);
    });

    test('is hidden while it has no message yet', () {
      final map = conversationMap()..remove('lastMessageAt');
      final c = ConversationModel.fromMap(map, 'alice_seller', 'alice');
      expect(c.isVisibleInList, isFalse);
    });
  });

  group('MessageModel', () {
    test('fromMap reads a server message as sent', () {
      final m = MessageModel.fromMap(
        {'senderId': 'alice', 'text': 'Hi', 'createdAt': Timestamp.fromDate(t1), 'deleted': false},
        'm1',
        'alice_seller',
      );

      expect(m.id, 'm1');
      expect(m.conversationId, 'alice_seller');
      expect(m.senderId, 'alice');
      expect(m.text, 'Hi');
      expect(m.createdAt, t1);
      expect(m.isDeleted, isFalse);
      expect(m.status, MessageStatus.sent);
    });

    test('a deleted message has empty text', () {
      final m = MessageModel.fromMap(
        {'senderId': 'alice', 'text': 'old text', 'createdAt': Timestamp.fromDate(t1), 'deleted': true},
        'm1',
        'alice_seller',
      );
      expect(m.isDeleted, isTrue);
      expect(m.text, '');
    });

    test('a message without createdAt stays sending', () {
      final m = MessageModel.fromMap(
        {'senderId': 'alice', 'text': 'Hi', 'createdAt': null, 'deleted': false},
        'm1',
        'alice_seller',
      );
      expect(m.createdAt, isNull);
      expect(m.status, MessageStatus.sending);
    });

    test('toCreateMap has exactly the keys the security rules accept', () {
      final map = MessageModel.toCreateMap(senderId: 'alice', text: 'Hi');

      expect(map.keys.toSet(), {'senderId', 'text', 'createdAt', 'deleted'});
      expect(map['senderId'], 'alice');
      expect(map['text'], 'Hi');
      expect(map['deleted'], isFalse);
      expect(map['createdAt'], isA<FieldValue>());
    });
  });
}
