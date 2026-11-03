import 'package:car_shop/entities/message.dart';
import 'package:car_shop/features/chat/chat_room/ui/message_bubble.dart';
import 'package:flutter/material.dart';

// Two slivers around a center key (research D17): messages older than the anchor go into the
// sliver above it, the anchor and every newer message into the sliver below. The anchor is the
// oldest message of the first non-empty list, so adding items on either side never moves the
// content on screen. Takes plain values, so a widget test can drive it without a bloc.
class MessageList extends StatefulWidget {
  final List<MessageEntity> messages;
  final String? currentUserId;

  const MessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final _scrollController = ScrollController();
  final _centerKey = UniqueKey();
  String? _anchorId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Jump to the newest message when the list first gets content.
  void _jumpToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    var anchorIndex = messages.indexWhere((m) => m.id == _anchorId);
    if (anchorIndex == -1) {
      _anchorId = messages.isEmpty ? null : messages.first.id;
      anchorIndex = 0;
      if (_anchorId != null) _jumpToNewest();
    }
    final older = messages.sublist(0, anchorIndex);
    final newer = messages.sublist(anchorIndex);

    return CustomScrollView(
      controller: _scrollController,
      center: _centerKey,
      slivers: [
        // Grows upwards from the center: index 0 is the message just above the anchor.
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _bubble(older[older.length - 1 - index]),
            childCount: older.length,
          ),
        ),
        SliverList(
          key: _centerKey,
          delegate: SliverChildBuilderDelegate(
            (context, index) => _bubble(newer[index]),
            childCount: newer.length,
          ),
        ),
      ],
    );
  }

  Widget _bubble(MessageEntity message) {
    return MessageBubble(
      key: ValueKey(message.id),
      message: message,
      isOwn: message.senderId == widget.currentUserId,
    );
  }
}
