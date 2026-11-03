import 'package:car_shop/features/chat/chat_room/bloc/chat_bloc.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_event.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_state.dart';
import 'package:car_shop/features/chat/chat_room/ui/message_input_bar.dart';
import 'package:car_shop/features/chat/chat_room/ui/message_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final target = state.target;
        return Scaffold(
          appBar: AppBar(title: Text(target?.otherUserName ?? '')),
          body: Column(
            children: [
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
                      ),
              ),
              MessageInputBar(
                draft: state.draft,
                enabled: target != null,
                onSend: (text) =>
                    context.read<ChatBloc>().add(ChatMessageSubmitted(text)),
              ),
            ],
          ),
        );
      },
    );
  }
}
