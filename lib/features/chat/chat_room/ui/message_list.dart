import 'package:car_shop/entities/message.dart';
import 'package:car_shop/features/chat/chat_room/ui/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Two slivers around a center key (research D17): messages older than the anchor go into the
// sliver above it, the anchor and every newer message into the sliver below. The anchor is the
// oldest message of the first non-empty list, so adding items on either side never moves the
// content on screen (FR-041, FR-045). Takes plain values and callbacks, so a widget test can
// drive it without a bloc.
class MessageList extends StatefulWidget {
  final List<MessageEntity> messages;
  final String? currentUserId;
  final bool hasOlder;
  final bool isLoadingOlder;
  final bool olderLoadFailed;
  final bool savedMessagesEnded;
  // Changes on every send or retry: scroll to the newest message (FR-046).
  final int outgoingCount;
  final VoidCallback onReachTop;
  final VoidCallback onRetryOlder;
  final ValueChanged<String> onRetryMessage;

  static const topThreshold = 200.0;
  static const bottomThreshold = 100.0;

  const MessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.onReachTop,
    required this.onRetryOlder,
    required this.onRetryMessage,
    this.hasOlder = false,
    this.isLoadingOlder = false,
    this.olderLoadFailed = false,
    this.savedMessagesEnded = false,
    this.outgoingCount = 0,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final _scrollController = ScrollController();
  final _centerKey = UniqueKey();
  String? _anchorId;
  bool _atBottom = true;
  bool _showNewMessages = false;
  double? _lastHeight;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final p = _scrollController.position;
    return p.maxScrollExtent - p.pixels <= MessageList.bottomThreshold;
  }

  void _onScroll() {
    _atBottom = _isNearBottom;
    if (_atBottom && _showNewMessages) {
      setState(() => _showNewMessages = false);
    }
    _checkTop();
  }

  // Asks for the next older batch within 200 px of the top. The bloc drops repeats (FR-042);
  // after a failure only the Retry row asks again.
  void _checkTop() {
    if (!_scrollController.hasClients ||
        !widget.hasOlder ||
        widget.isLoadingOlder ||
        widget.olderLoadFailed) {
      return;
    }
    final p = _scrollController.position;
    if (p.pixels <= p.minScrollExtent + MessageList.topThreshold) {
      widget.onReachTop();
    }
  }

  // When the newer part fits on screen (short conversation) the maximum extent is 0 and the
  // top row sits above the center, so show everything from the top instead.
  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final p = _scrollController.position;
      _scrollController.jumpTo(
        p.maxScrollExtent > 0 ? p.maxScrollExtent : p.minScrollExtent,
      );
      _atBottom = true;
    });
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.outgoingCount != oldWidget.outgoingCount) {
      _showNewMessages = false;
      _scrollToNewest();
      return;
    }
    if (oldWidget.messages.isEmpty || !_hasNewerItems(oldWidget.messages)) {
      return;
    }
    // Position before the new layout: near the bottom → follow, otherwise keep it (FR-045).
    if (_isNearBottom) {
      _scrollToNewest();
    } else {
      _showNewMessages = true;
    }
  }

  // New ids after the first message that was already shown are newer messages; new ids before
  // it are an older batch.
  bool _hasNewerItems(List<MessageEntity> old) {
    final oldIds = {for (final m in old) m.id};
    final current = widget.messages;
    final firstOld = current.indexWhere((m) => oldIds.contains(m.id));
    if (firstOld == -1) return false;
    for (var i = firstOld + 1; i < current.length; i++) {
      if (!oldIds.contains(current[i].id)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    var anchorIndex = messages.indexWhere((m) => m.id == _anchorId);
    if (anchorIndex == -1) {
      _anchorId = messages.isEmpty ? null : messages.first.id;
      anchorIndex = 0;
      if (_anchorId != null) _scrollToNewest();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkTop();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        // Keyboard opened: stay at the newest message if the user was there (FR-051).
        final height = constraints.maxHeight;
        if (_lastHeight != null && height < _lastHeight! && _atBottom) {
          _scrollToNewest();
        }
        _lastHeight = height;

        final olderCount = anchorIndex;
        final newerCount = messages.length - anchorIndex;
        return Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              center: _centerKey,
              slivers: [
                // Grows upwards from the center: index 0 is the message just above the
                // anchor, the last index is the top row.
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => index == olderCount
                        ? _topRow()
                        : _item(anchorIndex - 1 - index),
                    childCount: olderCount + 1,
                  ),
                ),
                SliverList(
                  key: _centerKey,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _item(anchorIndex + index),
                    childCount: newerCount,
                  ),
                ),
              ],
            ),
            if (_showNewMessages)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.arrow_downward, size: 16),
                    label: const Text('New messages'),
                    onPressed: () {
                      setState(() => _showNewMessages = false);
                      _scrollToNewest();
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _topRow() {
    final Widget child;
    if (widget.isLoadingOlder) {
      child = Semantics(
        label: 'Loading older messages',
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (widget.olderLoadFailed) {
      child = Semantics(
        label: "Couldn't load older messages, retry",
        button: true,
        excludeSemantics: true,
        child: TextButton(
          onPressed: widget.onRetryOlder,
          child: const Text("Couldn't load older messages · Retry"),
        ),
      );
    } else if (widget.savedMessagesEnded) {
      child = const Text(
        'No more saved messages. Connect to load older ones.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    } else if (!widget.hasOlder && widget.messages.isNotEmpty) {
      child = Semantics(
        label: 'Beginning of the conversation',
        excludeSemantics: true,
        child: const Text(
          'Beginning of the conversation',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(child: child),
    );
  }

  Widget _item(int index) {
    final messages = widget.messages;
    final message = messages[index];
    final day = _dayOf(message);
    final showDay = index == 0 || _dayOf(messages[index - 1]) != day;
    final bubble = MessageBubble(
      message: message,
      isOwn: message.senderId == widget.currentUserId,
      onRetry: () => widget.onRetryMessage(message.id),
    );
    return Column(
      key: ValueKey(message.id),
      mainAxisSize: MainAxisSize.min,
      children: [if (showDay) _DayLabel(day: day), bubble],
    );
  }

  // Local calendar day; a local message without a server time belongs to today.
  static DateTime _dayOf(MessageEntity m) {
    final t = (m.createdAt ?? DateTime.now()).toLocal();
    return DateTime(t.year, t.month, t.day);
  }
}

class _DayLabel extends StatelessWidget {
  final DateTime day;

  const _DayLabel({required this.day});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final String text;
    if (day == today) {
      text = 'Today';
    } else if (day == DateTime(now.year, now.month, now.day - 1)) {
      text = 'Yesterday';
    } else {
      text = DateFormat.yMMMd().format(day);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }
}
