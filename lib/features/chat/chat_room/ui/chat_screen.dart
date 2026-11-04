import 'package:car_shop/features/chat/chat_room/bloc/chat_bloc.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_event.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_state.dart';
import 'package:car_shop/features/chat/chat_room/ui/message_input_bar.dart';
import 'package:car_shop/features/chat/chat_room/ui/message_list.dart';
import 'package:car_shop/features/chat/chat_room/ui/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// Observes the app lifecycle: messages are marked read only while the chat is on screen.
class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      context.read<ChatBloc>().add(ChatVisibilityChanged(true));
    } else if (lifecycle == AppLifecycleState.paused) {
      context.read<ChatBloc>().add(ChatVisibilityChanged(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final bloc = context.read<ChatBloc>();
        final target = state.target;
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(title: Text(target?.otherUserName ?? '')),
          body: Column(
            children: [
              _LiveUpdatesBanner(state: state),
              if (state.isOffline) const OfflineBanner(),
              if (state.isNewConversation)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Start the conversation with ${target!.otherUserName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : MessageList(
                        messages: state.messages,
                        currentUserId: state.currentUserId,
                        hasOlder: state.hasOlder,
                        isLoadingOlder: state.isLoadingOlder,
                        olderLoadFailed: state.olderLoadFailed,
                        savedMessagesEnded: state.savedMessagesEnded,
                        outgoingCount: state.outgoingCount,
                        onReachTop: () => bloc.add(ChatLoadOlderRequested()),
                        onRetryOlder: () => bloc.add(ChatLoadOlderRequested()),
                        onRetryMessage: (id) =>
                            bloc.add(ChatMessageRetried(id)),
                      ),
              ),
              MessageInputBar(
                draft: state.draft,
                enabled: state.canSend,
                onSend: (text) => bloc.add(ChatMessageSubmitted(text)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Live window failure (FR-054): retryable → Retry (progress while retrying); fatal → the error
// text only, and sending is disabled by ChatState.canSend.
class _LiveUpdatesBanner extends StatelessWidget {
  final ChatState state;

  const _LiveUpdatesBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    final String text;
    switch (state.streamStatus) {
      case ChatStreamStatus.live:
        return const SizedBox.shrink();
      case ChatStreamStatus.retrying:
        text = 'Live updates stopped.';
        trailing = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ChatStreamStatus.failedRetryable:
        text = 'Live updates stopped.';
        trailing = TextButton(
          onPressed: () => context.read<ChatBloc>().add(ChatRetried()),
          child: const Text('Retry'),
        );
      case ChatStreamStatus.failedFatal:
        text = state.streamError ?? 'Live updates stopped.';
        trailing = const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          trailing,
        ],
      ),
    );
  }
}
