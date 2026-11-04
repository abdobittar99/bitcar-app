import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_bloc.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_event.dart';
import 'package:car_shop/features/chat/chat_room/ui/chat_screen.dart';
import 'package:car_shop/features/chat/chat_room/ui/offline_banner.dart';
import 'package:car_shop/features/chat/conversations/bloc/conversations_bloc.dart';
import 'package:car_shop/features/chat/conversations/bloc/conversations_event.dart';
import 'package:car_shop/features/chat/conversations/bloc/conversations_state.dart';
import 'package:car_shop/features/chat/conversations/ui/conversation_tile.dart';
import 'package:car_shop/shared/components/general_widget/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  void _open(BuildContext context, String conversationId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) =>
              sl<ChatBloc>()..add(ChatStarted.fromConversation(conversationId)),
          child: const ChatScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: BlocBuilder<ConversationsBloc, ConversationsState>(
        builder: (context, state) {
          if (state.hasError) {
            return EmptyState(
              icon: Icons.chat_bubble_outline,
              title: "Couldn't load conversations",
              subtitle: 'Check your connection and try again.',
              buttonText: 'Retry',
              onButtonPressed: () =>
                  context.read<ConversationsBloc>().add(ConversationsRetried()),
            );
          }
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              if (state.isOffline) const OfflineBanner(),
              Expanded(
                child: state.conversations.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No conversations yet',
                        subtitle: 'Start a chat from any car page.',
                      )
                    : ListView.separated(
                        itemCount: state.conversations.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final conversation = state.conversations[index];
                          return ConversationTile(
                            key: ValueKey(conversation.id),
                            conversation: conversation,
                            onTap: () => _open(context, conversation.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
