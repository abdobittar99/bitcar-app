import 'dart:async';

import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:car_shop/core/validators/chat_validator.dart';
import 'package:car_shop/models/conversation_model.dart';
import 'package:car_shop/models/message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef OpenChatRecord = ({
  String conversationId,
  String otherUserId,
  String otherUserName,
  bool exists,
});

typedef LatestMessagesRecord = ({
  List<MessageModel> messages,
  DateTime? otherLastReadAt,
  int unreadCount,
  DateTime? clearedAt,
  bool isFromCache,
});

typedef OlderMessagesRecord = ({
  List<MessageModel> messages,
  bool hasOlder,
  bool isFromCache,
});

typedef ConversationsRecord = ({
  List<ConversationModel> conversations,
  bool isFromCache,
});

typedef ChatTargetRecord = ({
  String conversationId,
  String otherUserId,
  String otherUserName,
  bool exists,
  bool ownNameIsPlaceholder,
});

// The only chat class that talks to Firestore and Auth. Returns models (or records of models),
// never domain types; ChatRepositoryImpl builds the domain wrappers (constitution I).
class ChatRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final SessionGate sessionGate;

  ChatRemoteDataSource(this.firestore, this.auth, this.sessionGate);

  static const placeholderName = 'BitCar user';
  static const maxMessagesPerWindow = ChatValidator.maxMessagesPerMinute;
  static const rateLimitMessage = ChatValidator.rateLimitMessage;

  String get currentUserId {
    final user = auth.currentUser;
    if (user == null) {
      throw AppException(message: 'User not logged in', type: ErrorType.auth);
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _conversation(String cid) =>
      firestore.collection('conversations').doc(cid);

  CollectionReference<Map<String, dynamic>> _messages(String cid) =>
      _conversation(cid).collection('messages');

  // Writes own publicProfiles/{uid} only when it is missing or different (research D14).
  Future<void> syncPublicProfile(String displayName) async {
    try {
      await sessionGate.run(() async {
        final ref = firestore.collection('publicProfiles').doc(currentUserId);
        final doc = await ref.get();
        // From the cache: offline. A write here would stay queued; the next app open repeats this.
        if (doc.metadata.isFromCache) return;
        if (doc.exists && doc.data()?['displayName'] == displayName) return;
        await ref.set({'displayName': displayName});
      });
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // Public name of a user, or the placeholder when they have no public profile.
  Future<String> readPublicName(String uid) async {
    try {
      final doc = await sessionGate.run(
        () => firestore.collection('publicProfiles').doc(uid).get(),
      );
      return doc.data()?['displayName'] as String? ?? placeholderName;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // Opening a chat writes nothing (FR-002): one read of the deterministic conversation id,
  // plus the other user's public name when the conversation does not exist yet.
  Future<OpenChatRecord> openChatWith(String otherUserId) async {
    final uid = currentUserId;
    if (otherUserId == uid) {
      throw AppException(
        message: "You can't chat with yourself",
        type: ErrorType.validation,
      );
    }
    final cid = ConversationModel.idFor(uid, otherUserId);
    try {
      final doc = await sessionGate.run(() => _conversation(cid).get());
      if (doc.exists) {
        final names =
            doc.data()?['participantNames'] as Map<String, dynamic>? ?? {};
        return (
          conversationId: cid,
          otherUserId: otherUserId,
          otherUserName: names[otherUserId] as String? ?? placeholderName,
          exists: true,
        );
      }
    } catch (e) {
      throw ErrorMapper.map(e);
    }
    return (
      conversationId: cid,
      otherUserId: otherUserId,
      otherUserName: await readPublicName(otherUserId),
      exists: false,
    );
  }

  // Opening from the list: one read, no profile read and no write, so names never delay or
  // block opening. Replacing an own placeholder is the separate fillOwnPlaceholderName.
  Future<ChatTargetRecord> getChatTarget(String conversationId) async {
    final uid = currentUserId;
    try {
      final doc = await sessionGate.run(
        () => _conversation(conversationId).get(),
      );
      final data = doc.data();
      if (data == null) {
        throw AppException(
          message: 'Conversation not found',
          type: ErrorType.notFound,
        );
      }
      final conversation = ConversationModel.fromMap(data, doc.id, uid);
      final names = data['participantNames'] as Map<String, dynamic>? ?? {};
      return (
        conversationId: doc.id,
        otherUserId: conversation.otherUserId,
        otherUserName: conversation.otherUserName,
        exists: true,
        ownNameIsPlaceholder:
            names[uid] == placeholderName && !doc.metadata.isFromCache,
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // Replaces only the caller's own placeholder with their public name (rules isFillOwnName).
  // Without a public profile, or offline, there is nothing to write.
  Future<void> fillOwnPlaceholderName(String conversationId) async {
    final uid = currentUserId;
    try {
      await sessionGate.run(() async {
        final profile = await firestore
            .collection('publicProfiles')
            .doc(uid)
            .get();
        final name = profile.data()?['displayName'] as String?;
        if (name == null || profile.metadata.isFromCache) return;
        await _conversation(
          conversationId,
        ).update({'participantNames.$uid': name});
      });
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // The user's conversations, newest first (composite index on participants + lastMessageAt).
  // Without a signed-in user no query runs: the error ends the stream quietly (_watchGuarded).
  Stream<ConversationsRecord> watchConversations() {
    return _watchGuarded(() {
      final String uid;
      try {
        uid = currentUserId;
      } on AppException catch (e) {
        return Stream<ConversationsRecord>.error(e);
      }
      return firestore
          .collection('conversations')
          .where('participants', arrayContains: uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snap) => (
              conversations: snap.docs
                  .map((d) => ConversationModel.fromMap(d.data(), d.id, uid))
                  .toList(),
              isFromCache: snap.metadata.isFromCache,
            ),
          );
    });
  }

  // Local id generation, no network.
  String newMessageId(String conversationId) =>
      _messages(conversationId).doc().id;

  // One transaction (research D4): creates the conversation on the first message, is idempotent
  // for the same messageId (FR-014) and counts the send in chatRateLimits/{uid} without using
  // the device clock (research D10). Field values match the rules contract exactly.
  // Two first sends racing for the same pair: the loser's transaction retries, sees the
  // conversation and continues as a normal send, so there is still one conversation (FR-001).
  Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required String otherUserId,
    required String text,
  }) async {
    final uid = currentUserId;
    final convRef = _conversation(conversationId);
    final msgRef = _messages(conversationId).doc(messageId);
    final rateRef = firestore.collection('chatRateLimits').doc(uid);
    var startsNewWindow = false;

    try {
      await sessionGate.run(
        () => firestore.runTransaction((tx) async {
          startsNewWindow = false;

          // All reads first. A message of a missing conversation cannot exist, and the rules
          // refuse reading it, so the message doc is read only when the conversation exists.
          final conv = await tx.get(convRef);
          if (conv.exists && (await tx.get(msgRef)).exists) return;
          final rate = await tx.get(rateRef);
          final names = conv.exists
              ? null
              : {
                  uid: await _publicNameIn(tx, uid),
                  otherUserId: await _publicNameIn(tx, otherUserId),
                };

          final now = FieldValue.serverTimestamp();
          final lastMessage = {
            'id': messageId,
            'text': text,
            'senderId': uid,
            'deleted': false,
          };

          if (names != null) {
            tx.set(convRef, {
              'participants': [uid, otherUserId]..sort(),
              'buyerId': uid,
              'sellerId': otherUserId,
              'participantNames': names,
              'createdAt': now,
              'lastMessage': lastMessage,
              'lastMessageAt': now,
              'unreadCount': {otherUserId: 1, uid: 0},
            });
          } else {
            tx.update(convRef, {
              'lastMessage': lastMessage,
              'lastMessageAt': now,
              'unreadCount.$otherUserId': FieldValue.increment(1),
            });
          }

          tx.set(msgRef, MessageModel.toCreateMap(senderId: uid, text: text));

          final count = (rate.data()?['count'] as num?)?.toInt() ?? 0;
          if (!rate.exists) {
            tx.set(rateRef, {'count': 1, 'windowStart': now});
          } else if (count < maxMessagesPerWindow) {
            // increment, not count + 1: the rules compare with the current count, so a stale
            // absolute value from a concurrent send would be refused instead of retried.
            tx.update(rateRef, {'count': FieldValue.increment(1)});
          } else {
            // The rules accept a new window only 60 s after windowStart (request.time).
            startsNewWindow = true;
            tx.set(rateRef, {'count': 1, 'windowStart': now});
          }
        }),
      );
    } on FirebaseException catch (e) {
      if (startsNewWindow && e.code == 'permission-denied') {
        throw AppException(
          message: rateLimitMessage,
          type: ErrorType.validation,
        );
      }
      throw ErrorMapper.map(e);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // One-time read of the batch just older than the cursor (research D17). The cursor is built
  // from plain values; startAfterDocument is never used. Falls back to the cache offline: a
  // cache-only result never ends the history.
  Future<OlderMessagesRecord> loadOlderMessages(
    String conversationId, {
    required DateTime beforeCreatedAt,
    required String beforeMessageId,
    DateTime? after,
    required int pageSize,
  }) async {
    try {
      final snap = await sessionGate.run(() {
        Query<Map<String, dynamic>> query = _messages(conversationId);
        if (after != null) {
          query = query.where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(after),
          );
        }
        return query
            .orderBy('createdAt', descending: true)
            .orderBy(FieldPath.documentId, descending: true)
            .startAfter([Timestamp.fromDate(beforeCreatedAt), beforeMessageId])
            .limit(pageSize)
            .get();
      });
      final isFromCache = snap.metadata.isFromCache;
      return (
        messages: snap.docs.reversed
            .map((d) => MessageModel.fromMap(d.data(), d.id, conversationId))
            .toList(),
        hasOlder: isFromCache || snap.docs.length == pageSize,
        isFromCache: isFromCache,
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // Own unread to 0 and own lastReadAt to server time (rules isMarkRead). The bloc calls this
  // only when the live window reports own unreadCount > 0 from the server, so an already-read
  // conversation is never written.
  Future<void> markConversationRead(String conversationId) async {
    final uid = currentUserId;
    try {
      await sessionGate.run(
        () => _conversation(conversationId).update({
          'unreadCount.$uid': 0,
          'lastReadAt.$uid': FieldValue.serverTimestamp(),
        }),
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // One extra attempt only for permission-denied: the rules compare with the current data, so a
  // concurrent change refuses a stale write, and transactions do not retry that by themselves
  // (research D19). A real denial fails again and reaches the caller.
  static Future<T> retryOnceOnPermissionDenied<T>(
    Future<T> Function() attempt,
  ) async {
    try {
      return await attempt();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      return attempt();
    }
  }

  // Same comparison as rules isUnseenBy: a message the user has read or cleared is not unread.
  static bool isUnseen(
    Timestamp createdAt, {
    Timestamp? lastReadAt,
    Timestamp? clearedAt,
  }) {
    return (lastReadAt == null || createdAt.compareTo(lastReadAt) > 0) &&
        (clearedAt == null || createdAt.compareTo(clearedAt) > 0);
  }

  // Delete for everyone, one commit with the proof the rules require (research D19): the message,
  // lastDeletedMessageId, the preview only if it is the latest message, and the other user's
  // unread count only if they have not seen it. Each attempt is a new transaction with fresh reads.
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final uid = currentUserId;
    final convRef = _conversation(conversationId);
    final msgRef = _messages(conversationId).doc(messageId);
    try {
      await sessionGate.run(
        () => retryOnceOnPermissionDenied(
          () => firestore.runTransaction((tx) async {
            final conv = (await tx.get(convRef)).data();
            final message = conv == null ? null : (await tx.get(msgRef)).data();
            if (conv == null || message == null) {
              throw AppException(
                message: 'Message not found',
                type: ErrorType.notFound,
              );
            }
            if (message['deleted'] == true) return;
            if (message['senderId'] != uid) {
              throw AppException(
                message: 'You can only delete your own messages',
                type: ErrorType.permission,
              );
            }

            final other = (conv['participants'] as List<dynamic>)
                .map((e) => e.toString())
                .firstWhere((p) => p != uid);
            final update = <String, dynamic>{'lastDeletedMessageId': messageId};
            final lastMessage = conv['lastMessage'] as Map<String, dynamic>?;
            if (lastMessage?['id'] == messageId) {
              update['lastMessage'] = {
                'id': messageId,
                'text': '',
                'senderId': uid,
                'deleted': true,
              };
            }
            final unread = conv['unreadCount'] as Map<String, dynamic>?;
            final lastReadAt = conv['lastReadAt'] as Map<String, dynamic>?;
            final clearedAt = conv['clearedAt'] as Map<String, dynamic>?;
            final seen = !isUnseen(
              message['createdAt'] as Timestamp,
              lastReadAt: lastReadAt?[other] as Timestamp?,
              clearedAt: clearedAt?[other] as Timestamp?,
            );
            if (!seen && ((unread?[other] as num?) ?? 0) > 0) {
              update['unreadCount.$other'] = FieldValue.increment(-1);
            }

            tx.update(msgRef, {'deleted': true, 'text': ''});
            tx.update(convRef, update);
          }),
        ),
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // One-sided delete (FR-027a). A transaction, so it fails instead of staying queued offline
  // (FR-014b). It writes only own entries: no message and nothing of the other participant.
  Future<void> deleteConversation(String conversationId) async {
    final uid = currentUserId;
    final convRef = _conversation(conversationId);
    try {
      await sessionGate.run(
        () => firestore.runTransaction((tx) async {
          final conv = await tx.get(convRef);
          if (!conv.exists) {
            throw AppException(
              message: 'Conversation not found',
              type: ErrorType.notFound,
            );
          }
          tx.update(convRef, {
            'clearedAt.$uid': FieldValue.serverTimestamp(),
            'unreadCount.$uid': 0,
          });
        }),
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<String> _publicNameIn(Transaction tx, String uid) async {
    final doc = await tx.get(firestore.collection('publicProfiles').doc(uid));
    return doc.data()?['displayName'] as String? ?? placeholderName;
  }

  // Bounded live window (research D17). The conversation listener starts first; the messages
  // listener starts only once the conversation exists (the rules refuse the messages query
  // before that) and restarts when own clearedAt changes. Never listens without a limit.
  Stream<LatestMessagesRecord> watchLatestMessages(
    String conversationId,
    int pageSize,
  ) {
    return _watchGuarded(() => _latestMessages(conversationId, pageSize));
  }

  Stream<LatestMessagesRecord> _latestMessages(String cid, int pageSize) {
    late final StreamController<LatestMessagesRecord> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? convSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? msgSub;
    DocumentSnapshot<Map<String, dynamic>>? lastConv;
    QuerySnapshot<Map<String, dynamic>>? lastMessages;
    var messagesStarted = false;
    Object? clearedRaw;

    Future<void> stop() async {
      final subs = [msgSub, convSub];
      msgSub = null;
      convSub = null;
      for (final sub in subs) {
        await sub?.cancel();
      }
    }

    // A listener error is terminal: report it once and end the stream.
    void fail(Object error, [StackTrace? stackTrace]) {
      if (controller.isClosed) return;
      controller.addError(error, stackTrace);
      stop();
      controller.close();
    }

    void push(String uid) {
      final convDoc = lastConv;
      if (convDoc == null || controller.isClosed) return;
      if (!convDoc.exists) {
        controller.add((
          messages: const [],
          otherLastReadAt: null,
          unreadCount: 0,
          clearedAt: null,
          isFromCache: convDoc.metadata.isFromCache,
        ));
        return;
      }
      final messagesSnap = lastMessages;
      if (messagesSnap == null) return;
      final conv = ConversationModel.fromMap(convDoc.data()!, cid, uid);
      controller.add((
        messages: messagesSnap.docs.reversed
            .map((d) => MessageModel.fromMap(d.data(), d.id, cid))
            .toList(),
        otherLastReadAt: conv.otherLastReadAt,
        unreadCount: conv.unreadCount,
        clearedAt: conv.clearedAt,
        isFromCache:
            convDoc.metadata.isFromCache || messagesSnap.metadata.isFromCache,
      ));
    }

    void listenMessages(String uid, DateTime? clearedAt) {
      msgSub?.cancel();
      lastMessages = null;
      Query<Map<String, dynamic>> query = _messages(cid);
      if (clearedAt != null) {
        query = query.where(
          'createdAt',
          isGreaterThan: Timestamp.fromDate(clearedAt),
        );
      }
      msgSub = query
          .orderBy('createdAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(pageSize)
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
            lastMessages = snap;
            push(uid);
          }, onError: fail);
    }

    controller = StreamController<LatestMessagesRecord>(
      onListen: () {
        final String uid;
        try {
          uid = currentUserId;
        } on AppException catch (e) {
          fail(e);
          return;
        }
        convSub = _conversation(cid)
            .snapshots(includeMetadataChanges: true)
            .listen((snap) {
              lastConv = snap;
              if (!snap.exists) {
                push(uid);
                return;
              }
              final cleared =
                  snap.data()?['clearedAt'] as Map<String, dynamic>?;
              final raw = cleared?[uid];
              if (!messagesStarted || raw != clearedRaw) {
                messagesStarted = true;
                clearedRaw = raw;
                final conv = ConversationModel.fromMap(snap.data()!, cid, uid);
                listenMessages(uid, conv.clearedAt);
              } else {
                push(uid);
              }
            }, onError: fail);
      },
      onCancel: stop,
    );
    return controller.stream;
  }

  // Every chat stream goes through the session gate. When the session is ending
  // (gate closing for sign-out, or no signed-in user) the stream is closed without an error;
  // that is an explicit check, not a blanket catch (constitution III). Any other error is
  // mapped with ErrorMapper and reaches the bloc.
  Stream<T> _watchGuarded<T>(Stream<T> Function() open) {
    return sessionGate
        .watch(open)
        .transform(
          StreamTransformer<T, T>.fromHandlers(
            handleError: (error, stackTrace, sink) {
              if (_sessionEnded) {
                sink.close();
                return;
              }
              sink.addError(ErrorMapper.map(error), stackTrace);
            },
          ),
        );
  }

  bool get _sessionEnded =>
      sessionGate.state == SessionGateState.closing || auth.currentUser == null;
}
